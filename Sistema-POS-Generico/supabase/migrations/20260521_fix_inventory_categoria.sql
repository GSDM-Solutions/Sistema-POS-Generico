-- Fix: agregar columna categoria a get_inventory_por_bodega
DROP FUNCTION IF EXISTS public.get_inventory_por_bodega(uuid);

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
    controla_stock boolean,
    categoria text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        p.id,
        mp.nombre::text,
        mp.codigo_barra::text,
        mp.precio_venta::numeric,
        p.stock_actual::numeric,
        p.numero_lote::text,
        p.fecha_vencimiento::date,
        COALESCE(b.nombre, 'Sin bodega')::text,
        COALESCE(pp.factor_conversion, 1)::numeric,
        (pp.id IS NOT NULL)::boolean,
        pp.nombre_presentacion::text,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean,
        COALESCE(mp.categoria, '')::text
    FROM public.productos p
    JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id AND mp.empresa_id = v_empresa_id
    LEFT JOIN public.bodegas b ON p.bodega_id = b.id AND b.empresa_id = v_empresa_id
    LEFT JOIN public.producto_presentaciones pp ON pp.maestro_producto_id = mp.id AND pp.empresa_id = v_empresa_id
    WHERE p.empresa_id = v_empresa_id
      AND (p_filtro_bodega IS NULL OR p.bodega_id = p_filtro_bodega)
      AND p.stock_actual > 0
    ORDER BY mp.nombre, p.fecha_vencimiento ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_inventory_por_bodega(uuid) TO authenticated, anon;
