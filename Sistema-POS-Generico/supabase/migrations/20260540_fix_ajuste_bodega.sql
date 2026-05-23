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
    v_bodega_id UUID;
    v_tipo TEXT;
    v_motivo TEXT;
    v_row RECORD;
    v_cantidad_restante NUMERIC;
    v_lote RECORD;
    v_cantidad_a_descontar NUMERIC;
    v_producto_id UUID;
    v_motivo_base TEXT;
BEGIN
    SELECT s.empresa_id, s.bodega_id, s.tipo, s.motivo_ajuste
    INTO v_empresa_id, v_bodega_id, v_tipo, v_motivo
    FROM public.inventory_sessions s WHERE s.id = p_session_id;

    IF v_empresa_id IS NULL THEN
        RETURN;
    END IF;

    IF v_tipo = 'AJUSTE_DIRECTO' THEN
        v_motivo_base := COALESCE(v_motivo, 'Ajuste Directo');
    ELSE
        v_motivo_base := 'Auditoria Inventario';
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
                maestro_producto_id, empresa_id, bodega_id, stock_actual,
                numero_lote, condicion, creado_en, fecha_vencimiento
            ) VALUES (
                v_row.maestro_producto_id, v_empresa_id, v_bodega_id, v_row.diferencia,
                'AJUSTE-' || TO_CHAR(NOW(), 'YYYYMMDD'), 'Bueno', NOW(), NULL
            ) RETURNING id INTO v_producto_id;

            INSERT INTO public.movimientos (
                producto_id, tipo_movimiento, cantidad, usuario_id, empresa_id,
                motivo, condicion, creado_en
            ) VALUES (
                v_producto_id, 'entrada', v_row.diferencia, p_usuario_id, v_empresa_id,
                v_motivo_base || ' (Sobrante)', 'Bueno', NOW()
            );

        ELSIF v_row.diferencia < 0 THEN
            v_cantidad_restante := ABS(v_row.diferencia);

            FOR v_lote IN
                SELECT id, stock_actual
                FROM public.productos
                WHERE maestro_producto_id = v_row.maestro_producto_id
                  AND empresa_id = v_empresa_id
                  AND stock_actual > 0
                  AND (v_bodega_id IS NULL OR bodega_id = v_bodega_id)
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
                    v_motivo_base || ' (Faltante)', 'Bueno', NOW()
                );

                v_cantidad_restante := v_cantidad_restante - v_cantidad_a_descontar;
            END LOOP;
        END IF;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.aplicar_ajuste_inventario(uuid, uuid) TO authenticated, anon;
ALTER FUNCTION public.aplicar_ajuste_inventario(uuid, uuid) OWNER TO postgres;
