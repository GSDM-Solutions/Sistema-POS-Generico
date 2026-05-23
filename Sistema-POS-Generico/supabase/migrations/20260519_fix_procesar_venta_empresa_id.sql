-- =============================================================
-- FIX: procesar_venta con empresa_id (mantiene compatibilidad POS)
-- =============================================================

CREATE OR REPLACE FUNCTION public.procesar_venta(
    p_cliente_id uuid,
    p_tipo_venta text,
    p_items jsonb,
    p_usuario_id uuid,
    p_force_credit boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_venta_id uuid;
    v_total numeric(10,2) := 0;
    v_item jsonb;
    v_cantidad numeric;
    v_precio numeric(10,2);
    v_factor numeric;
    v_subtotal numeric(10,2);
    v_producto_id uuid;
    v_cantidad_descontar numeric;
    v_cliente_saldo numeric(10,2);
    v_cliente_cupo numeric(10,2);
    v_current_stock int;
    v_empresa_id uuid;
BEGIN
    -- Obtener empresa_id del usuario
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_usuario_id;
    IF v_empresa_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin empresa asignada';
    END IF;

    -- 1. Calcular total
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_cantidad := (v_item->>'cantidad')::numeric;
        v_precio := (v_item->>'precio')::numeric;
        v_total := v_total + (v_cantidad * v_precio);
    END LOOP;

    -- 2. Validaciones FIADO
    IF p_tipo_venta = 'FIADO' THEN
        IF p_cliente_id IS NULL THEN
            RAISE EXCEPTION 'Debe seleccionar un cliente para venta FIADO';
        END IF;
        
        SELECT saldo_actual, cupo_credito INTO v_cliente_saldo, v_cliente_cupo
        FROM public.clientes WHERE id = p_cliente_id AND empresa_id = v_empresa_id;
        
        IF v_cliente_saldo IS NULL THEN 
            RAISE EXCEPTION 'Cliente no encontrado o no pertenece a esta empresa';
        END IF;

        IF NOT p_force_credit AND (v_cliente_saldo + v_total) > v_cliente_cupo THEN
            RAISE EXCEPTION 'El cliente excede su cupo de credito';
        END IF;
    END IF;

    -- 3. Crear cabecera Venta
    INSERT INTO public.ventas (cliente_id, tipo_venta, total, usuario_id, empresa_id)
    VALUES (p_cliente_id, p_tipo_venta::tipo_venta, v_total, p_usuario_id, v_empresa_id)
    RETURNING id INTO v_venta_id;

    -- 4. Procesar Detalle y Stock (FIFO por fecha_vencimiento)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_producto_id := (v_item->>'producto_id')::uuid;
        v_cantidad := (v_item->>'cantidad')::numeric;
        v_precio := (v_item->>'precio')::numeric;
        v_factor := COALESCE((v_item->>'factor')::numeric, 1);
        v_subtotal := v_cantidad * v_precio;
        
        v_cantidad_descontar := v_cantidad * v_factor;

        -- Verificar Stock (productos de la misma empresa)
        SELECT stock_actual INTO v_current_stock 
        FROM public.productos 
        WHERE id = v_producto_id 
          AND empresa_id = v_empresa_id
        FOR UPDATE;
        
        IF v_current_stock IS NULL THEN
            RAISE EXCEPTION 'Producto no encontrado o no pertenece a esta empresa: %', v_producto_id;
        END IF;
        
        IF v_current_stock < v_cantidad_descontar THEN
            RAISE EXCEPTION 'Stock insuficiente para el producto % (Stock: %, Necesario: %)', 
                v_producto_id, v_current_stock, v_cantidad_descontar;
        END IF;

        -- Descontar Stock
        UPDATE public.productos 
        SET stock_actual = stock_actual - v_cantidad_descontar
        WHERE id = v_producto_id AND empresa_id = v_empresa_id;
        
        -- Registrar Movimiento de Salida (Kardex)
        INSERT INTO public.movimientos (
            producto_id, tipo_movimiento, cantidad, motivo, usuario_id, empresa_id
        ) VALUES (
            v_producto_id, 'venta', v_cantidad_descontar, 
            'Venta Folio: ' || v_venta_id::text, p_usuario_id, v_empresa_id
        );

        -- Insertar Detalle Venta
        INSERT INTO public.detalle_ventas (venta_id, producto_id, cantidad, precio_unitario, subtotal, factor_conversion)
        VALUES (v_venta_id, v_producto_id, v_cantidad, v_precio, v_subtotal, v_factor);
    END LOOP;

    -- 5. Actualizar Cta Cte Fiado
    IF p_tipo_venta = 'FIADO' THEN
        UPDATE public.clientes
        SET saldo_actual = saldo_actual + v_total,
            actualizado_en = now()
        WHERE id = p_cliente_id AND empresa_id = v_empresa_id;

        INSERT INTO public.movimientos_cuenta_corriente (
            cliente_id, venta_id, tipo, monto, saldo_posterior, usuario_id, empresa_id
        ) VALUES (
            p_cliente_id, v_venta_id, 'COMPRA', v_total, 
            (SELECT saldo_actual FROM public.clientes WHERE id = p_cliente_id), 
            p_usuario_id, v_empresa_id
        );
    END IF;

    RETURN v_venta_id;
END;
$$;
