-- ==============================================================================
-- MIGRACION: MODULOS DE AUDITORIA V2 - Conteo General, Selectivo y Ajuste Directo
-- Fecha: 2026-05-22
-- Objetivo: Soportar 3 tipos de auditoria:
--   GENERAL:     Cuenta todo. Productos no escaneados se ajustan a cero.
--   SELECTIVO:   Solo cuenta los SKUs escaneados. No afecta productos no contados.
--   AJUSTE_DIRECTO: Ajuste manual por consumo, rotura, caida a piso, etc.
-- ==============================================================================

-- 1. AGREGAR COLUMNAS A inventory_sessions ====================================

ALTER TABLE public.inventory_sessions
ADD COLUMN IF NOT EXISTS tipo TEXT DEFAULT 'GENERAL'
CHECK (tipo IN ('GENERAL', 'SELECTIVO', 'AJUSTE_DIRECTO'));

ALTER TABLE public.inventory_sessions
ADD COLUMN IF NOT EXISTS motivo_ajuste TEXT;

ALTER TABLE public.inventory_sessions
ADD COLUMN IF NOT EXISTS bodega_id UUID REFERENCES public.bodegas(id);

-- 2. MODIFICAR analizar_diferencias_inventario =================================
-- Respetar el tipo de sesion: SELECTIVO solo muestra productos contados

DROP FUNCTION IF EXISTS public.analizar_diferencias_inventario(uuid);

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
    SELECT empresa_id, tipo, bodega_id INTO v_empresa_id, v_tipo, v_bodega_id
    FROM public.inventory_sessions WHERE id = p_session_id;
    
    IF v_empresa_id IS NULL THEN
        RAISE EXCEPTION 'Sesion de inventario sin empresa asignada';
    END IF;

    IF v_tipo = 'SELECTIVO' OR v_tipo = 'AJUSTE_DIRECTO' THEN
        -- SELECTIVO / AJUSTE_DIRECTO: Solo productos contados, no afecta los no escaneados
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
            c.maestro_producto_id as m_id,
            mp.nombre::text,
            COALESCE(s.total_sistema, 0) as stock_sys,
            c.total_fisico as stock_fis,
            (c.total_fisico - COALESCE(s.total_sistema, 0)) as diff,
            ((c.total_fisico - COALESCE(s.total_sistema, 0)) * COALESCE(mp.precio_compra, 0)) as val
        FROM conteo c
        LEFT JOIN sistema s ON c.maestro_producto_id = s.maestro_producto_id
        JOIN public.maestro_productos mp ON mp.id = c.maestro_producto_id
        WHERE mp.empresa_id = v_empresa_id;

    ELSE
        -- GENERAL: FULL OUTER JOIN. Productos no escaneados aparecen con stock_fisico = 0
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
            COALESCE(c.maestro_producto_id, s.maestro_producto_id) as m_id,
            mp.nombre::text,
            COALESCE(s.total_sistema, 0) as stock_sys,
            COALESCE(c.total_fisico, 0) as stock_fis,
            (COALESCE(c.total_fisico, 0) - COALESCE(s.total_sistema, 0)) as diff,
            ((COALESCE(c.total_fisico, 0) - COALESCE(s.total_sistema, 0)) * COALESCE(mp.precio_compra, 0)) as val
        FROM conteo c
        FULL OUTER JOIN sistema s ON c.maestro_producto_id = s.maestro_producto_id
        JOIN public.maestro_productos mp ON mp.id = COALESCE(c.maestro_producto_id, s.maestro_producto_id)
        WHERE mp.empresa_id = v_empresa_id;
    END IF;
END;
$$;

-- 3. MODIFICAR aplicar_ajuste_inventario =======================================
-- Asegurar que respeta bodega_id de la sesion

