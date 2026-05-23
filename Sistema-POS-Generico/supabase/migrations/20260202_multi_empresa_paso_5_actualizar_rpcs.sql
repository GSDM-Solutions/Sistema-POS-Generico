-- =====================================================
-- MIGRACIÓN MULTI-EMPRESA - PASO 5: ACTUALIZAR FUNCIONES RPC
-- =====================================================
-- Fecha: 2026-02-02
-- Descripción: Actualiza las funciones RPC más críticas para filtrar por empresa
-- =====================================================

-- ⚠️ IMPORTANTE: Ejecuta PASOS 1-4 primero

-- ========== FUNCIÓN HELPER: Obtener empresa del usuario actual ==========
-- (Ya creada en paso 4, pero la incluimos por si acaso)
CREATE OR REPLACE FUNCTION public.get_user_empresa_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT empresa_id FROM public.users WHERE id = auth.uid();
$$;


-- ========== 1. search_products_pos ==========
-- Buscar productos en el POS (CRÍTICA)
DROP FUNCTION IF EXISTS public.search_products_pos(text);
CREATE OR REPLACE FUNCTION public.search_products_pos(p_query text)
RETURNS TABLE(
    maestro_id uuid,
    nombre text,
    codigo_barra text,
    precio_venta numeric,
    stock_total numeric,
    controla_stock boolean,
    lotes jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
BEGIN
    -- Obtener empresa del usuario actual
    v_empresa_id := public.get_user_empresa_id();
    
    RETURN QUERY
    SELECT 
        mp.id AS maestro_id,
        mp.nombre,
        mp.codigo_barra,
        mp.precio_venta,
        COALESCE(SUM(p.stock_actual), 0) AS stock_total,
        mp.controla_stock,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'stock', p.stock_actual,
                    'fecha_vencimiento', p.fecha_vencimiento
                ) ORDER BY p.fecha_vencimiento ASC NULLS LAST
            ) FILTER (WHERE p.id IS NOT NULL),
            '[]'::jsonb
        ) AS lotes
    FROM public.maestro_productos mp
    LEFT JOIN public.productos p ON mp.id = p.maestro_producto_id AND p.stock_actual > 0
    WHERE mp.empresa_id = v_empresa_id  -- FILTRO POR EMPRESA
      AND mp.activo = true
      AND (
        LOWER(mp.nombre) LIKE LOWER('%' || p_query || '%')
        OR mp.codigo_barra LIKE '%' || p_query || '%'
      )
    GROUP BY mp.id, mp.nombre, mp.codigo_barra, mp.precio_venta, mp.controla_stock
    LIMIT 50;
END;
$$;


-- ========== 2. get_inventory_stock ==========
-- Obtener stock de inventario (CRÍTICA)
DROP FUNCTION IF EXISTS public.get_inventory_stock();
CREATE OR REPLACE FUNCTION public.get_inventory_stock()
RETURNS TABLE(
    maestro_producto_id uuid,
    nombre text,
    codigo_barra text,
    categoria text,
    stock_total numeric,
    precio_venta numeric,
    precio_compra numeric,
    valor_inventario numeric,
    controla_stock boolean,
    lotes jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
BEGIN
    v_empresa_id := public.get_user_empresa_id();
    
    RETURN QUERY
    SELECT 
        mp.id AS maestro_producto_id,
        mp.nombre,
        mp.codigo_barra,
        mp.categoria,
        COALESCE(SUM(p.stock_actual), 0) AS stock_total,
        mp.precio_venta,
        mp.precio_compra,
        COALESCE(SUM(p.stock_actual * mp.precio_compra), 0) AS valor_inventario,
        mp.controla_stock,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'stock_actual', p.stock_actual,
                    'fecha_vencimiento', p.fecha_vencimiento,
                    'creado_en', p.creado_en
                ) ORDER BY p.fecha_vencimiento ASC NULLS LAST
            ) FILTER (WHERE p.id IS NOT NULL),
            '[]'::jsonb
        ) AS lotes
    FROM public.maestro_productos mp
    LEFT JOIN public.productos p ON mp.id = p.maestro_producto_id
    WHERE mp.empresa_id = v_empresa_id  -- FILTRO POR EMPRESA
      AND mp.activo = true
    GROUP BY mp.id, mp.nombre, mp.codigo_barra, mp.categoria, mp.precio_venta, mp.precio_compra, mp.controla_stock
    ORDER BY mp.nombre;
