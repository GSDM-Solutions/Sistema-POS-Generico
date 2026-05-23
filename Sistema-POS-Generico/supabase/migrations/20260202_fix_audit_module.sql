-- ==============================================================================
-- MIGRACIÓN: CORRECCIÓN INTEGRAL MÓDULO AUDITORÍA (MULTI-EMPRESA)
-- Fecha: 2026-02-02
-- Objetivo: Asegurar tablas, RLS y funciones para auditoría aislada por empresa
-- ==============================================================================

-- 1. ASEGURAR ESTRUCTURA DE TABLAS ============================================

-- Tabla de Sesiones
CREATE TABLE IF NOT EXISTS public.inventory_sessions (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    nombre text NOT NULL,
    estado text DEFAULT 'OPEN' CHECK (estado IN ('OPEN', 'COUNTING', 'REVIEW', 'APPLIED', 'CANCELLED')),
    creado_por uuid REFERENCES auth.users(id),
    empresa_id uuid REFERENCES public.empresas(id), -- Vital para multi-empresa
    fecha_inicio timestamptz DEFAULT now(),
    fecha_fin timestamptz,
    observaciones text
);

-- Tabla de Conteos (Detalle)
CREATE TABLE IF NOT EXISTS public.inventory_counts (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    session_id uuid REFERENCES public.inventory_sessions(id) ON DELETE CASCADE,
    maestro_producto_id uuid REFERENCES public.maestro_productos(id),
    codigo_escaneado text,
    cantidad_escaneada numeric DEFAULT 1,
    factor_conversion numeric DEFAULT 1,
    usuario_id uuid REFERENCES auth.users(id),
    creado_en timestamptz DEFAULT now()
);

-- Tabla de Resultados (Snapshot/Histórico)
CREATE TABLE IF NOT EXISTS public.inventory_session_results (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    session_id uuid REFERENCES public.inventory_sessions(id) ON DELETE CASCADE,
    maestro_producto_id uuid REFERENCES public.maestro_productos(id),
    nombre_producto text,
    stock_sistema_snapshot numeric,
    stock_fisico_final numeric,
    diferencia numeric,
    valor_ajuste numeric,
    creado_en timestamptz DEFAULT now()
);

-- Asegurar que empresa_id exista en inventory_sessions (si la tabla ya existía)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'inventory_sessions' AND column_name = 'empresa_id') THEN
        ALTER TABLE public.inventory_sessions ADD COLUMN empresa_id uuid REFERENCES public.empresas(id);
    END IF;
END $$;


-- 2. SEGURIDAD RLS (ROW LEVEL SECURITY) =======================================

-- Habilitar RLS
ALTER TABLE public.inventory_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_session_results ENABLE ROW LEVEL SECURITY;

-- Limpiar políticas antiguas (Evitar duplicados/conflictos)
DROP POLICY IF EXISTS "Admin y Bodega ven sesiones" ON public.inventory_sessions;
DROP POLICY IF EXISTS "Inventory Sessions Policy" ON public.inventory_sessions;
DROP POLICY IF EXISTS "Sesiones por empresa" ON public.inventory_sessions;

DROP POLICY IF EXISTS "Admin y Bodega gestionan conteos" ON public.inventory_counts;
DROP POLICY IF EXISTS "Conteos por empresa (via session)" ON public.inventory_counts;

DROP POLICY IF EXISTS "Admin y Bodega ven resultados" ON public.inventory_session_results;
DROP POLICY IF EXISTS "Resultados por empresa (via session)" ON public.inventory_session_results;

-- Crear NUEVAS Políticas Multi-Empresa

-- A) Sesiones: Ver y Crear solo para mi empresa
CREATE POLICY "Sesiones por empresa" ON public.inventory_sessions
    USING (empresa_id = (SELECT empresa_id FROM public.users WHERE id = auth.uid()))
    WITH CHECK (empresa_id = (SELECT empresa_id FROM public.users WHERE id = auth.uid()));

