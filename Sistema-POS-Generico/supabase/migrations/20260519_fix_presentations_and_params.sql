-- ============================================================
-- FIX DEFINITIVO: Solución al colapso de productos y sus presentaciones (maestro/packs)
-- Corrige search_products_pos_bodega, get_inventory_por_bodega y search_products_pos
-- para que retornen AMBOS el producto unitario (base) y sus presentaciones.
-- ============================================================

-- 1. search_products_pos_bodega (Usado por el POS y CrearPreVenta)
DROP FUNCTION IF EXISTS public.search_products_pos_bodega() CASCADE;
DROP FUNCTION IF EXISTS public.search_products_pos_bodega(text) CASCADE;

CREATE OR REPLACE FUNCTION public.search_products_pos_bodega(p_query text DEFAULT '')
RETURNS TABLE(
    id uuid,
    nombre_producto text,
    codigo_barra text,
    precio_venta numeric,
    stock_actual numeric,
    numero_lote text,
    fecha_vencimiento date,
    factor_conversion numeric,
    es_presentacion boolean,
    nombre_presentacion text,
    unidad_medida text,
    controla_stock boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
    v_empresa_id uuid;
    v_bodega_venta_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    -- Intentamos obtener la bodega de tipo 'venta' de la empresa
    SELECT id INTO v_bodega_venta_id 
    FROM public.bodegas 
    WHERE empresa_id = v_empresa_id AND tipo = 'venta' 
    LIMIT 1;

    RETURN QUERY
    /* A. Productos Base (Unidad) */
    SELECT 
        pr.id::uuid,
        mp.nombre::text,
        mp.codigo_barra::text,
        mp.precio_venta::numeric,
        pr.stock_actual::numeric,
        pr.numero_lote::text,
        pr.fecha_vencimiento::date,
        1.0::numeric as factor_conversion,
        false::boolean as es_presentacion,
        NULL::text as nombre_presentacion,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM 
        public.productos pr
    JOIN 
        public.maestro_productos mp ON pr.maestro_producto_id = mp.id
    WHERE 
        mp.empresa_id = v_empresa_id
        AND (v_bodega_venta_id IS NULL OR pr.bodega_id = v_bodega_venta_id)
        AND (pr.stock_actual > 0 OR mp.controla_stock = false)
        AND (
            p_query = '' 
            OR mp.nombre ILIKE '%' || p_query || '%' 
            OR mp.codigo_barra ILIKE '%' || p_query || '%'
        )

    UNION ALL

    /* B. Presentaciones / Packs */
    SELECT 
        pr.id::uuid,
        mp.nombre::text,
        pp.codigo_barra::text,
        COALESCE(pp.precio_venta, mp.precio_venta * pp.factor_conversion)::numeric as precio_venta,
        pr.stock_actual::numeric,
        pr.numero_lote::text,
        pr.fecha_vencimiento::date,
        pp.factor_conversion::numeric,
        true::boolean as es_presentacion,
        pp.nombre_presentacion::text,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM 
        public.productos pr
    JOIN 
        public.maestro_productos mp ON pr.maestro_producto_id = mp.id
    JOIN 
        public.producto_presentaciones pp ON pp.maestro_producto_id = mp.id
    WHERE 
        mp.empresa_id = v_empresa_id
        AND (v_bodega_venta_id IS NULL OR pr.bodega_id = v_bodega_venta_id)
        AND (pr.stock_actual > 0 OR mp.controla_stock = false)
        AND (
            p_query = '' 
            OR mp.nombre ILIKE '%' || p_query || '%' 
            OR pp.nombre_presentacion ILIKE '%' || p_query || '%'
            OR pp.codigo_barra ILIKE '%' || p_query || '%'
            OR mp.codigo_barra ILIKE '%' || p_query || '%'
        );
END;
$$;


-- 2. get_inventory_por_bodega (Usado en el Dashboard de Inventario)
DROP FUNCTION IF EXISTS public.get_inventory_por_bodega() CASCADE;
DROP FUNCTION IF EXISTS public.get_inventory_por_bodega(uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.get_inventory_por_bodega(p_filtro_bodega uuid DEFAULT NULL)
RETURNS TABLE(
    id uuid,
    nombre_producto text,
    codigo_barra text,
    precio_venta numeric,
    stock_actual numeric,
    numero_lote text,
    fecha_vencimiento date,
    bodega_nombre text,
    factor_conversion numeric,
    es_presentacion boolean,
    nombre_presentacion text,
    unidad_medida text,
    controla_stock boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    /* A. Productos Base */
    SELECT 
        pr.id::uuid,
        mp.nombre::text,
        mp.codigo_barra::text,
        mp.precio_venta::numeric,
        pr.stock_actual::numeric,
        pr.numero_lote::text,
        pr.fecha_vencimiento::date,
        COALESCE(b.nombre, 'Sin bodega')::text,
        1.0::numeric as factor_conversion,
        false::boolean as es_presentacion,
        NULL::text as nombre_presentacion,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM 
        public.productos pr
    JOIN 
        public.maestro_productos mp ON pr.maestro_producto_id = mp.id
    LEFT JOIN 
        public.bodegas b ON pr.bodega_id = b.id
    WHERE 
        mp.empresa_id = v_empresa_id
        AND (p_filtro_bodega IS NULL OR pr.bodega_id = p_filtro_bodega)
        AND (pr.stock_actual > 0 OR mp.controla_stock = false);
END;
$$;


-- 3. search_products_pos (Búsqueda general fuera de bodega)
DROP FUNCTION IF EXISTS public.search_products_pos() CASCADE;
DROP FUNCTION IF EXISTS public.search_products_pos(text) CASCADE;

CREATE OR REPLACE FUNCTION public.search_products_pos(p_query text DEFAULT '')
RETURNS TABLE(
    id uuid,
    nombre text,
    codigo_barra text,
    precio_venta numeric,
    stock_actual numeric,
    numero_lote text,
    factor_conversion numeric,
    es_presentacion boolean,
    nombre_presentacion text,
    unidad_medida text,
    controla_stock boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    /* A. Productos Base */
    SELECT 
        pr.id::uuid,
        mp.nombre::text,
        mp.codigo_barra::text,
        mp.precio_venta::numeric,
        pr.stock_actual::numeric,
        pr.numero_lote::text,
        1.0::numeric as factor_conversion,
        false::boolean as es_presentacion,
        NULL::text as nombre_presentacion,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM 
        public.productos pr
    JOIN 
        public.maestro_productos mp ON pr.maestro_producto_id = mp.id
    WHERE 
        mp.empresa_id = v_empresa_id
        AND (pr.stock_actual > 0 OR mp.controla_stock = false)
        AND (
            p_query = '' 
            OR mp.nombre ILIKE '%' || p_query || '%' 
            OR mp.codigo_barra ILIKE '%' || p_query || '%'
        )

    UNION ALL

    /* B. Presentaciones / Packs */
    SELECT 
        pr.id::uuid,
        mp.nombre::text,
        pp.codigo_barra::text,
        COALESCE(pp.precio_venta, mp.precio_venta * pp.factor_conversion)::numeric as precio_venta,
        pr.stock_actual::numeric,
        pr.numero_lote::text,
        pp.factor_conversion::numeric,
        true::boolean as es_presentacion,
        pp.nombre_presentacion::text,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM 
        public.productos pr
    JOIN 
        public.maestro_productos mp ON pr.maestro_producto_id = mp.id
    JOIN 
        public.producto_presentaciones pp ON pp.maestro_producto_id = mp.id
    WHERE 
        mp.empresa_id = v_empresa_id
        AND (pr.stock_actual > 0 OR mp.controla_stock = false)
        AND (
            p_query = '' 
            OR mp.nombre ILIKE '%' || p_query || '%' 
            OR pp.nombre_presentacion ILIKE '%' || p_query || '%'
            OR pp.codigo_barra ILIKE '%' || p_query || '%'
            OR mp.codigo_barra ILIKE '%' || p_query || '%'
        );
END;
$$;

NOTIFY pgrst, 'reload schema';