DROP FUNCTION IF EXISTS public.aplicar_ajuste_inventario(uuid, uuid);

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
    SELECT empresa_id, bodega_id, tipo, motivo_ajuste
    INTO v_empresa_id, v_bodega_id, v_tipo, v_motivo
    FROM public.inventory_sessions WHERE id = p_session_id;
    
    IF v_empresa_id IS NULL THEN
        RAISE EXCEPTION 'Sesion invalida o sin empresa';
    END IF;

    IF v_tipo = 'AJUSTE_DIRECTO' THEN
        v_motivo_base := COALESCE(v_motivo, 'Ajuste Directo');
    ELSE
        v_motivo_base := 'Auditoria Inventario';
    END IF;

    -- Marcar sesion como APLICADA
    UPDATE public.inventory_sessions SET estado = 'APPLIED' WHERE id = p_session_id;

    -- Iterar sobre las diferencias calculadas
    FOR v_row IN SELECT * FROM public.analizar_diferencias_inventario(p_session_id)
    LOOP
        -- Guardar resultado estatico en historial
        INSERT INTO public.inventory_session_results (
            session_id, maestro_producto_id, nombre_producto, stock_sistema_snapshot,
            stock_fisico_final, diferencia, valor_ajuste
        ) VALUES (
            p_session_id, v_row.maestro_producto_id, v_row.nombre_producto,
            v_row.stock_sistema, v_row.stock_fisico, v_row.diferencia, v_row.valor_ajuste
        );

        IF v_row.diferencia > 0 THEN
            -- SOBRANTE: Crear lote de ajuste
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
            -- FALTANTE: Descontar FIFO
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

-- 4. NUEVA RPC: registrar_ajuste_directo =======================================
-- Para ajustes por consumo, caida a piso, roto, etc.
-- Crea la sesion, inserta el conteo y aplica el ajuste en una sola llamada.

CREATE OR REPLACE FUNCTION public.registrar_ajuste_directo(
    p_maestro_producto_id UUID,
    p_bodega_id UUID,
    p_cantidad_diferencia NUMERIC,
    p_motivo TEXT,
    p_usuario_id UUID,
    p_empresa_id UUID
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID;
    v_stock_sistema NUMERIC;
BEGIN
    -- Validaciones basicas
    IF p_cantidad_diferencia = 0 THEN
        RAISE EXCEPTION 'La cantidad de ajuste no puede ser cero';
    END IF;

    IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
        RAISE EXCEPTION 'El motivo del ajuste es obligatorio';
    END IF;

    -- Calcular stock actual del sistema para este producto en la bodega
    SELECT COALESCE(SUM(pr.stock_actual), 0) INTO v_stock_sistema
    FROM public.productos pr
    WHERE pr.maestro_producto_id = p_maestro_producto_id
      AND pr.empresa_id = p_empresa_id
      AND (p_bodega_id IS NULL OR pr.bodega_id = p_bodega_id)
      AND pr.stock_actual > 0;

    -- Si es un faltante (negativo), validar que haya stock suficiente
    IF p_cantidad_diferencia < 0 AND v_stock_sistema < ABS(p_cantidad_diferencia) THEN
        RAISE EXCEPTION 'Stock insuficiente. Sistema: %, Intento ajustar: %',
            v_stock_sistema, ABS(p_cantidad_diferencia);
    END IF;

    -- Crear sesion de tipo AJUSTE_DIRECTO (ya aplicada)
    INSERT INTO public.inventory_sessions (
        nombre, estado, tipo, creado_por, empresa_id, bodega_id, motivo_ajuste
    ) VALUES (
        'Ajuste Directo - ' || p_motivo,
        'COUNTING',
        'AJUSTE_DIRECTO',
        p_usuario_id,
        p_empresa_id,
        p_bodega_id,
        p_motivo
    ) RETURNING id INTO v_session_id;

    -- Insertar conteo con la cantidad fisica deseada (stock_sistema - cantidad_a_ajustar)
    -- Para que la diferencia sea exactamente p_cantidad_diferencia:
    -- stock_fisico - stock_sistema = p_cantidad_diferencia
    -- => stock_fisico = stock_sistema + p_cantidad_diferencia
    INSERT INTO public.inventory_counts (
        session_id,
        maestro_producto_id,
        codigo_escaneado,
        cantidad_escaneada,
        factor_conversion,
        usuario_id
    ) VALUES (
        v_session_id,
        p_maestro_producto_id,
        (SELECT codigo_barra FROM public.maestro_productos WHERE id = p_maestro_producto_id LIMIT 1),
        v_stock_sistema + p_cantidad_diferencia,
        1,
        p_usuario_id
    );

    -- Aplicar el ajuste
    PERFORM public.aplicar_ajuste_inventario(v_session_id, p_usuario_id);

    RETURN v_session_id;
END;
$$;

-- 5. PERMISOS ==================================================================

GRANT EXECUTE ON FUNCTION public.analizar_diferencias_inventario(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.aplicar_ajuste_inventario(uuid, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.registrar_ajuste_directo(uuid, uuid, numeric, text, uuid, uuid) TO authenticated;
