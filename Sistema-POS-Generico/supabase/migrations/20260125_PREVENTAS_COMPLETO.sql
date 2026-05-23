-- =====================================================
-- SISTEMA COMPLETO DE PRE-VENTAS CON CÓDIGOS
-- Ejecutar COMPLETO en SQL Editor de Supabase
-- Fecha: 25 Enero 2026
-- =====================================================

-- 1. CREAR TIPO ENUM PARA ESTADOS
DO $$ BEGIN
    CREATE TYPE estado_preventa AS ENUM (
        'BORRADOR',
        'PENDIENTE',
        'CONFIRMADA',
        'RECHAZADA',
        'CANCELADA'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. CREAR TABLA PRE_VENTAS
CREATE TABLE IF NOT EXISTS public.pre_ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo_preventa VARCHAR(20) UNIQUE, -- CÓDIGO CORTO
    
    -- Relaciones
    vendedor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    cajero_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES public.clientes(id) ON DELETE SET NULL,
    
    -- Estado y flujo
    estado estado_preventa NOT NULL DEFAULT 'BORRADOR',
    
    -- Datos de la venta
    items JSONB NOT NULL,
    total NUMERIC(12,2) NOT NULL DEFAULT 0,
    tipo_venta tipo_venta NOT NULL DEFAULT 'BOLETA',
    
    -- Notas y observaciones
    notas_vendedor TEXT,
    notas_cajero TEXT,
    motivo_rechazo TEXT,
    
    -- Auditoría
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    enviada_at TIMESTAMPTZ,
    confirmada_at TIMESTAMPTZ,
    
    -- Folio de venta real
    venta_id UUID REFERENCES public.ventas(id) ON DELETE SET NULL,
    
    CONSTRAINT chk_total_positivo CHECK (total >= 0),
    CONSTRAINT chk_items_no_vacio CHECK (jsonb_array_length(items) > 0)
);

