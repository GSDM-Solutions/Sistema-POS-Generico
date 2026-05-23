-- =====================================================
-- FASE 1: SISTEMA DE PRE-VENTAS (VENDEDOR → CAJERO)
-- Fecha: 25 Enero 2026
-- =====================================================

-- 1. CREAR TIPO ENUM PARA ESTADOS DE PRE-VENTA
CREATE TYPE estado_preventa AS ENUM (
    'BORRADOR',           -- Vendedor está armando la venta
    'PENDIENTE',          -- Enviada al cajero para confirmación
    'CONFIRMADA',         -- Cajero la confirmó y procesó el pago
    'RECHAZADA',          -- Cajero la rechazó
    'CANCELADA'           -- Vendedor la canceló antes de enviar
);

-- 2. CREAR TABLA PRE_VENTAS
CREATE TABLE IF NOT EXISTS public.pre_ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Relaciones
    vendedor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    cajero_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    cliente_id UUID REFERENCES public.clientes(id) ON DELETE SET NULL,
    
    -- Estado y flujo
    estado estado_preventa NOT NULL DEFAULT 'BORRADOR',
    
    -- Datos de la venta
    items JSONB NOT NULL, -- Array de {producto_id, cantidad, precio, nombre, factor}
    total NUMERIC(12,2) NOT NULL DEFAULT 0,
    tipo_venta tipo_venta NOT NULL DEFAULT 'BOLETA',
    
    -- Notas y observaciones
    notas_vendedor TEXT,
    notas_cajero TEXT,
    motivo_rechazo TEXT,
    
    -- Auditoría
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    enviada_at TIMESTAMPTZ, -- Cuando el vendedor la envía al cajero
    confirmada_at TIMESTAMPTZ, -- Cuando el cajero la confirma
    
    -- Folio de venta real (si fue confirmada)
    venta_id UUID REFERENCES public.ventas(id) ON DELETE SET NULL,
    
    -- Índices para búsquedas rápidas
    CONSTRAINT chk_total_positivo CHECK (total >= 0),
    CONSTRAINT chk_items_no_vacio CHECK (jsonb_array_length(items) > 0)
);

-- 3. CREAR ÍNDICES PARA OPTIMIZAR CONSULTAS
CREATE INDEX idx_preventas_vendedor ON public.pre_ventas(vendedor_id);
CREATE INDEX idx_preventas_estado ON public.pre_ventas(estado);
CREATE INDEX idx_preventas_created ON public.pre_ventas(created_at DESC);
CREATE INDEX idx_preventas_cajero ON public.pre_ventas(cajero_id) WHERE cajero_id IS NOT NULL;

-- 4. TRIGGER PARA ACTUALIZAR updated_at AUTOMÁTICAMENTE
CREATE OR REPLACE FUNCTION update_preventa_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_preventas_updated_at
    BEFORE UPDATE ON public.pre_ventas
    FOR EACH ROW
    EXECUTE FUNCTION update_preventa_timestamp();

-- 5. RPC: CREAR PRE-VENTA (Vendedor)
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
    -- Validar que el vendedor existe y tiene rol correcto
    IF NOT EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = p_vendedor_id 
        AND role IN ('vendedor', 'admin')
    ) THEN
        RAISE EXCEPTION 'Usuario no autorizado para crear pre-ventas';
    END IF;
    
    -- Calcular total
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_total := v_total + (
            (v_item->>'cantidad')::numeric * (v_item->>'precio')::numeric
        );
    END LOOP;
    
    -- Crear pre-venta
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

