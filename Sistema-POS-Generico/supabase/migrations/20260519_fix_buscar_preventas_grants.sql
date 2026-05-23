-- Fix buscar_preventa_por_codigo: estructura de retorno + grants

DROP FUNCTION IF EXISTS public.buscar_preventa_por_codigo CASCADE;

CREATE OR REPLACE FUNCTION public.buscar_preventa_por_codigo(p_codigo text)
RETURNS TABLE(
    id uuid, codigo_preventa text, estado text, total numeric,
    items jsonb, vendedor_nombre text, vendedor_id uuid,
    cliente_nombre text, cliente_id uuid, tipo_venta text,
    notas_vendedor text
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
        pv.id::uuid,
        pv.codigo_preventa::text,
        pv.estado::text,
        pv.total::numeric,
        pv.items::jsonb,
        COALESCE(u.name, '')::text,
        pv.vendedor_id::uuid,
        COALESCE(c.nombre, '')::text,
        pv.cliente_id::uuid,
        pv.tipo_venta::text,
        COALESCE(pv.notas_vendedor, '')::text
    FROM public.pre_ventas pv
    LEFT JOIN public.users u ON pv.vendedor_id = u.id
    LEFT JOIN public.clientes c ON pv.cliente_id = c.id
    WHERE pv.codigo_preventa ILIKE p_codigo
      AND pv.empresa_id = v_empresa_id
      AND pv.estado = 'PENDIENTE'
    LIMIT 1;
END;
$$;

-- Restaurar grants para todas las funciones recreadas
GRANT EXECUTE ON FUNCTION public.buscar_preventa_por_codigo(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_products_pos_bodega(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_inventory_por_bodega(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.listar_preventas(uuid, text, boolean) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_products_pos(text) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
