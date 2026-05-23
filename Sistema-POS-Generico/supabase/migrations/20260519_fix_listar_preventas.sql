-- Fix listar_preventas: estructura de retorno
DROP FUNCTION IF EXISTS public.listar_preventas CASCADE;

CREATE OR REPLACE FUNCTION public.listar_preventas(
    p_usuario_id uuid DEFAULT NULL,
    p_estado text DEFAULT NULL,
    p_solo_propias boolean DEFAULT false
)
RETURNS TABLE(
    id uuid,
    codigo_preventa text,
    estado text,
    total numeric,
    vendedor_nombre text,
    cliente_nombre text,
    cliente_id uuid,
    tipo_venta text,
    notas_vendedor text,
    created_at timestamptz,
    items jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    SELECT u.empresa_id INTO v_empresa_id FROM public.users u WHERE u.id = p_usuario_id;

    RETURN QUERY
    SELECT
        pv.id::uuid,
        pv.codigo_preventa::text,
        pv.estado::text AS estado,
        pv.total::numeric,
        COALESCE(u.name, '')::text,
        COALESCE(c.nombre, '')::text,
        pv.cliente_id::uuid,
        pv.tipo_venta::text,
        COALESCE(pv.notas_vendedor, '')::text,
        pv.created_at::timestamptz,
        pv.items::jsonb
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
