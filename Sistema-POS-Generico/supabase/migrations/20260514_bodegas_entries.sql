-- ============================================
-- Actualizar procesar_recepcion_mercaderia
-- Agrega soporte para bodega_id
-- ============================================

DROP FUNCTION IF EXISTS public.procesar_recepcion_mercaderia(text, text, uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS public.procesar_recepcion_mercaderia(text, text, uuid, uuid, uuid, jsonb);

CREATE OR REPLACE FUNCTION public.procesar_recepcion_mercaderia(
    p_numero_documento TEXT,
    p_tipo_documento TEXT,
    p_proveedor_id UUID,
    p_usuario_id UUID,
    p_bodega_id UUID,
    p_detalles JSONB
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_detalle JSONB;
    v_maestro_id UUID;
    v_cantidad NUMERIC;
    v_precio_costo NUMERIC;
    v_precio_venta NUMERIC;
    v_lote TEXT;
    v_vencimiento DATE;
    v_producto_existente RECORD;
    v_producto_id UUID;
    v_stock_anterior NUMERIC;
    v_productos_afectados INT := 0;
    v_entrada_id UUID;
BEGIN
    -- Validar bodega
    IF NOT EXISTS (SELECT 1 FROM public.bodegas WHERE id = p_bodega_id) THEN
        RAISE EXCEPTION 'Bodega no encontrada: %', p_bodega_id;
    END IF;

    -- Procesar cada item
    FOR v_detalle IN SELECT * FROM jsonb_array_elements(p_detalles)
    LOOP
        v_maestro_id := (v_detalle->>'id')::UUID;
        v_cantidad := (v_detalle->>'cantidad')::NUMERIC;
        v_precio_costo := (v_detalle->>'precio_costo')::NUMERIC;
        v_precio_venta := (v_detalle->>'precio_venta')::NUMERIC;
        v_lote := COALESCE(v_detalle->>'lote', 'S/L');
        v_vencimiento := NULLIF(v_detalle->>'vencimiento', '')::DATE;

        -- Buscar producto existente en la misma bodega con el mismo lote
        SELECT id, stock_actual INTO v_producto_existente
        FROM public.productos
        WHERE maestro_producto_id = v_maestro_id
          AND bodega_id = p_bodega_id
          AND numero_lote = v_lote
        LIMIT 1;

        IF FOUND THEN
            -- Sumar stock al existente
            UPDATE public.productos
            SET stock_actual = stock_actual + v_cantidad,
                actualizado_en = now()
            WHERE id = v_producto_existente.id;

            v_producto_id := v_producto_existente.id;
        ELSE
            -- Crear nuevo producto en la bodega
            INSERT INTO public.productos (
                maestro_producto_id, bodega_id, stock_actual,
                numero_lote, fecha_vencimiento, condicion
            ) VALUES (
                v_maestro_id, p_bodega_id, v_cantidad,
                v_lote, v_vencimiento, 'Bueno'
            ) RETURNING id INTO v_producto_id;
        END IF;

        v_productos_afectados := v_productos_afectados + 1;
    END LOOP;

    -- Registrar la entrada
    INSERT INTO public.entradas (
        numero_documento, tipo_documento,
        proveedor_id, usuario_id, bodega_id,
        cantidad_items, created_at
    ) VALUES (
        p_numero_documento, p_tipo_documento,
        p_proveedor_id, p_usuario_id, p_bodega_id,
        v_productos_afectados, now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'productos_afectados', v_productos_afectados,
        'bodega_id', p_bodega_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.procesar_recepcion_mercaderia(text, text, uuid, uuid, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.procesar_recepcion_mercaderia(text, text, uuid, uuid, uuid, jsonb) TO anon;
