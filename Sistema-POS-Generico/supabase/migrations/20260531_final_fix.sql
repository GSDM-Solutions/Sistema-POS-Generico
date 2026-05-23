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
BEGIN
    SELECT s.empresa_id INTO v_empresa_id
    FROM public.inventory_sessions s WHERE s.id = p_session_id;

    IF v_empresa_id IS NULL THEN
        RETURN;
    END IF;

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
        GROUP BY p.maestro_producto_id
    )
    SELECT 
        COALESCE(c.maestro_producto_id, s.maestro_producto_id),
        mp.nombre::text,
        COALESCE(s.total_sistema, 0),
        COALESCE(c.total_fisico, 0),
        (COALESCE(c.total_fisico, 0) - COALESCE(s.total_sistema, 0)),
        ((COALESCE(c.total_fisico, 0) - COALESCE(s.total_sistema, 0)) * COALESCE(mp.precio_venta, 0))
    FROM conteo c
    FULL OUTER JOIN sistema s ON c.maestro_producto_id = s.maestro_producto_id
    JOIN public.maestro_productos mp ON mp.id = COALESCE(c.maestro_producto_id, s.maestro_producto_id)
    WHERE mp.empresa_id = v_empresa_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.analizar_diferencias_inventario(uuid) TO authenticated, anon;

ALTER FUNCTION public.analizar_diferencias_inventario(uuid) OWNER TO postgres;


DROP FUNCTION IF EXISTS public.aplicar_ajuste_inventario(uuid, uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.aplicar_ajuste_inventario(
    p_session_id uuid,
    p_usuario_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
    v_row RECORD;
    v_cantidad_restante NUMERIC;
    v_lote RECORD;
    v_cantidad_a_descontar NUMERIC;
    v_producto_id UUID;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.inventory_sessions WHERE id = p_session_id;
    
    IF v_empresa_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE public.inventory_sessions SET estado = 'APPLIED' WHERE id = p_session_id;

    FOR v_row IN SELECT * FROM public.analizar_diferencias_inventario(p_session_id)
    LOOP
        INSERT INTO public.inventory_session_results (
            session_id, maestro_producto_id, nombre_producto, stock_sistema_snapshot,
            stock_fisico_final, diferencia, valor_ajuste
        ) VALUES (
            p_session_id, v_row.maestro_producto_id, v_row.nombre_producto,
            v_row.stock_sistema, v_row.stock_fisico, v_row.diferencia, v_row.valor_ajuste
        );

        IF v_row.diferencia > 0 THEN
            INSERT INTO public.productos (
                maestro_producto_id, empresa_id, stock_actual,
                numero_lote, condicion, creado_en, fecha_vencimiento
            ) VALUES (
                v_row.maestro_producto_id, v_empresa_id, v_row.diferencia,
                'AJUSTE-' || TO_CHAR(NOW(), 'YYYYMMDD'), 'Bueno', NOW(), NULL
            ) RETURNING id INTO v_producto_id;
            
            INSERT INTO public.movimientos (
                producto_id, tipo_movimiento, cantidad, usuario_id, empresa_id,
                motivo, condicion, creado_en
            ) VALUES (
                v_producto_id, 'entrada', v_row.diferencia, p_usuario_id, v_empresa_id,
                'Auditoria Inventario (Sobrante)', 'Bueno', NOW()
            );

        ELSIF v_row.diferencia < 0 THEN
            v_cantidad_restante := ABS(v_row.diferencia);
            
            FOR v_lote IN 
                SELECT id, stock_actual 
                FROM public.productos 
                WHERE maestro_producto_id = v_row.maestro_producto_id 
                  AND empresa_id = v_empresa_id
                  AND stock_actual > 0
                ORDER BY fecha_vencimiento ASC NULLS LAST, creado_en ASC
            LOOP
                IF v_cantidad_restante <= 0 THEN EXIT; END IF;
                
                v_cantidad_a_descontar := LEAST(v_lote.stock_actual, v_cantidad_restante);
                
                UPDATE public.productos 
                SET stock_actual = stock_actual - v_cantidad_a_descontar
                WHERE id = v_lote.id;
                
                INSERT INTO public.movimientos (
                    producto_id, tipo_movimiento, cantidad, usuario_id, empresa_id,
                    motivo, condicion, creado_en
                ) VALUES (
                    v_lote.id, 'salida', v_cantidad_a_descontar, p_usuario_id, v_empresa_id,
                    'Auditoria Inventario (Faltante)', 'Bueno', NOW()
                );
                
                v_cantidad_restante := v_cantidad_restante - v_cantidad_a_descontar;
            END LOOP;
        END IF;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.aplicar_ajuste_inventario(uuid, uuid) TO authenticated, anon;

ALTER FUNCTION public.aplicar_ajuste_inventario(uuid, uuid) OWNER TO postgres;
