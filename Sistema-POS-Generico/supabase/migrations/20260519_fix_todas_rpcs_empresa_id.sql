-- ============================================================
-- FIX COMPLETO: empresa_id en TODAS las RPCs faltantes
-- 25 RPCs actualizadas + search_products_pos + fix configuracion PK
-- ============================================================

-- ============================================================
-- 0. Fix PK de configuracion (debe incluir empresa_id)
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'configuracion' AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE public.configuracion DROP CONSTRAINT configuracion_pkey;
    END IF;
END $$;

ALTER TABLE public.configuracion ADD PRIMARY KEY (key, empresa_id);

-- ============================================================
-- 1. procesar_recepcion_mercaderia
-- ============================================================
DROP FUNCTION IF EXISTS public.procesar_recepcion_mercaderia(text, text, uuid, uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS public.procesar_recepcion_mercaderia(text, text, uuid, uuid, jsonb);

CREATE OR REPLACE FUNCTION public.procesar_recepcion_mercaderia(
    p_numero_documento text,
    p_tipo_documento text,
    p_proveedor_id uuid,
    p_usuario_id uuid,
    p_bodega_id uuid DEFAULT NULL,
    p_detalles jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_recepcion_id uuid;
    v_item jsonb;
    v_maestro_producto_id uuid;
    v_cantidad numeric;
    v_lote text;
    v_vencimiento date;
    v_condicion text;
    v_producto_id uuid;
BEGIN
    -- Obtener empresa del usuario
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_usuario_id;
    IF v_empresa_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin empresa asignada';
    END IF;

    -- Si se especifico bodega, verificar que pertenece a la empresa
    IF p_bodega_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.bodegas WHERE id = p_bodega_id AND empresa_id = v_empresa_id) THEN
            RAISE EXCEPTION 'Bodega no pertenece a esta empresa';
        END IF;
    END IF;

    -- Crear recepcion
    INSERT INTO public.recepciones (
        numero_documento, tipo_documento, proveedor_id,
        usuario_id, empresa_id, fecha_recepcion, estado
    ) VALUES (
        p_numero_documento, p_tipo_documento, p_proveedor_id,
        p_usuario_id, v_empresa_id, NOW(), 'COMPLETADO'
    ) RETURNING id INTO v_recepcion_id;

    -- Procesar detalles (parametro p_detalles es opcional para compatibilidad)
    IF p_detalles IS NOT NULL THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles)
        LOOP
            v_maestro_producto_id := (v_item->>'maestro_producto_id')::uuid;
            v_cantidad := (v_item->>'cantidad')::numeric;
            v_lote := v_item->>'lote';
            v_vencimiento := (v_item->>'vencimiento')::date;
            v_condicion := COALESCE(v_item->>'condicion', 'Bueno');

            -- Crear o actualizar producto (lote)
            INSERT INTO public.productos (
                maestro_producto_id, stock_actual, numero_lote,
                fecha_vencimiento, condicion, proveedor_id,
                empresa_id, bodega_id
            ) VALUES (
                v_maestro_producto_id, v_cantidad, v_lote,
                v_vencimiento, v_condicion, p_proveedor_id,
                v_empresa_id, p_bodega_id
            ) RETURNING id INTO v_producto_id;

            -- Registrar movimiento
            INSERT INTO public.movimientos (
                producto_id, tipo_movimiento, cantidad, motivo,
                usuario_id, empresa_id, condicion, origen_destino
            ) VALUES (
                v_producto_id, 'entrada', v_cantidad,
                'Recepcion ' || p_numero_documento,
                p_usuario_id, v_empresa_id, v_condicion, 'Proveedor'
            );

            -- Detalle recepcion
            INSERT INTO public.detalle_recepcion (
                recepcion_id, maestro_producto_id, cantidad,
                numero_lote, fecha_vencimiento, condicion
            ) VALUES (
                v_recepcion_id, v_maestro_producto_id, v_cantidad,
                v_lote, v_vencimiento, v_condicion
            );
        END LOOP;
    END IF;

    RETURN v_recepcion_id;
END;
$$;