-- 3. ÍNDICES
CREATE INDEX IF NOT EXISTS idx_preventas_vendedor ON public.pre_ventas(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_preventas_estado ON public.pre_ventas(estado);
CREATE INDEX IF NOT EXISTS idx_preventas_created ON public.pre_ventas(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_preventas_cajero ON public.pre_ventas(cajero_id) WHERE cajero_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_preventas_codigo ON public.pre_ventas(codigo_preventa);

-- 4. SECUENCIA PARA CÓDIGOS
CREATE SEQUENCE IF NOT EXISTS preventa_codigo_seq START 1000;

-- 5. FUNCIÓN PARA GENERAR CÓDIGO
CREATE OR REPLACE FUNCTION generar_codigo_preventa()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo TEXT;
    v_numero INT;
BEGIN
    v_numero := nextval('preventa_codigo_seq');
    v_codigo := 'PV-' || LPAD(v_numero::TEXT, 4, '0');
    RETURN v_codigo;
END;
$$;

-- 6. TRIGGER PARA ASIGNAR CÓDIGO AUTOMÁTICAMENTE
CREATE OR REPLACE FUNCTION asignar_codigo_preventa()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.codigo_preventa IS NULL THEN
        NEW.codigo_preventa := generar_codigo_preventa();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_asignar_codigo_preventa ON public.pre_ventas;
CREATE TRIGGER trg_asignar_codigo_preventa
    BEFORE INSERT ON public.pre_ventas
    FOR EACH ROW
    EXECUTE FUNCTION asignar_codigo_preventa();

-- 7. TRIGGER PARA ACTUALIZAR updated_at
CREATE OR REPLACE FUNCTION update_preventa_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_preventas_updated_at ON public.pre_ventas;
CREATE TRIGGER trg_preventas_updated_at
    BEFORE UPDATE ON public.pre_ventas
    FOR EACH ROW
    EXECUTE FUNCTION update_preventa_timestamp();

-- =====================================================
-- FUNCIONES RPC
-- =====================================================

-- RPC 1: CREAR PRE-VENTA
CREATE OR REPLACE FUNCTION public.crear_preventa(
    p_vendedor_id UUID,
    p_cliente_id UUID,
    p_items JSONB,
    p_tipo_venta TEXT,
    p_notas TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_preventa_id UUID;
    v_total NUMERIC(12,2) := 0;
    v_item JSONB;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = p_vendedor_id 
        AND role IN ('vendedor', 'admin')
    ) THEN
        RAISE EXCEPTION 'Usuario no autorizado para crear pre-ventas';
    END IF;
    
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_total := v_total + (
            (v_item->>'cantidad')::numeric * (v_item->>'precio')::numeric
        );
    END LOOP;
    
    INSERT INTO public.pre_ventas (
        vendedor_id,
        cliente_id,
        items,
        total,
        tipo_venta,
        notas_vendedor,
        estado
    ) VALUES (
        p_vendedor_id,
        p_cliente_id,
        p_items,
        v_total,
        p_tipo_venta::tipo_venta,
        p_notas,
        'BORRADOR'
    ) RETURNING id INTO v_preventa_id;
    
    RETURN v_preventa_id;
END;
$$;

-- RPC 2: ENVIAR PRE-VENTA
CREATE OR REPLACE FUNCTION public.enviar_preventa(
    p_preventa_id UUID,
    p_vendedor_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.pre_ventas
        WHERE id = p_preventa_id
        AND vendedor_id = p_vendedor_id
        AND estado = 'BORRADOR'
    ) THEN
        RAISE EXCEPTION 'Pre-venta no encontrada o no se puede enviar';
    END IF;
    
    UPDATE public.pre_ventas
    SET estado = 'PENDIENTE',
        enviada_at = NOW()
    WHERE id = p_preventa_id;
    
    RETURN TRUE;
END;
$$;

-- RPC 3: LISTAR PRE-VENTAS
CREATE OR REPLACE FUNCTION public.listar_preventas(
    p_usuario_id UUID,
    p_estado estado_preventa DEFAULT NULL,
    p_solo_propias BOOLEAN DEFAULT FALSE
) RETURNS TABLE (
    id UUID,
    codigo_preventa TEXT,
    vendedor_nombre TEXT,
    vendedor_id UUID,
    cajero_nombre TEXT,
    cliente_nombre TEXT,
    estado estado_preventa,
    total NUMERIC,
    tipo_venta tipo_venta,
    items JSONB,
    notas_vendedor TEXT,
    notas_cajero TEXT,
    created_at TIMESTAMPTZ,
    enviada_at TIMESTAMPTZ,
    confirmada_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pv.id,
        pv.codigo_preventa,
        u_vendedor.email AS vendedor_nombre,
        pv.vendedor_id,
        u_cajero.email AS cajero_nombre,
        c.nombre AS cliente_nombre,
        pv.estado,
        pv.total,
        pv.tipo_venta,
        pv.items,
        pv.notas_vendedor,
        pv.notas_cajero,
        pv.created_at,
        pv.enviada_at,
        pv.confirmada_at
    FROM public.pre_ventas pv
    LEFT JOIN public.users u_vendedor ON pv.vendedor_id = u_vendedor.id
    LEFT JOIN public.users u_cajero ON pv.cajero_id = u_cajero.id
    LEFT JOIN public.clientes c ON pv.cliente_id = c.id
    WHERE 
        (p_estado IS NULL OR pv.estado = p_estado)
        AND (
            NOT p_solo_propias 
            OR pv.vendedor_id = p_usuario_id
        )
    ORDER BY 
        CASE 
            WHEN pv.estado = 'PENDIENTE' THEN 1
            WHEN pv.estado = 'BORRADOR' THEN 2
            ELSE 3
        END,
        pv.created_at DESC;
END;
$$;

-- RPC 4: CONFIRMAR PRE-VENTA
CREATE OR REPLACE FUNCTION public.confirmar_preventa(
    p_preventa_id UUID,
    p_cajero_id UUID,
    p_notas_cajero TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_preventa RECORD;
    v_venta_id UUID;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = p_cajero_id
        AND role IN ('admin', 'vendedor')
    ) THEN
        RAISE EXCEPTION 'Usuario no autorizado para confirmar pre-ventas';
    END IF;
    
    SELECT * INTO v_preventa
    FROM public.pre_ventas
    WHERE id = p_preventa_id
    AND estado = 'PENDIENTE';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pre-venta no encontrada o no está pendiente';
    END IF;
    
    v_venta_id := public.procesar_venta(
        p_cliente_id := v_preventa.cliente_id,
        p_tipo_venta := v_preventa.tipo_venta::text,
        p_items := v_preventa.items,
        p_usuario_id := p_cajero_id,
        p_force_credit := FALSE
    );
    
    UPDATE public.pre_ventas
    SET estado = 'CONFIRMADA',
        cajero_id = p_cajero_id,
        confirmada_at = NOW(),
        venta_id = v_venta_id,
        notas_cajero = p_notas_cajero
    WHERE id = p_preventa_id;
    
    RETURN v_venta_id;
END;
$$;

-- RPC 5: RECHAZAR PRE-VENTA
CREATE OR REPLACE FUNCTION public.rechazar_preventa(
    p_preventa_id UUID,
    p_cajero_id UUID,
    p_motivo TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = p_cajero_id
        AND role IN ('admin', 'vendedor')
    ) THEN
        RAISE EXCEPTION 'Usuario no autorizado';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM public.pre_ventas
        WHERE id = p_preventa_id
        AND estado = 'PENDIENTE'
    ) THEN
        RAISE EXCEPTION 'Pre-venta no encontrada o no está pendiente';
    END IF;
    
    UPDATE public.pre_ventas
    SET estado = 'RECHAZADA',
        cajero_id = p_cajero_id,
        motivo_rechazo = p_motivo,
        notas_cajero = p_motivo
    WHERE id = p_preventa_id;
    
    RETURN TRUE;
END;
$$;

-- RPC 6: CANCELAR PRE-VENTA
CREATE OR REPLACE FUNCTION public.cancelar_preventa(
    p_preventa_id UUID,
    p_vendedor_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.pre_ventas
        WHERE id = p_preventa_id
        AND vendedor_id = p_vendedor_id
        AND estado IN ('BORRADOR', 'PENDIENTE')
    ) THEN
        RAISE EXCEPTION 'No se puede cancelar esta pre-venta';
    END IF;
    
    UPDATE public.pre_ventas
    SET estado = 'CANCELADA'
    WHERE id = p_preventa_id;
    
    RETURN TRUE;
END;
$$;

-- RPC 7: BUSCAR POR CÓDIGO (PARA EL POS)
CREATE OR REPLACE FUNCTION public.buscar_preventa_por_codigo(
    p_codigo TEXT
) RETURNS TABLE (
    id UUID,
    codigo_preventa TEXT,
    vendedor_nombre TEXT,
    cliente_id UUID,
    cliente_nombre TEXT,
    estado estado_preventa,
    items JSONB,
    total NUMERIC,
    tipo_venta tipo_venta,
    notas_vendedor TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pv.id,
        pv.codigo_preventa,
        u.email AS vendedor_nombre,
        pv.cliente_id,
        c.nombre AS cliente_nombre,
        pv.estado,
        pv.items,
        pv.total,
        pv.tipo_venta,
        pv.notas_vendedor,
        pv.created_at
    FROM public.pre_ventas pv
    LEFT JOIN public.users u ON pv.vendedor_id = u.id
    LEFT JOIN public.clientes c ON pv.cliente_id = c.id
    WHERE pv.codigo_preventa = UPPER(p_codigo)
    AND pv.estado = 'PENDIENTE';
END;
$$;

-- =====================================================
-- PERMISOS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.crear_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.enviar_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.listar_preventas TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirmar_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.rechazar_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.buscar_preventa_por_codigo TO authenticated;

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE public.pre_ventas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vendedores ven sus preventas" ON public.pre_ventas;
CREATE POLICY "Vendedores ven sus preventas"
    ON public.pre_ventas
    FOR SELECT
    USING (
        vendedor_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    );

DROP POLICY IF EXISTS "Vendedores crean preventas" ON public.pre_ventas;
CREATE POLICY "Vendedores crean preventas"
    ON public.pre_ventas
    FOR INSERT
    WITH CHECK (vendedor_id = auth.uid());

DROP POLICY IF EXISTS "Vendedores editan borradores" ON public.pre_ventas;
CREATE POLICY "Vendedores editan borradores"
    ON public.pre_ventas
    FOR UPDATE
    USING (
        vendedor_id = auth.uid()
        AND estado IN ('BORRADOR', 'PENDIENTE')
    );

-- =====================================================
-- FIN - EJECUTAR TODO ESTE ARCHIVO
-- =====================================================