-- B) Conteos: Acceso si tengo acceso a la sesión padre (Join implícito seguro)
CREATE POLICY "Conteos por empresa" ON public.inventory_counts
    USING (
        EXISTS (
            SELECT 1 FROM public.inventory_sessions s
            WHERE s.id = inventory_counts.session_id
            AND s.empresa_id = (SELECT empresa_id FROM public.users WHERE id = auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.inventory_sessions s
            WHERE s.id = inventory_counts.session_id
            AND s.empresa_id = (SELECT empresa_id FROM public.users WHERE id = auth.uid())
        )
    );

-- C) Resultados: Igual que conteos, acceso via sesión padre
CREATE POLICY "Resultados por empresa" ON public.inventory_session_results
    USING (
        EXISTS (
            SELECT 1 FROM public.inventory_sessions s
            WHERE s.id = inventory_session_results.session_id
            AND s.empresa_id = (SELECT empresa_id FROM public.users WHERE id = auth.uid())
        )
    );


-- 3. FUNCIONES RPC (LÓGICA DE NEGOCIO) ========================================

-- A) Analizar Diferencias (Comparar Fisico vs Sistema de LA EMPRESA)
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
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.inventory_sessions WHERE id = p_session_id;
    
    IF v_empresa_id IS NULL THEN
        RAISE EXCEPTION 'Sesión de inventario sin empresa asignada';
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
END;
$$;

-- B) Aplicar Ajuste (Impactar Stock y Cerrar Sesión)
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
    v_row RECORD;
    v_cantidad_restante NUMERIC;
    v_lote RECORD;
    v_cantidad_a_descontar NUMERIC;
    v_producto_id UUID;
BEGIN
    -- Obtener empresa
    SELECT empresa_id INTO v_empresa_id FROM public.inventory_sessions WHERE id = p_session_id;
    
    IF v_empresa_id IS NULL THEN
        RAISE EXCEPTION 'Sesión inválida o sin empresa';
    END IF;

    -- Marcar sesión como APLICADA
    UPDATE public.inventory_sessions SET estado = 'APPLIED' WHERE id = p_session_id;

    -- Iterar sobre las diferencias calculadas
    FOR v_row IN SELECT * FROM public.analizar_diferencias_inventario(p_session_id)
    LOOP
        -- Guardar resultado estático en historial
        INSERT INTO public.inventory_session_results (
            session_id, maestro_producto_id, nombre_producto, stock_sistema_snapshot, stock_fisico_final, diferencia, valor_ajuste
        ) VALUES (
            p_session_id, v_row.maestro_producto_id, v_row.nombre_producto, v_row.stock_sistema, v_row.stock_fisico, v_row.diferencia, v_row.valor_ajuste
        );

        IF v_row.diferencia > 0 THEN
            -- SOBRANTE: Crear lote de ajuste
            INSERT INTO public.productos (
                maestro_producto_id, empresa_id, stock_actual, numero_lote, condicion, creado_en, fecha_vencimiento
            ) VALUES (
                v_row.maestro_producto_id, v_empresa_id, v_row.diferencia, 'AJUSTE-' || TO_CHAR(NOW(), 'YYYYMMDD'), 'Bueno', NOW(), NULL
            ) RETURNING id INTO v_producto_id;
            
            INSERT INTO public.movimientos (
                producto_id, tipo_movimiento, cantidad, usuario_id, empresa_id, motivo, condicion, creado_en
            ) VALUES (
                v_producto_id, 'entrada', v_row.diferencia, p_usuario_id, v_empresa_id, 'Auditoría Inventario (Sobrante)', 'Bueno', NOW()
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
                ORDER BY fecha_vencimiento ASC NULLS LAST, creado_en ASC
            LOOP
                IF v_cantidad_restante <= 0 THEN EXIT; END IF;
                
                v_cantidad_a_descontar := LEAST(v_lote.stock_actual, v_cantidad_restante);
                
                UPDATE public.productos 
                SET stock_actual = stock_actual - v_cantidad_a_descontar
                WHERE id = v_lote.id;
                
                INSERT INTO public.movimientos (
                    producto_id, tipo_movimiento, cantidad, usuario_id, empresa_id, motivo, condicion, creado_en
                ) VALUES (
                    v_lote.id, 'salida', v_cantidad_a_descontar, p_usuario_id, v_empresa_id, 'Auditoría Inventario (Faltante)', 'Bueno', NOW()
                );
                
                v_cantidad_restante := v_cantidad_restante - v_cantidad_a_descontar;
            END LOOP;
        END IF;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.analizar_diferencias_inventario(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.aplicar_ajuste_inventario(uuid, uuid) TO authenticated, anon;