END;
$$;


-- ========== 3. get_dashboard_stats ==========
-- Estadísticas del dashboard (CRÍTICA)
DROP FUNCTION IF EXISTS public.get_dashboard_stats();
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
    v_stats jsonb;
BEGIN
    v_empresa_id := public.get_user_empresa_id();
    
    SELECT jsonb_build_object(
        'ventas_hoy', (
            SELECT COALESCE(SUM(total), 0)
            FROM public.ventas
            WHERE empresa_id = v_empresa_id
              AND DATE(creado_en) = CURRENT_DATE
        ),
        'ventas_mes', (
            SELECT COALESCE(SUM(total), 0)
            FROM public.ventas
            WHERE empresa_id = v_empresa_id
              AND DATE_TRUNC('month', creado_en) = DATE_TRUNC('month', CURRENT_DATE)
        ),
        'productos_total', (
            SELECT COUNT(*)
            FROM public.maestro_productos
            WHERE empresa_id = v_empresa_id
              AND activo = true
        ),
        'clientes_total', (
            SELECT COUNT(*)
            FROM public.clientes
            WHERE empresa_id = v_empresa_id
        ),
        'stock_bajo', (
            SELECT COUNT(*)
            FROM public.maestro_productos mp
            LEFT JOIN (
                SELECT maestro_producto_id, SUM(stock_actual) as total_stock
                FROM public.productos
                WHERE empresa_id = v_empresa_id
                GROUP BY maestro_producto_id
            ) p ON mp.id = p.maestro_producto_id
            WHERE mp.empresa_id = v_empresa_id
              AND mp.activo = true
              AND mp.controla_stock = true
              AND COALESCE(p.total_stock, 0) <= mp.stock_minimo
        )
    ) INTO v_stats;
    
    RETURN v_stats;
END;
$$;


-- ========== 4. procesar_venta ==========
-- Procesar una venta (CRÍTICA)
DROP FUNCTION IF EXISTS public.procesar_venta(uuid, text, jsonb, uuid, boolean);
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
    v_empresa_id UUID;
    v_venta_id UUID;
    v_total NUMERIC := 0;
    v_item RECORD;
    v_producto RECORD;
    v_cantidad_restante INTEGER;
    v_cantidad_a_descontar INTEGER;
    v_cliente RECORD;
