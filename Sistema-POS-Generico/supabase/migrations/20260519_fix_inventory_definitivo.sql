-- Fix definitivo: quitar SET search_path que rompe PostgREST
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
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        pr.id::uuid,
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

GRANT EXECUTE ON FUNCTION public.get_inventory_por_bodega(uuid) TO authenticated, anon;
NOTIFY pgrst, 'reload schema';
