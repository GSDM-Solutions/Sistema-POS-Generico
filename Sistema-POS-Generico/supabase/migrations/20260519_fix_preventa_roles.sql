-- =====================================================
-- FIX: PERMISOS PARA CONFIRMAR Y RECHAZAR PRE-VENTAS
-- =====================================================

-- 1. Actualizar confirmar_preventa
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
        AND role IN ('superadmin', 'admin', 'vendedor', 'empleado', 'cajero')
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

-- 2. Actualizar rechazar_preventa
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
        AND role IN ('superadmin', 'admin', 'vendedor', 'empleado', 'cajero')
    ) THEN
        RAISE EXCEPTION 'Usuario no autorizado para rechazar pre-ventas';
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
