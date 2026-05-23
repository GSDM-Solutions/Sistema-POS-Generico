DROP FUNCTION IF EXISTS public.analizar_diferencias_inventario(uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.analizar_diferencias_inventario(p_session_id uuid)
RETURNS TABLE(
    maestro_producto_id uuid,
    nombre_producto text,
    stock_sistema numeric,
    stock_fisico numeric,
    diferencia numeric,
    valor_ajuste numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
    v_tipo TEXT;
    v_bodega_id UUID;
BEGIN
    BEGIN
        SELECT s.empresa_id, s.tipo, s.bodega_id INTO v_empresa_id, v_tipo, v_bodega_id
        FROM public.inventory_sessions s WHERE s.id = p_session_id;
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;

    IF v_empresa_id IS NULL THEN
        RETURN;
    END IF;

    IF v_tipo = 'SELECTIVO' OR v_tipo = 'AJUSTE_DIRECTO' THEN
        RETURN QUERY
        WITH conteo AS (
            SELECT 
                ic.maestro_producto_id,
                COALESCE(SUM(ic.cantidad_escaneada * ic.factor_conversion), 0) as total_fisico
            FROM public.inventory_counts ic
            JOIN public.maestro_productos mp ON ic.maestro_producto_id = mp.id
            WHERE ic.session_id = p_session_id
              AND mp.empresa_id = v_empresa_id 
            GROUP BY ic.maestro_producto_id
        ),
        sistema AS (
            SELECT 
                p.maestro_producto_id,
                COALESCE(SUM(p.stock_actual), 0) as total_sistema
            FROM public.productos p
            WHERE p.empresa_id = v_empresa_id
              AND p.stock_actual > 0
              AND (v_bodega_id IS NULL OR p.bodega_id = v_bodega_id)
            GROUP BY p.maestro_producto_id
        )
        SELECT 
            c.maestro_producto_id,
            mp.nombre,
            COALESCE(s.total_sistema, 0),
            c.total_fisico,
            (c.total_fisico - COALESCE(s.total_sistema, 0)),
            ((c.total_fisico - COALESCE(s.total_sistema, 0)) * COALESCE(mp.precio_compra, 0))
        FROM conteo c
        LEFT JOIN sistema s ON c.maestro_producto_id = s.maestro_producto_id
        JOIN public.maestro_productos mp ON mp.id = c.maestro_producto_id
        WHERE mp.empresa_id = v_empresa_id;

    ELSE
        RETURN QUERY
        WITH conteo AS (
            SELECT 
                ic.maestro_producto_id,
                COALESCE(SUM(ic.cantidad_escaneada * ic.factor_conversion), 0) as total_fisico
            FROM public.inventory_counts ic
            JOIN public.maestro_productos mp ON ic.maestro_producto_id = mp.id
            WHERE ic.session_id = p_session_id
              AND mp.empresa_id = v_empresa_id 
            GROUP BY ic.maestro_producto_id
        ),
        sistema AS (
            SELECT 
                p.maestro_producto_id,
                COALESCE(SUM(p.stock_actual), 0) as total_sistema
            FROM public.productos p
            WHERE p.empresa_id = v_empresa_id
              AND p.stock_actual > 0
              AND (v_bodega_id IS NULL OR p.bodega_id = v_bodega_id)
            GROUP BY p.maestro_producto_id
        )
        SELECT 
            COALESCE(c.maestro_producto_id, s.maestro_producto_id),
            mp.nombre,
            COALESCE(s.total_sistema, 0),
            COALESCE(c.total_fisico, 0),
            (COALESCE(c.total_fisico, 0) - COALESCE(s.total_sistema, 0)),
            ((COALESCE(c.total_fisico, 0) - COALESCE(s.total_sistema, 0)) * COALESCE(mp.precio_compra, 0))
        FROM conteo c
        FULL OUTER JOIN sistema s ON c.maestro_producto_id = s.maestro_producto_id
        JOIN public.maestro_productos mp ON mp.id = COALESCE(c.maestro_producto_id, s.maestro_producto_id)
        WHERE mp.empresa_id = v_empresa_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.analizar_diferencias_inventario(uuid) TO authenticated, anon;