-- 6. RPC: ENVIAR PRE-VENTA AL CAJERO (Vendedor)
CREATE OR REPLACE FUNCTION public.enviar_preventa(
    p_preventa_id UUID,
    p_vendedor_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validar que la pre-venta existe y pertenece al vendedor
    IF NOT EXISTS (
        SELECT 1 FROM public.pre_ventas
        WHERE id = p_preventa_id
        AND vendedor_id = p_vendedor_id
        AND estado = 'BORRADOR'
    ) THEN
        RAISE EXCEPTION 'Pre-venta no encontrada o no se puede enviar';
    END IF;
    
    -- Cambiar estado a PENDIENTE
    UPDATE public.pre_ventas
    SET estado = 'PENDIENTE',
        enviada_at = NOW()
    WHERE id = p_preventa_id;
    
    RETURN TRUE;
END;
$$;

-- 7. RPC: LISTAR PRE-VENTAS (Con filtros)
CREATE OR REPLACE FUNCTION public.listar_preventas(
    p_usuario_id UUID,
    p_estado estado_preventa DEFAULT NULL,
    p_solo_propias BOOLEAN DEFAULT FALSE
) RETURNS TABLE (
    id UUID,
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

-- 8. RPC: CONFIRMAR PRE-VENTA Y PROCESAR VENTA (Cajero)
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
    -- Validar que el cajero tiene permisos
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = p_cajero_id
        AND role IN ('admin', 'vendedor') -- En tu sistema simplificado
    ) THEN
        RAISE EXCEPTION 'Usuario no autorizado para confirmar pre-ventas';
    END IF;
    
    -- Obtener datos de la pre-venta
    SELECT * INTO v_preventa
    FROM public.pre_ventas
    WHERE id = p_preventa_id
    AND estado = 'PENDIENTE';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pre-venta no encontrada o no está pendiente';
    END IF;
    
    -- Procesar la venta real usando la función existente
    v_venta_id := public.procesar_venta(
        p_cliente_id := v_preventa.cliente_id,
        p_tipo_venta := v_preventa.tipo_venta::text,
        p_items := v_preventa.items,
        p_usuario_id := p_cajero_id,
        p_force_credit := FALSE
    );
    
    -- Actualizar pre-venta como confirmada
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

-- 9. RPC: RECHAZAR PRE-VENTA (Cajero)
CREATE OR REPLACE FUNCTION public.rechazar_preventa(
    p_preventa_id UUID,
    p_cajero_id UUID,
    p_motivo TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validar permisos
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = p_cajero_id
        AND role IN ('admin', 'vendedor')
    ) THEN
        RAISE EXCEPTION 'Usuario no autorizado';
    END IF;
    
    -- Validar que la pre-venta existe y está pendiente
    IF NOT EXISTS (
        SELECT 1 FROM public.pre_ventas
        WHERE id = p_preventa_id
        AND estado = 'PENDIENTE'
    ) THEN
        RAISE EXCEPTION 'Pre-venta no encontrada o no está pendiente';
    END IF;
    
    -- Rechazar
    UPDATE public.pre_ventas
    SET estado = 'RECHAZADA',
        cajero_id = p_cajero_id,
        motivo_rechazo = p_motivo,
        notas_cajero = p_motivo
    WHERE id = p_preventa_id;
    
    RETURN TRUE;
END;
$$;

-- 10. RPC: CANCELAR PRE-VENTA (Vendedor)
CREATE OR REPLACE FUNCTION public.cancelar_preventa(
    p_preventa_id UUID,
    p_vendedor_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Solo se puede cancelar si es BORRADOR o PENDIENTE y es del vendedor
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

-- 11. PERMISOS PARA LAS FUNCIONES
GRANT EXECUTE ON FUNCTION public.crear_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.enviar_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.listar_preventas TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirmar_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.rechazar_preventa TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_preventa TO authenticated;

-- 12. ROW LEVEL SECURITY (RLS) - Opcional pero recomendado
ALTER TABLE public.pre_ventas ENABLE ROW LEVEL SECURITY;

-- Política: Los vendedores solo ven sus propias pre-ventas
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

-- Política: Los vendedores pueden insertar sus propias pre-ventas
CREATE POLICY "Vendedores crean preventas"
    ON public.pre_ventas
    FOR INSERT
    WITH CHECK (vendedor_id = auth.uid());

-- Política: Los vendedores pueden actualizar solo sus borradores
CREATE POLICY "Vendedores editan borradores"
    ON public.pre_ventas
    FOR UPDATE
    USING (
        vendedor_id = auth.uid()
        AND estado IN ('BORRADOR', 'PENDIENTE')
    );

-- =====================================================
-- FIN DE MIGRACIÓN
-- =====================================================

-- COMENTARIOS:
-- Esta migración crea el sistema completo de pre-ventas
-- Flujo: Vendedor crea → Envía → Cajero confirma/rechaza
-- Estados: BORRADOR → PENDIENTE → CONFIRMADA/RECHAZADA
-- Incluye RLS para seguridad a nivel de fila