BEGIN
    -- Obtener empresa del usuario
    v_empresa_id := public.get_user_empresa_id();
    
    -- Validar cliente pertenece a la misma empresa
    SELECT * INTO v_cliente FROM public.clientes 
    WHERE id = p_cliente_id AND empresa_id = v_empresa_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente no encontrado o no pertenece a esta empresa';
    END IF;
    
    -- Validar crédito si es venta fiada
    IF p_tipo_venta = 'FIADO' AND NOT p_force_credit THEN
        IF v_cliente.deuda_actual + (p_items::jsonb->0->>'subtotal')::numeric > v_cliente.cupo_credito THEN
            RAISE EXCEPTION 'Cliente excede su cupo de crédito';
        END IF;
    END IF;
    
    -- Crear venta
    INSERT INTO public.ventas (
        cliente_id,
        usuario_id,
        empresa_id,  -- NUEVO
        tipo_venta,
        total,
        creado_en
    ) VALUES (
        p_cliente_id,
        p_usuario_id,
        v_empresa_id,  -- NUEVO
        p_tipo_venta::tipo_venta,
        0,
        NOW()
    ) RETURNING id INTO v_venta_id;
    
    -- Procesar items
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
        maestro_producto_id uuid,
        cantidad integer,
        precio_unitario numeric,
        subtotal numeric
    )
    LOOP
        v_total := v_total + v_item.subtotal;
        
        -- Insertar detalle
        INSERT INTO public.detalle_ventas (
            venta_id,
            maestro_producto_id,
            cantidad,
            precio_unitario,
            subtotal
        ) VALUES (
            v_venta_id,
            v_item.maestro_producto_id,
            v_item.cantidad,
            v_item.precio_unitario,
            v_item.subtotal
        );
        
        -- Descontar stock (FIFO)
        v_cantidad_restante := v_item.cantidad;
        
        FOR v_producto IN 
            SELECT id, stock_actual
            FROM public.productos
            WHERE maestro_producto_id = v_item.maestro_producto_id
              AND empresa_id = v_empresa_id  -- FILTRO POR EMPRESA
              AND stock_actual > 0
            ORDER BY fecha_vencimiento ASC NULLS LAST, creado_en ASC
        LOOP
            IF v_cantidad_restante <= 0 THEN EXIT; END IF;
            
            v_cantidad_a_descontar := LEAST(v_producto.stock_actual, v_cantidad_restante);
            
            UPDATE public.productos
            SET stock_actual = stock_actual - v_cantidad_a_descontar
            WHERE id = v_producto.id;
            
            INSERT INTO public.movimientos (
                producto_id,
                tipo_movimiento,
                cantidad,
                usuario_id,
                empresa_id,  -- NUEVO
                motivo,
                condicion,
                creado_en
            ) VALUES (
                v_producto.id,
                'salida',
                v_cantidad_a_descontar,
                p_usuario_id,
                v_empresa_id,  -- NUEVO
                'Venta #' || v_venta_id,
                'Bueno',
                NOW()
            );
            
            v_cantidad_restante := v_cantidad_restante - v_cantidad_a_descontar;
        END LOOP;
    END LOOP;
    
    -- Actualizar total de venta
    UPDATE public.ventas SET total = v_total WHERE id = v_venta_id;
    
    -- Actualizar cuenta corriente si es fiado
    IF p_tipo_venta = 'FIADO' THEN
        INSERT INTO public.movimientos_cuenta_corriente (
            cliente_id,
            tipo_movimiento,
            monto,
            usuario_id,
            empresa_id,  -- NUEVO
            referencia_venta_id,
            descripcion,
            creado_en
        ) VALUES (
            p_cliente_id,
            'COMPRA',
            v_total,
            p_usuario_id,
            v_empresa_id,  -- NUEVO
            v_venta_id,
            'Venta fiada',
            NOW()
        );
        
        UPDATE public.clientes
        SET deuda_actual = deuda_actual + v_total
        WHERE id = p_cliente_id;
    END IF;
    
    RETURN v_venta_id;
END;
$$;


