-- ============================================
-- RPCs para Sistema de Bodegas y Traslados
-- ============================================

-- RPC: Obtener inventario por bodega
CREATE OR REPLACE FUNCTION public.get_inventory_por_bodega(p_bodega_id UUID DEFAULT NULL)
RETURNS TABLE (
    maestro_producto_id UUID,
    producto_id UUID,
    nombre_producto TEXT,
    codigo_barra TEXT,
    precio_venta NUMERIC,
    stock_actual NUMERIC,
    numero_lote TEXT,
    fecha_vencimiento DATE,
    unidad_medida TEXT,
    controla_stock BOOLEAN,
    bodega_id UUID,
    bodega_nombre TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT
        mp.id AS maestro_producto_id,
        p.id AS producto_id,
        mp.nombre AS nombre_producto,
        mp.codigo_barra,
        mp.precio_venta,
        p.stock_actual,
        p.numero_lote,
        p.fecha_vencimiento,
        mp.unidad_medida,
        mp.controla_stock,
        b.id AS bodega_id,
        b.nombre AS bodega_nombre
    FROM public.productos p
    JOIN public.maestro_productos mp ON mp.id = p.maestro_producto_id
    LEFT JOIN public.bodegas b ON b.id = p.bodega_id
    WHERE (p_bodega_id IS NULL OR p.bodega_id = p_bodega_id)
      AND p.stock_actual > 0
    ORDER BY mp.nombre, p.numero_lote;
END;
$$;

-- RPC: Buscar productos en bodega de venta (para POS)
CREATE OR REPLACE FUNCTION public.search_products_pos_bodega(p_query TEXT DEFAULT '')
RETURNS TABLE (
    id UUID,
    nombre_producto TEXT,
    codigo_barra TEXT,
    precio_venta NUMERIC,
    stock_actual NUMERIC,
    numero_lote TEXT,
    fecha_vencimiento DATE,
    unidad_medida TEXT,
    controla_stock BOOLEAN,
    factor_conversion NUMERIC,
    es_presentacion BOOLEAN,
    nombre_presentacion TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_bodega_venta_id UUID;
BEGIN
    -- Obtener ID de la bodega de venta
    SELECT id INTO v_bodega_venta_id FROM public.bodegas WHERE tipo = 'venta' LIMIT 1;

    RETURN QUERY
    SELECT
        p.id,
        mp.nombre,
        mp.codigo_barra,
        mp.precio_venta,
        p.stock_actual,
        p.numero_lote,
        p.fecha_vencimiento,
        COALESCE(mp.unidad_medida, 'UN'),
        COALESCE(mp.controla_stock, true),
        COALESCE(pp.factor_conversion, 1),
        COALESCE(pp.es_presentacion, false),
        pp.nombre_presentacion
    FROM public.productos p
    JOIN public.maestro_productos mp ON mp.id = p.maestro_producto_id
    LEFT JOIN public.producto_presentaciones pp ON pp.producto_id = p.id
    WHERE p.bodega_id = v_bodega_venta_id
      AND p.stock_actual > 0
      AND (
          p_query = ''
          OR mp.nombre ILIKE '%' || p_query || '%'
          OR mp.codigo_barra ILIKE '%' || p_query || '%'
          OR p.numero_lote ILIKE '%' || p_query || '%'
      )
    ORDER BY mp.nombre
    LIMIT 50;
END;
$$;

-- RPC: Crear traslado de stock entre bodegas
CREATE OR REPLACE FUNCTION public.crear_traslado(
    p_bodega_destino_id UUID,
    p_items JSONB,
    p_usuario_id UUID,
    p_notas TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_bodega_origen_id UUID;
    v_traslado_id UUID;
    v_item JSONB;
    v_producto_id UUID;
    v_cantidad NUMERIC;
    v_stock_actual NUMERIC;
BEGIN
    -- Obtener bodega general como origen por defecto
    SELECT id INTO v_bodega_origen_id FROM public.bodegas WHERE tipo = 'general' LIMIT 1;

    -- Crear traslado
    INSERT INTO public.traslados (bodega_origen_id, bodega_destino_id, usuario_id, notas, estado)
    VALUES (v_bodega_origen_id, p_bodega_destino_id, p_usuario_id, p_notas, 'COMPLETADO')
    RETURNING id INTO v_traslado_id;

    -- Procesar cada item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_producto_id := (v_item->>'producto_id')::UUID;
        v_cantidad := (v_item->>'cantidad')::NUMERIC;

        -- Validar stock en origen
        SELECT stock_actual INTO v_stock_actual
        FROM public.productos WHERE id = v_producto_id;

        IF v_stock_actual < v_cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para producto %: disponible %, solicitado %',
                v_producto_id, v_stock_actual, v_cantidad;
        END IF;

        -- Descontar del origen (bodega general)
        UPDATE public.productos
        SET stock_actual = stock_actual - v_cantidad
        WHERE id = v_producto_id;

        -- Verificar si ya existe el producto en destino
        IF EXISTS (
            SELECT 1 FROM public.productos
            WHERE maestro_producto_id = (SELECT maestro_producto_id FROM public.productos WHERE id = v_producto_id)
              AND bodega_id = p_bodega_destino_id
              AND numero_lote = (SELECT numero_lote FROM public.productos WHERE id = v_producto_id)
        ) THEN
            -- Sumar al existente
            UPDATE public.productos
            SET stock_actual = stock_actual + v_cantidad
            WHERE maestro_producto_id = (SELECT maestro_producto_id FROM public.productos WHERE id = v_producto_id)
              AND bodega_id = p_bodega_destino_id
              AND numero_lote = (SELECT numero_lote FROM public.productos WHERE id = v_producto_id);
        ELSE
            -- Crear nuevo registro en bodega destino
            INSERT INTO public.productos (
                maestro_producto_id, bodega_id, stock_actual,
                numero_lote, fecha_vencimiento, condicion
            )
            SELECT
                maestro_producto_id, p_bodega_destino_id, v_cantidad,
                numero_lote, fecha_vencimiento, 'Bueno'
            FROM public.productos
            WHERE id = v_producto_id;
        END IF;

        -- Registrar item
        INSERT INTO public.traslado_items (traslado_id, producto_id, cantidad)
        VALUES (v_traslado_id, v_producto_id, v_cantidad);

    END LOOP;

    RETURN v_traslado_id;
END;
$$;

-- RPC: Listar traslados
CREATE OR REPLACE FUNCTION public.listar_traslados()
RETURNS TABLE (
    id UUID,
    bodega_origen_nombre TEXT,
    bodega_destino_nombre TEXT,
    usuario_nombre TEXT,
    estado TEXT,
    total_items BIGINT,
    notas TEXT,
    created_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id,
        bo.nombre AS bodega_origen_nombre,
        bd.nombre AS bodega_destino_nombre,
        u.name AS usuario_nombre,
        t.estado,
        COUNT(ti.id) AS total_items,
        t.notas,
        t.created_at
    FROM public.traslados t
    JOIN public.bodegas bo ON bo.id = t.bodega_origen_id
    JOIN public.bodegas bd ON bd.id = t.bodega_destino_id
    LEFT JOIN public.users u ON u.id = t.usuario_id
    LEFT JOIN public.traslado_items ti ON ti.traslado_id = t.id
    GROUP BY t.id, bo.nombre, bd.nombre, u.name, t.estado, t.notas, t.created_at
    ORDER BY t.created_at DESC;
END;
$$;
