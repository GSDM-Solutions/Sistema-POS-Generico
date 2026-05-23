-- Fix search_products_pos_bodega: columnas ambiguas
DROP FUNCTION IF EXISTS public.search_products_pos_bodega CASCADE;

CREATE OR REPLACE FUNCTION public.search_products_pos_bodega(p_search text DEFAULT '')
RETURNS TABLE(
    id uuid, nombre_producto text, codigo_barra text, precio_venta numeric,
    stock_actual numeric, numero_lote text, fecha_vencimiento date,
    factor_conversion numeric, es_presentacion boolean, nombre_presentacion text,
    unidad_medida text, controla_stock boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
    v_empresa_id uuid;
    v_bodega_venta_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();
    SELECT b.id INTO v_bodega_venta_id
    FROM public.bodegas b
    WHERE b.tipo = 'venta' AND b.empresa_id = v_empresa_id AND b.activo = true
    LIMIT 1;

    IF v_bodega_venta_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT DISTINCT ON (pr.id)
        pr.id,
        mp.nombre::text,
        mp.codigo_barra::text,
        mp.precio_venta::numeric,
        pr.stock_actual::numeric,
        pr.numero_lote::text,
        pr.fecha_vencimiento::date,
        COALESCE(pp.factor_conversion, 1)::numeric,
        (pp.id IS NOT NULL)::boolean,
        pp.nombre_presentacion::text,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM public.productos pr
    JOIN public.maestro_productos mp ON pr.maestro_producto_id = mp.id
    LEFT JOIN public.producto_presentaciones pp ON pp.maestro_producto_id = mp.id
    WHERE pr.bodega_id = v_bodega_venta_id
      AND pr.empresa_id = v_empresa_id
      AND mp.empresa_id = v_empresa_id
      AND pr.stock_actual > 0
      AND (p_search = '' OR mp.nombre ILIKE '%' || p_search || '%'
           OR mp.codigo_barra ILIKE '%' || p_search || '%'
           OR pp.codigo_barra ILIKE '%' || p_search || '%')
    ORDER BY pr.id, pp.factor_conversion ASC;
END;
$$;


-- Fix listar_preventas: columnas ambiguas
DROP FUNCTION IF EXISTS public.listar_preventas CASCADE;

CREATE OR REPLACE FUNCTION public.listar_preventas(
    p_usuario_id uuid DEFAULT NULL,
    p_estado text DEFAULT NULL,
    p_solo_propias boolean DEFAULT false
)
RETURNS TABLE(
    id uuid, codigo_preventa text, estado text, total numeric,
    vendedor_nombre text, cliente_nombre text, cliente_id uuid,
    tipo_venta text, notas_vendedor text, created_at timestamptz,
    items jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
    v_empresa_id uuid;
BEGIN
    SELECT u.empresa_id INTO v_empresa_id FROM public.users u WHERE u.id = p_usuario_id;

    RETURN QUERY
    SELECT
        pv.id,
        pv.codigo_preventa,
        pv.estado::text,
        pv.total,
        u.name::text,
        c.nombre::text,
        pv.cliente_id,
        pv.tipo_venta::text,
        pv.notas_vendedor,
        pv.created_at,
        pv.items
    FROM public.pre_ventas pv
    LEFT JOIN public.users u ON pv.vendedor_id = u.id
    LEFT JOIN public.clientes c ON pv.cliente_id = c.id
    WHERE pv.empresa_id = v_empresa_id
      AND (p_estado IS NULL OR pv.estado::text = p_estado)
      AND (NOT p_solo_propias OR pv.vendedor_id = p_usuario_id)
    ORDER BY
        CASE pv.estado WHEN 'PENDIENTE' THEN 1 WHEN 'BORRADOR' THEN 2 ELSE 3 END,
        pv.created_at DESC;
END;
$$;


-- Fix get_inventory_por_bodega: parametro ambiguo
DROP FUNCTION IF EXISTS public.get_inventory_por_bodega CASCADE;

CREATE OR REPLACE FUNCTION public.get_inventory_por_bodega(p_filtro_bodega uuid DEFAULT NULL)
RETURNS TABLE(
    id uuid, nombre_producto text, codigo_barra text, precio_venta numeric,
    stock_actual numeric, numero_lote text, fecha_vencimiento date,
    bodega_nombre text, factor_conversion numeric, es_presentacion boolean,
    nombre_presentacion text, unidad_medida text, controla_stock boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        pr.id,
        mp.nombre::text,
        mp.codigo_barra::text,
        mp.precio_venta::numeric,
        pr.stock_actual::numeric,
        pr.numero_lote::text,
        pr.fecha_vencimiento::date,
        COALESCE(b.nombre, 'Sin bodega')::text,
        COALESCE(pp.factor_conversion, 1)::numeric,
        (pp.id IS NOT NULL)::boolean,
        pp.nombre_presentacion::text,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM public.productos pr
    JOIN public.maestro_productos mp ON pr.maestro_producto_id = mp.id AND mp.empresa_id = v_empresa_id
    LEFT JOIN public.bodegas b ON pr.bodega_id = b.id AND b.empresa_id = v_empresa_id
    LEFT JOIN public.producto_presentaciones pp ON pp.maestro_producto_id = mp.id AND pp.empresa_id = v_empresa_id
    WHERE pr.empresa_id = v_empresa_id
      AND (p_filtro_bodega IS NULL OR pr.bodega_id = p_filtro_bodega)
      AND pr.stock_actual > 0
    ORDER BY mp.nombre, pr.fecha_vencimiento ASC;
END;
$$;