-- ========== 5. procesar_recepcion_mercaderia ==========
-- Procesar recepción de mercadería (CRÍTICA)
DROP FUNCTION IF EXISTS public.procesar_recepcion_mercaderia(text, text, uuid, uuid, jsonb);
CREATE OR REPLACE FUNCTION public.procesar_recepcion_mercaderia(
    p_numero_documento text,
    p_tipo_documento text,
    p_proveedor_id uuid,
    p_usuario_id uuid,
    p_detalles jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
    v_recepcion_id UUID;
    v_detalle RECORD;
    v_producto_id UUID;
BEGIN
    -- Obtener empresa del usuario
    v_empresa_id := public.get_user_empresa_id();
    
    -- Validar proveedor pertenece a la misma empresa
    IF NOT EXISTS (
        SELECT 1 FROM public.proveedores 
        WHERE id = p_proveedor_id AND empresa_id = v_empresa_id
    ) THEN
        RAISE EXCEPTION 'Proveedor no encontrado o no pertenece a esta empresa';
    END IF;
    
    -- Crear recepción
    INSERT INTO public.recepciones (
        numero_documento,
        tipo_documento,
        proveedor_id,
        usuario_id,
        empresa_id,  -- NUEVO
        creado_en
    ) VALUES (
        p_numero_documento,
        p_tipo_documento,
        p_proveedor_id,
        p_usuario_id,
        v_empresa_id,  -- NUEVO
        NOW()
    ) RETURNING id INTO v_recepcion_id;
    
    -- Procesar detalles
    FOR v_detalle IN SELECT * FROM jsonb_to_recordset(p_detalles) AS x(
        maestro_producto_id uuid,
        cantidad integer,
        precio_compra numeric,
        fecha_vencimiento date
    )
    LOOP
        -- Validar producto pertenece a la empresa
        IF NOT EXISTS (
            SELECT 1 FROM public.maestro_productos 
            WHERE id = v_detalle.maestro_producto_id AND empresa_id = v_empresa_id
        ) THEN
            RAISE EXCEPTION 'Producto no encontrado o no pertenece a esta empresa';
        END IF;
        
        -- Crear nuevo lote
        INSERT INTO public.productos (
            maestro_producto_id,
            empresa_id,  -- NUEVO
            stock_actual,
            fecha_vencimiento,
            creado_en
        ) VALUES (
            v_detalle.maestro_producto_id,
            v_empresa_id,  -- NUEVO
            v_detalle.cantidad,
            v_detalle.fecha_vencimiento,
            NOW()
        ) RETURNING id INTO v_producto_id;
        
        -- Registrar detalle de recepción
        INSERT INTO public.detalle_recepcion (
            recepcion_id,
            maestro_producto_id,
            producto_id,
            cantidad,
            precio_compra
        ) VALUES (
            v_recepcion_id,
            v_detalle.maestro_producto_id,
            v_producto_id,
            v_detalle.cantidad,
            v_detalle.precio_compra
        );
        
        -- Registrar movimiento
        INSERT INTO public.movimientos (
            producto_id,
            tipo_movimiento,
            cantidad,
            usuario_id,
            empresa_id,  -- NUEVO
            motivo,
            condicion,
            creado_en
        ) VALUES (
            v_producto_id,
            'entrada',
            v_detalle.cantidad,
            p_usuario_id,
            v_empresa_id,  -- NUEVO
            'Recepción ' || p_numero_documento,
            'Bueno',
            NOW()
        );
    END LOOP;
    
    RETURN v_recepcion_id;
END;
$$;


-- ========== VERIFICAR ==========
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname IN (
    'search_products_pos',
    'get_inventory_stock',
    'get_dashboard_stats',
    'procesar_venta',
    'procesar_recepcion_mercaderia',
    'get_user_empresa_id'
  )
ORDER BY p.proname;


-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- 6 funciones actualizadas con filtros por empresa
-- Todas las operaciones críticas ahora filtran por empresa_id
-- =====================================================

-- =====================================================
-- NOTA IMPORTANTE:
-- =====================================================
-- Este script actualiza las 5 funciones MÁS CRÍTICAS.
-- Hay ~25 funciones más que también deben actualizarse.
-- 
-- Para cada función adicional, sigue el mismo patrón:
-- 1. Obtener empresa_id con get_user_empresa_id()
-- 2. Agregar filtro WHERE tabla.empresa_id = v_empresa_id
-- 3. Agregar empresa_id en los INSERT
-- 
-- Funciones pendientes de actualizar:
-- - crear_preventa
-- - confirmar_preventa
-- - buscar_preventa_por_codigo
-- - listar_preventas
-- - abrir_caja
-- - cerrar_caja
-- - get_movement_history
-- - get_expiring_products_list
-- - get_critical_stock_products_list
-- - get_quarantine_products_list
-- - registrar_salida_manual
-- - segregate_stock
-- - Y otras...
-- =====================================================