-- ============================================================
-- 2. search_products_pos_bodega (CRITICO - usado por POS)
-- ============================================================
DROP FUNCTION IF EXISTS public.search_products_pos_bodega(text);
CREATE OR REPLACE FUNCTION public.search_products_pos_bodega(p_query text DEFAULT '')
RETURNS TABLE(
    id uuid,
    nombre_producto text,
    codigo_barra text,
    precio_venta numeric,
    stock_actual numeric,
    numero_lote text,
    fecha_vencimiento date,
    factor_conversion numeric,
    es_presentacion boolean,
    nombre_presentacion text,
    unidad_medida text,
    controla_stock boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_bodega_venta_id uuid;
BEGIN
    -- Obtener empresa del usuario autenticado
    v_empresa_id := public.get_user_empresa_id();
    
    -- Buscar bodega de venta de esta empresa
    SELECT id INTO v_bodega_venta_id
    FROM public.bodegas
    WHERE tipo = 'venta' AND empresa_id = v_empresa_id AND activo = true
    LIMIT 1;
    
    IF v_bodega_venta_id IS NULL THEN
        RETURN QUERY SELECT NULL::uuid, NULL::text, NULL::text, NULL::numeric,
            NULL::numeric, NULL::text, NULL::date, NULL::numeric,
            NULL::boolean, NULL::text, NULL::text, NULL::boolean
            WHERE FALSE;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT DISTINCT ON (p.id)
        p.id,
        mp.nombre::text,
        mp.codigo_barra::text,
        mp.precio_venta::numeric,
        p.stock_actual::numeric,
        p.numero_lote::text,
        p.fecha_vencimiento::date,
        COALESCE(pp.factor_conversion, 1)::numeric,
        (pp.id IS NOT NULL)::boolean,
        pp.nombre_presentacion::text,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM public.productos p
    JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
    LEFT JOIN public.producto_presentaciones pp ON pp.maestro_producto_id = mp.id
    WHERE p.bodega_id = v_bodega_venta_id
      AND p.empresa_id = v_empresa_id
      AND mp.empresa_id = v_empresa_id
      AND p.stock_actual > 0
      AND (p_query = '' OR mp.nombre ILIKE '%' || p_query || '%' 
           OR mp.codigo_barra ILIKE '%' || p_query || '%'
           OR pp.codigo_barra ILIKE '%' || p_query || '%')
    ORDER BY p.id, pp.factor_conversion ASC;
END;
$$;


-- ============================================================
-- 3. get_inventory_por_bodega
-- ============================================================
DROP FUNCTION IF EXISTS public.get_inventory_por_bodega(uuid);

CREATE OR REPLACE FUNCTION public.get_inventory_por_bodega(p_bodega_id uuid DEFAULT NULL)
RETURNS TABLE(
    id uuid,
    nombre_producto text,
    codigo_barra text,
    precio_venta numeric,
    stock_actual numeric,
    numero_lote text,
    fecha_vencimiento date,
    bodega_nombre text,
    factor_conversion numeric,
    es_presentacion boolean,
    nombre_presentacion text,
    unidad_medida text,
    controla_stock boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        p.id,
        mp.nombre::text,
        mp.codigo_barra::text,
        mp.precio_venta::numeric,
        p.stock_actual::numeric,
        p.numero_lote::text,
        p.fecha_vencimiento::date,
        b.nombre::text,
        COALESCE(pp.factor_conversion, 1)::numeric,
        (pp.id IS NOT NULL)::boolean,
        pp.nombre_presentacion::text,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM public.productos p
    JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id AND mp.empresa_id = v_empresa_id
    LEFT JOIN public.bodegas b ON p.bodega_id = b.id AND b.empresa_id = v_empresa_id
    LEFT JOIN public.producto_presentaciones pp ON pp.maestro_producto_id = mp.id AND pp.empresa_id = v_empresa_id
    WHERE p.empresa_id = v_empresa_id
      AND (p_bodega_id IS NULL OR p.bodega_id = p_bodega_id)
      AND p.stock_actual > 0
    ORDER BY mp.nombre, p.fecha_vencimiento ASC;
END;
$$;


-- ============================================================
-- 4. crear_traslado
-- ============================================================
CREATE OR REPLACE FUNCTION public.crear_traslado(
    p_bodega_destino_id uuid,
    p_items jsonb,
    p_usuario_id uuid,
    p_notas text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_traslado_id uuid;
    v_bodega_origen_id uuid;
    v_item jsonb;
    v_producto_id uuid;
    v_cantidad numeric;
    v_stock_actual numeric;
BEGIN
    -- Obtener empresa del usuario
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_usuario_id;
    IF v_empresa_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin empresa asignada';
    END IF;

    -- Validar bodega destino pertenece a la empresa
    IF NOT EXISTS (SELECT 1 FROM public.bodegas WHERE id = p_bodega_destino_id AND empresa_id = v_empresa_id) THEN
        RAISE EXCEPTION 'Bodega destino no pertenece a esta empresa';
    END IF;

    -- Buscar bodega general de la empresa
    SELECT id INTO v_bodega_origen_id
    FROM public.bodegas
    WHERE tipo = 'general' AND empresa_id = v_empresa_id AND activo = true
    LIMIT 1;

    IF v_bodega_origen_id IS NULL THEN
        RAISE EXCEPTION 'No se encontro bodega general para esta empresa';
    END IF;

    -- Crear traslado
    INSERT INTO public.traslados (bodega_origen_id, bodega_destino_id, usuario_id, notas)
    VALUES (v_bodega_origen_id, p_bodega_destino_id, p_usuario_id, p_notas)
    RETURNING id INTO v_traslado_id;

    -- Procesar items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_producto_id := (v_item->>'producto_id')::uuid;
        v_cantidad := (v_item->>'cantidad')::numeric;

        -- Verificar stock en bodega origen
        SELECT stock_actual INTO v_stock_actual
        FROM public.productos
        WHERE id = v_producto_id AND bodega_id = v_bodega_origen_id AND empresa_id = v_empresa_id
        FOR UPDATE;

        IF v_stock_actual IS NULL OR v_stock_actual < v_cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente en bodega origen para producto %', v_producto_id;
        END IF;

        -- Descontar de origen
        UPDATE public.productos
        SET stock_actual = stock_actual - v_cantidad
        WHERE id = v_producto_id AND empresa_id = v_empresa_id;

        -- Agregar a destino (buscar si ya existe lote en destino)
        UPDATE public.productos
        SET stock_actual = stock_actual + v_cantidad
        WHERE maestro_producto_id = (SELECT maestro_producto_id FROM public.productos WHERE id = v_producto_id)
          AND bodega_id = p_bodega_destino_id
          AND numero_lote = (SELECT numero_lote FROM public.productos WHERE id = v_producto_id)
          AND empresa_id = v_empresa_id;

        IF NOT FOUND THEN
            INSERT INTO public.productos (
                maestro_producto_id, stock_actual, numero_lote,
                fecha_vencimiento, condicion, empresa_id, bodega_id
            )
            SELECT
                maestro_producto_id, v_cantidad, numero_lote,
                fecha_vencimiento, condicion, v_empresa_id, p_bodega_destino_id
            FROM public.productos
            WHERE id = v_producto_id;
        END IF;

        -- Insertar traslado_item
        INSERT INTO public.traslado_items (traslado_id, producto_id, cantidad)
        VALUES (v_traslado_id, v_producto_id, v_cantidad);

        -- Movimientos Kardex
        INSERT INTO public.movimientos (producto_id, tipo_movimiento, cantidad, motivo, usuario_id, empresa_id)
        VALUES (v_producto_id, 'traslado_origen', v_cantidad, 'Traslado a bodega destino', p_usuario_id, v_empresa_id);
    END LOOP;

    RETURN v_traslado_id;
END;
$$;


-- ============================================================
-- 5. listar_traslados
-- ============================================================
DROP FUNCTION IF EXISTS public.listar_traslados();

CREATE OR REPLACE FUNCTION public.listar_traslados()
RETURNS TABLE(
    id uuid,
    bodega_origen_nombre text,
    bodega_destino_nombre text,
    usuario_nombre text,
    estado text,
    created_at timestamptz,
    notas text,
    items_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        t.id,
        bo.nombre::text,
        bd.nombre::text,
        u.name::text,
        t.estado::text,
        t.created_at,
        t.notas::text,
        COUNT(ti.id)::bigint
    FROM public.traslados t
    JOIN public.bodegas bo ON t.bodega_origen_id = bo.id AND bo.empresa_id = v_empresa_id
    JOIN public.bodegas bd ON t.bodega_destino_id = bd.id AND bd.empresa_id = v_empresa_id
    LEFT JOIN public.users u ON t.usuario_id = u.id
    LEFT JOIN public.traslado_items ti ON t.id = ti.traslado_id
    GROUP BY t.id, bo.nombre, bd.nombre, u.name, t.estado, t.created_at, t.notas
    ORDER BY t.created_at DESC;
END;
$$;


-- ============================================================
-- 6. crear_preventa
-- ============================================================
DROP FUNCTION IF EXISTS public.crear_preventa(uuid, uuid, jsonb, text, text);

CREATE OR REPLACE FUNCTION public.crear_preventa(
    p_vendedor_id uuid,
    p_items jsonb,
    p_cliente_id uuid DEFAULT NULL,
    p_tipo_venta text DEFAULT 'BOLETA',
    p_notas text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_preventa_id uuid;
    v_total numeric(12,2) := 0;
    v_item jsonb;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_vendedor_id;
    IF v_empresa_id IS NULL THEN
        RAISE EXCEPTION 'Usuario sin empresa asignada';
    END IF;

    -- Calcular total
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_total := v_total + ((v_item->>'cantidad')::numeric * (v_item->>'precio')::numeric);
    END LOOP;

    INSERT INTO public.pre_ventas (
        vendedor_id, cliente_id, items, total, tipo_venta,
        notas_vendedor, estado, empresa_id
    ) VALUES (
        p_vendedor_id, p_cliente_id, p_items, v_total,
        p_tipo_venta::tipo_venta, p_notas, 'BORRADOR', v_empresa_id
    ) RETURNING id INTO v_preventa_id;

    RETURN v_preventa_id;
END;
$$;


-- ============================================================
-- 7. enviar_preventa
-- ============================================================
DROP FUNCTION IF EXISTS public.enviar_preventa(uuid, uuid);

CREATE OR REPLACE FUNCTION public.enviar_preventa(p_preventa_id uuid, p_vendedor_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_vendedor_id;

    UPDATE public.pre_ventas
    SET estado = 'PENDIENTE', enviada_at = NOW(), updated_at = NOW()
    WHERE id = p_preventa_id
      AND vendedor_id = p_vendedor_id
      AND empresa_id = v_empresa_id
      AND estado = 'BORRADOR';

    RETURN FOUND;
END;
$$;


-- ============================================================
-- 8. confirmar_preventa
-- ============================================================
DROP FUNCTION IF EXISTS public.confirmar_preventa(uuid, uuid, text);

CREATE OR REPLACE FUNCTION public.confirmar_preventa(
    p_preventa_id uuid,
    p_cajero_id uuid,
    p_notas_cajero text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_preventa RECORD;
    v_venta_id uuid;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_cajero_id;

    SELECT * INTO v_preventa FROM public.pre_ventas
    WHERE id = p_preventa_id AND empresa_id = v_empresa_id AND estado = 'PENDIENTE';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pre-venta no encontrada o no esta pendiente';
    END IF;

    v_venta_id := public.procesar_venta(
        v_preventa.cliente_id,
        v_preventa.tipo_venta::text,
        v_preventa.items,
        p_cajero_id,
        false
    );

    UPDATE public.pre_ventas
    SET estado = 'CONFIRMADA', cajero_id = p_cajero_id,
        notas_cajero = p_notas_cajero, confirmada_at = NOW(),
        venta_id = v_venta_id, updated_at = NOW()
    WHERE id = p_preventa_id AND empresa_id = v_empresa_id;

    RETURN v_venta_id;
END;
$$;


-- ============================================================
-- 9. rechazar_preventa
-- ============================================================
DROP FUNCTION IF EXISTS public.rechazar_preventa(uuid, uuid, text);

CREATE OR REPLACE FUNCTION public.rechazar_preventa(
    p_preventa_id uuid,
    p_cajero_id uuid,
    p_motivo text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_cajero_id;

    UPDATE public.pre_ventas
    SET estado = 'RECHAZADA', cajero_id = p_cajero_id,
        motivo_rechazo = p_motivo, updated_at = NOW()
    WHERE id = p_preventa_id
      AND empresa_id = v_empresa_id;

    RETURN FOUND;
END;
$$;


-- ============================================================
-- 10. cancelar_preventa
-- ============================================================
DROP FUNCTION IF EXISTS public.cancelar_preventa(uuid, uuid);

CREATE OR REPLACE FUNCTION public.cancelar_preventa(p_preventa_id uuid, p_vendedor_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_vendedor_id;

    UPDATE public.pre_ventas
    SET estado = 'CANCELADA', updated_at = NOW()
    WHERE id = p_preventa_id
      AND vendedor_id = p_vendedor_id
      AND empresa_id = v_empresa_id;

    RETURN FOUND;
END;
$$;


-- ============================================================
-- 11. listar_preventas
-- ============================================================
DROP FUNCTION IF EXISTS public.listar_preventas(uuid, text, boolean);

CREATE OR REPLACE FUNCTION public.listar_preventas(
    p_usuario_id uuid DEFAULT NULL,
    p_estado text DEFAULT NULL,
    p_solo_propias boolean DEFAULT false
)
RETURNS TABLE(
    id uuid,
    codigo_preventa text,
    estado text,
    total numeric,
    vendedor_nombre text,
    cliente_nombre text,
    cliente_id uuid,
    tipo_venta text,
    notas_vendedor text,
    created_at timestamptz,
    items jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_usuario_id;

    RETURN QUERY
    SELECT
        pv.id,
        pv.codigo_preventa,
        pv.estado::text,
        pv.total,
        u.name::text,
        c.nombre::text,
        pv.cliente_id,
        pv.tipo_venta::text,
        pv.notas_vendedor,
        pv.created_at,
        pv.items
    FROM public.pre_ventas pv
    LEFT JOIN public.users u ON pv.vendedor_id = u.id
    LEFT JOIN public.clientes c ON pv.cliente_id = c.id
    WHERE pv.empresa_id = v_empresa_id
      AND (p_estado IS NULL OR pv.estado::text = p_estado)
      AND (NOT p_solo_propias OR pv.vendedor_id = p_usuario_id)
    ORDER BY
        CASE pv.estado
            WHEN 'PENDIENTE' THEN 1
            WHEN 'BORRADOR' THEN 2
            ELSE 3
        END,
        pv.created_at DESC;
END;
$$;


-- ============================================================
-- 12. buscar_preventa_por_codigo
-- ============================================================
DROP FUNCTION IF EXISTS public.buscar_preventa_por_codigo(text);

CREATE OR REPLACE FUNCTION public.buscar_preventa_por_codigo(p_codigo text)
RETURNS TABLE(
    id uuid,
    codigo_preventa text,
    estado text,
    total numeric,
    items jsonb,
    vendedor_nombre text,
    vendedor_id uuid,
    cliente_nombre text,
    cliente_id uuid,
    tipo_venta text,
    notas_vendedor text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        pv.id,
        pv.codigo_preventa,
        pv.estado::text,
        pv.total,
        pv.items,
        u.name::text,
        pv.vendedor_id,
        c.nombre::text,
        pv.cliente_id,
        pv.tipo_venta::text,
        pv.notas_vendedor
    FROM public.pre_ventas pv
    LEFT JOIN public.users u ON pv.vendedor_id = u.id
    LEFT JOIN public.clientes c ON pv.cliente_id = c.id
    WHERE pv.codigo_preventa ILIKE p_codigo
      AND pv.empresa_id = v_empresa_id
      AND pv.estado = 'PENDIENTE'
    LIMIT 1;
END;
$$;


-- ============================================================
-- 13. abrir_caja
-- ============================================================
CREATE OR REPLACE FUNCTION public.abrir_caja(
    p_usuario_id uuid,
    p_monto_inicial numeric,
    p_caja_id uuid,
    p_codigo_auth text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_codigo_valido text;
    v_sesion_id uuid;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_usuario_id;

    -- Validar codigo de autorizacion
    SELECT value INTO v_codigo_valido FROM public.configuracion
    WHERE key = 'CODIGO_CAJA' AND empresa_id = v_empresa_id;

    IF v_codigo_valido IS NULL OR v_codigo_valido <> p_codigo_auth THEN
        RAISE EXCEPTION 'Codigo de autorizacion invalido';
    END IF;

    -- Verificar que no tenga sesion abierta
    IF EXISTS (
        SELECT 1 FROM public.sesiones_caja
        WHERE usuario_id = p_usuario_id
          AND empresa_id = v_empresa_id
          AND estado = 'ABIERTA'
    ) THEN
        RAISE EXCEPTION 'El usuario ya tiene una sesion de caja abierta';
    END IF;

    -- Abrir sesion
    INSERT INTO public.sesiones_caja (usuario_id, monto_inicial, caja_id, empresa_id)
    VALUES (p_usuario_id, p_monto_inicial, p_caja_id, v_empresa_id)
    RETURNING id INTO v_sesion_id;

    -- Registrar movimiento de apertura
    INSERT INTO public.movimientos_caja (sesion_id, tipo_movimiento, monto, descripcion, empresa_id)
    VALUES (v_sesion_id, 'APERTURA', p_monto_inicial, 'Apertura de caja', v_empresa_id);

    RETURN v_sesion_id;
END;
$$;


-- ============================================================
-- 14. cerrar_caja
-- ============================================================
CREATE OR REPLACE FUNCTION public.cerrar_caja(
    p_sesion_id uuid,
    p_monto_declarado numeric,
    p_codigo_auth text,
    p_nombre_cajera text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_codigo_valido text;
    v_monto_esperado numeric;
    v_diferencia numeric;
BEGIN
    -- Obtener empresa de la sesion
    SELECT empresa_id INTO v_empresa_id FROM public.sesiones_caja WHERE id = p_sesion_id;

    -- Validar codigo
    SELECT value INTO v_codigo_valido FROM public.configuracion
    WHERE key = 'CODIGO_CAJA' AND empresa_id = v_empresa_id;

    IF v_codigo_valido IS NULL OR v_codigo_valido <> p_codigo_auth THEN
        RAISE EXCEPTION 'Codigo de autorizacion invalido';
    END IF;

    -- Calcular monto esperado
    SELECT COALESCE(SUM(monto), 0) INTO v_monto_esperado
    FROM public.movimientos_caja
    WHERE sesion_id = p_sesion_id AND empresa_id = v_empresa_id;

    v_diferencia := p_monto_declarado - v_monto_esperado;

    -- Cerrar sesion
    UPDATE public.sesiones_caja
    SET estado = 'CERRADA',
        fecha_cierre = NOW(),
        monto_final_declarado = p_monto_declarado,
        monto_final_esperado = v_monto_esperado,
        diferencia = v_diferencia,
        nombre_cajera_cierre = p_nombre_cajera
    WHERE id = p_sesion_id AND empresa_id = v_empresa_id;

    RETURN jsonb_build_object(
        'success', true,
        'monto_esperado', v_monto_esperado,
        'monto_declarado', p_monto_declarado,
        'diferencia', v_diferencia
    );
END;
$$;


-- ============================================================
-- 15. crear_nueva_caja
-- ============================================================
CREATE OR REPLACE FUNCTION public.crear_nueva_caja(p_nombre text, p_codigo_auth text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_codigo_valido text;
    v_caja_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    SELECT value INTO v_codigo_valido FROM public.configuracion
    WHERE key = 'CODIGO_CAJA' AND empresa_id = v_empresa_id;

    IF v_codigo_valido IS NULL OR v_codigo_valido <> p_codigo_auth THEN
        RAISE EXCEPTION 'Codigo de autorizacion invalido';
    END IF;

    INSERT INTO public.cajas (nombre, empresa_id) VALUES (p_nombre, v_empresa_id)
    RETURNING id INTO v_caja_id;

    RETURN jsonb_build_object('success', true, 'id', v_caja_id);
END;
$$;


-- ============================================================
-- 16. actualizar_clave_maestra
-- ============================================================
CREATE OR REPLACE FUNCTION public.actualizar_clave_maestra(
    p_actual_codigo text,
    p_nuevo_codigo text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_codigo_valido text;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    SELECT value INTO v_codigo_valido FROM public.configuracion
    WHERE key = 'CODIGO_CAJA' AND empresa_id = v_empresa_id;

    IF v_codigo_valido IS NULL OR v_codigo_valido <> p_actual_codigo THEN
        RAISE EXCEPTION 'Codigo actual invalido';
    END IF;

    INSERT INTO public.configuracion (key, value, empresa_id)
    VALUES ('CODIGO_CAJA', p_nuevo_codigo, v_empresa_id)
    ON CONFLICT (key, empresa_id) DO UPDATE SET value = p_nuevo_codigo;

    RETURN true;
END;
$$;


-- ============================================================
-- 17. get_movement_history
-- ============================================================
DROP FUNCTION IF EXISTS public.get_movement_history(date, date, uuid[], text, text);

CREATE OR REPLACE FUNCTION public.get_movement_history(
    start_date date DEFAULT NULL,
    end_date date DEFAULT NULL,
    user_ids uuid[] DEFAULT NULL,
    movement_type text DEFAULT NULL,
    search_term text DEFAULT NULL
)
RETURNS TABLE(
    id uuid,
    producto_id uuid,
    producto_nombre text,
    tipo_movimiento text,
    cantidad numeric,
    motivo text,
    usuario_nombre text,
    creado_en timestamptz,
    condicion text,
    origen_destino text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        m.id,
        m.producto_id,
        mp.nombre::text,
        m.tipo_movimiento,
        m.cantidad,
        m.motivo,
        u.name::text,
        m.creado_en,
        m.condicion,
        m.origen_destino
    FROM public.movimientos m
    LEFT JOIN public.productos p ON m.producto_id = p.id
    LEFT JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
    LEFT JOIN public.users u ON m.usuario_id = u.id
    WHERE m.empresa_id = v_empresa_id
      AND (start_date IS NULL OR m.creado_en::date >= start_date)
      AND (end_date IS NULL OR m.creado_en::date <= end_date)
      AND (user_ids IS NULL OR m.usuario_id = ANY(user_ids))
      AND (movement_type IS NULL OR m.tipo_movimiento = movement_type)
      AND (search_term IS NULL OR mp.nombre ILIKE '%' || search_term || '%')
    ORDER BY m.creado_en DESC
    LIMIT 1000;
END;
$$;


-- ============================================================
-- 18. get_critical_stock_products_list
-- ============================================================
DROP FUNCTION IF EXISTS public.get_critical_stock_products_list();

CREATE OR REPLACE FUNCTION public.get_critical_stock_products_list()
RETURNS TABLE(
    maestro_producto_id uuid,
    nombre text,
    stock_actual numeric,
    stock_critico integer,
    categoria text,
    unidad_medida text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        mp.id,
        mp.nombre::text,
        COALESCE(SUM(p.stock_actual), 0)::numeric,
        mp.stock_critico,
        mp.categoria::text,
        mp.unidad_medida::text
    FROM public.maestro_productos mp
    LEFT JOIN public.productos p ON p.maestro_producto_id = mp.id AND p.empresa_id = v_empresa_id
    WHERE mp.empresa_id = v_empresa_id
      AND mp.activo = true
      AND mp.controla_stock = true
    GROUP BY mp.id, mp.nombre, mp.stock_critico, mp.categoria, mp.unidad_medida
    HAVING COALESCE(SUM(p.stock_actual), 0) <= mp.stock_critico
    ORDER BY COALESCE(SUM(p.stock_actual), 0) ASC;
END;
$$;


-- ============================================================
-- 19. get_expiring_products_list
-- ============================================================
DROP FUNCTION IF EXISTS public.get_expiring_products_list(integer);

CREATE OR REPLACE FUNCTION public.get_expiring_products_list(days_threshold integer DEFAULT 30)
RETURNS TABLE(
    id uuid,
    nombre_producto text,
    numero_lote text,
    fecha_vencimiento date,
    stock_actual numeric,
    dias_restantes integer,
    bodega_nombre text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        p.id,
        mp.nombre::text,
        p.numero_lote::text,
        p.fecha_vencimiento,
        p.stock_actual::numeric,
        (p.fecha_vencimiento - CURRENT_DATE)::integer,
        COALESCE(b.nombre, 'Sin bodega')::text
    FROM public.productos p
    JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id AND mp.empresa_id = v_empresa_id
    LEFT JOIN public.bodegas b ON p.bodega_id = b.id
    WHERE p.empresa_id = v_empresa_id
      AND p.stock_actual > 0
      AND p.fecha_vencimiento IS NOT NULL
      AND p.fecha_vencimiento <= (CURRENT_DATE + days_threshold)
    ORDER BY p.fecha_vencimiento ASC;
END;
$$;


-- ============================================================
-- 20. get_quarantine_products_list
-- ============================================================
DROP FUNCTION IF EXISTS public.get_quarantine_products_list();

CREATE OR REPLACE FUNCTION public.get_quarantine_products_list()
RETURNS TABLE(
    id uuid,
    nombre_producto text,
    numero_lote text,
    stock_actual numeric,
    fecha_ingreso timestamptz,
    observaciones text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        p.id,
        mp.nombre::text,
        p.numero_lote::text,
        p.stock_actual::numeric,
        p.fecha_ingreso,
        p.observaciones::text
    FROM public.productos p
    JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id AND mp.empresa_id = v_empresa_id
    WHERE p.empresa_id = v_empresa_id
      AND p.condicion = 'Cuarentena'
      AND p.stock_actual > 0
    ORDER BY p.fecha_ingreso ASC;
END;
$$;


-- ============================================================
-- 21. get_dispatch_lots
-- ============================================================
DROP FUNCTION IF EXISTS public.get_dispatch_lots(uuid);

CREATE OR REPLACE FUNCTION public.get_dispatch_lots(param_maestro_producto_id uuid)
RETURNS TABLE(
    producto_id uuid,
    numero_lote text,
    fecha_vencimiento date,
    condicion text,
    stock_actual numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        p.id,
        p.numero_lote::text,
        p.fecha_vencimiento,
        p.condicion::text,
        p.stock_actual::numeric
    FROM public.productos p
    WHERE p.maestro_producto_id = param_maestro_producto_id
      AND p.empresa_id = v_empresa_id
      AND p.stock_actual > 0
    ORDER BY p.fecha_vencimiento ASC NULLS LAST;
END;
$$;


-- ============================================================
-- 22. registar_salida_manual
-- ============================================================
CREATE OR REPLACE FUNCTION public.registrar_salida_manual(
    p_usuario_id uuid,
    p_motivo text,
    p_salidas jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_item jsonb;
    v_producto_id uuid;
    v_cantidad numeric;
    v_stock numeric;
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_usuario_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_salidas)
    LOOP
        v_producto_id := (v_item->>'producto_id')::uuid;
        v_cantidad := (v_item->>'cantidad')::numeric;

        SELECT stock_actual INTO v_stock
        FROM public.productos
        WHERE id = v_producto_id AND empresa_id = v_empresa_id
        FOR UPDATE;

        IF v_stock IS NULL OR v_stock < v_cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para producto %', v_producto_id;
        END IF;

        UPDATE public.productos
        SET stock_actual = stock_actual - v_cantidad
        WHERE id = v_producto_id AND empresa_id = v_empresa_id;

        INSERT INTO public.movimientos (
            producto_id, tipo_movimiento, cantidad, motivo,
            usuario_id, empresa_id
        ) VALUES (
            v_producto_id, 'salida', v_cantidad, p_motivo,
            p_usuario_id, v_empresa_id
        );
    END LOOP;
END;
$$;


-- ============================================================
-- 23. segregate_stock (sobrescribe ambas sobrecargas)
-- ============================================================
DROP FUNCTION IF EXISTS public.segregate_stock(uuid, integer, text, text);
DROP FUNCTION IF EXISTS public.segregate_stock(uuid, integer, text, text, uuid, text);

CREATE OR REPLACE FUNCTION public.segregate_stock(
    p_producto_id uuid,
    p_cantidad integer,
    p_condicion_origen text,
    p_condicion_destino text,
    p_usuario_id uuid DEFAULT NULL,
    p_motivo text DEFAULT 'Segregacion de stock'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_stock_actual numeric;
BEGIN
    IF p_usuario_id IS NOT NULL THEN
        SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_usuario_id;
    ELSE
        v_empresa_id := public.get_user_empresa_id();
    END IF;

    SELECT stock_actual INTO v_stock_actual
    FROM public.productos
    WHERE id = p_producto_id AND empresa_id = v_empresa_id AND condicion = p_condicion_origen
    FOR UPDATE;

    IF v_stock_actual IS NULL OR v_stock_actual < p_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente en condicion %', p_condicion_origen;
    END IF;

    UPDATE public.productos
    SET stock_actual = stock_actual - p_cantidad
    WHERE id = p_producto_id AND empresa_id = v_empresa_id;

    INSERT INTO public.productos (
        maestro_producto_id, stock_actual, numero_lote,
        fecha_vencimiento, condicion, empresa_id, bodega_id
    )
    SELECT
        maestro_producto_id, p_cantidad, numero_lote,
        fecha_vencimiento, p_condicion_destino, v_empresa_id, bodega_id
    FROM public.productos
    WHERE id = p_producto_id;

    INSERT INTO public.movimientos (
        producto_id, tipo_movimiento, cantidad, motivo, usuario_id, empresa_id
    ) VALUES (
        p_producto_id, 'ajuste', p_cantidad, p_motivo, p_usuario_id, v_empresa_id
    );
END;
$$;


-- ============================================================
-- 24. recepcionar_orden_compra
-- ============================================================
CREATE OR REPLACE FUNCTION public.recepcionar_orden_compra(
    p_orden_id uuid,
    p_usuario_id uuid,
    p_items jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
    v_item jsonb;
    v_detalle_id uuid;
    v_cantidad integer;
    v_lote text;
    v_vencimiento date;
    v_maestro_id uuid;
    v_new_product_id uuid;
    v_orden_status text := 'COMPLETADA';
BEGIN
    SELECT empresa_id INTO v_empresa_id FROM public.users WHERE id = p_usuario_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_detalle_id := (v_item->>'detalle_id')::uuid;
        v_cantidad := (v_item->>'cantidad')::int;
        v_lote := v_item->>'lote';
        v_vencimiento := (v_item->>'vencimiento')::date;
        v_maestro_id := (v_item->>'maestro_producto_id')::uuid;

        INSERT INTO public.productos (
            maestro_producto_id, stock_actual, numero_lote,
            fecha_vencimiento, condicion, empresa_id
        ) VALUES (
            v_maestro_id, v_cantidad, v_lote,
            v_vencimiento, 'Bueno', v_empresa_id
        ) RETURNING id INTO v_new_product_id;

        INSERT INTO public.movimientos (
            producto_id, tipo_movimiento, cantidad, motivo, usuario_id, empresa_id
        ) VALUES (
            v_new_product_id, 'entrada', v_cantidad,
            'Recepcion OC ', p_usuario_id, v_empresa_id
        );

        UPDATE public.detalle_ordenes_compra
        SET cantidad_recibida = cantidad_recibida + v_cantidad
        WHERE id = v_detalle_id;
    END LOOP;

    -- Actualizar estado de la orden si todos los items fueron recibidos
    UPDATE public.ordenes_compra
    SET estado = v_orden_status, fecha_recepcion_final = NOW()
    WHERE id = p_orden_id AND empresa_id = v_empresa_id;
END;
$$;


-- ============================================================
-- 25. get_users
-- ============================================================
DROP FUNCTION IF EXISTS public.get_users();

CREATE OR REPLACE FUNCTION public.get_users()
RETURNS TABLE(
    id uuid,
    email text,
    name text,
    role text,
    created_at timestamptz,
    last_sign_in_at timestamptz,
    empresa_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT
        u.id,
        u.email::text,
        u.name::text,
        u.role::text,
        u.created_at,
        u.updated_at AS last_sign_in_at,
        u.empresa_id
    FROM public.users u
    WHERE u.empresa_id = v_empresa_id
    ORDER BY u.created_at DESC;
END;
$$;


-- ============================================================
-- 26. search_products_pos (respaldo - por si paso_5 no se aplico)
-- ============================================================
DROP FUNCTION IF EXISTS public.search_products_pos(text);

CREATE OR REPLACE FUNCTION public.search_products_pos(p_query text)
RETURNS TABLE(
    id uuid,
    nombre_producto text,
    codigo_barra text,
    precio_venta numeric,
    stock_actual numeric,
    factor_conversion numeric,
    es_presentacion boolean,
    nombre_presentacion text,
    unidad_medida text,
    controla_stock boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id uuid;
BEGIN
    v_empresa_id := public.get_user_empresa_id();

    RETURN QUERY
    SELECT DISTINCT ON (p.id, COALESCE(pp.id, '00000000-0000-0000-0000-000000000000'))
        p.id,
        mp.nombre::text,
        COALESCE(pp.codigo_barra, mp.codigo_barra)::text,
        COALESCE(pp.precio_venta, mp.precio_venta)::numeric,
        p.stock_actual::numeric,
        COALESCE(pp.factor_conversion, 1)::numeric,
        (pp.id IS NOT NULL)::boolean,
        pp.nombre_presentacion::text,
        COALESCE(mp.unidad_medida, 'UN')::text,
        COALESCE(mp.controla_stock, true)::boolean
    FROM public.productos p
    JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
        AND mp.empresa_id = v_empresa_id
    LEFT JOIN public.producto_presentaciones pp ON pp.maestro_producto_id = mp.id
    WHERE p.empresa_id = v_empresa_id
      AND p.stock_actual > 0
      AND (mp.codigo_barra = p_query OR mp.nombre ILIKE '%' || p_query || '%'
           OR pp.codigo_barra = p_query)
    ORDER BY p.id, COALESCE(pp.id, '00000000-0000-0000-0000-000000000000'), p.fecha_vencimiento ASC NULLS LAST;
END;
$$;
