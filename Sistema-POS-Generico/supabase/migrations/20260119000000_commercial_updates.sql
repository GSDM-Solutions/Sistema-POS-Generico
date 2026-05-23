-- MIGRACIÓN 2026-01-19: EVOLUCIÓN COMERCIAL Y SOPORTE DECIMAL
-- Estas son las actualizaciones realizadas para transformar el sistema a POS Genérico.

-- 1. SOPORTE DE STOCK DECIMAL (Para Pesaje/Metraje)
ALTER TABLE "public"."productos" ALTER COLUMN "stock_actual" TYPE numeric(12,2);
ALTER TABLE "public"."detalle_ventas" ALTER COLUMN "cantidad" TYPE numeric(12,2);
ALTER TABLE "public"."movimientos" ALTER COLUMN "cantidad" TYPE numeric(12,2);

-- 2. ACTUALIZACIÓN DE BÚSQUEDA POS (Soporte decimal y Packs con precio específico)
-- NOTA: Se requiere DROP debido al cambio de tipo de retorno (int -> numeric)
DROP FUNCTION IF EXISTS "public"."search_products_pos"(p_query text);

CREATE OR REPLACE FUNCTION "public"."search_products_pos"("p_query" "text") 
RETURNS TABLE(
    "id" "uuid", 
    "maestro_id" "uuid", 
    "nombre_producto" "text", 
    "codigo_barra" "text", 
    "precio_venta" numeric, 
    "stock_actual" numeric, 
    "numero_lote" "text", 
    "fecha_vencimiento" "date", 
    "es_presentacion" boolean, 
    "nombre_presentacion" "text", 
    "factor_conversion" numeric
)
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    mp.id as maestro_id,
    mp.nombre as nombre_producto,
    mp.codigo_barra,
    mp.precio_venta,
    p.stock_actual::numeric,
    p.numero_lote,
    p.fecha_vencimiento,
    false as es_presentacion,
    NULL::text as nombre_presentacion,
    1.0::numeric as factor_conversion
  FROM public.productos p
  JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
  WHERE 
    p.stock_actual > 0 
    AND (
      mp.codigo_barra ILIKE p_query 
      OR mp.nombre ILIKE '%' || p_query || '%'
    )

  UNION ALL

  SELECT 
    p.id,
    mp.id as maestro_id,
    mp.nombre as nombre_producto,
    pp.codigo_barra,
    COALESCE(pp.precio_venta, mp.precio_venta * pp.factor_conversion) as precio_venta, 
    p.stock_actual::numeric,
    p.numero_lote,
    p.fecha_vencimiento,
    true as es_presentacion,
    pp.nombre_presentacion,
    pp.factor_conversion::numeric
  FROM public.productos p
  JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
  JOIN public.producto_presentaciones pp ON mp.id = pp.maestro_producto_id
  WHERE 
    p.stock_actual > 0 
    AND pp.codigo_barra ILIKE p_query;
END;
$$;

GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "service_role";

-- 3. PANEL DE ESTADÍSTICAS COMERCIAL (Ventas hoy y Fiados)
CREATE OR REPLACE FUNCTION "public"."get_dashboard_stats"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_total_products bigint;
  v_critical_stock bigint;
  v_ventas_hoy numeric(12,2);
  v_fiado_pendiente numeric(12,2);
  
  v_recent_movements json;
  v_category_distribution json;
  v_top_products json;
  v_sales_trend json;
  
  result json;
BEGIN
    SELECT COUNT(*) INTO v_total_products FROM public.productos WHERE stock_actual > 0;
    
    SELECT COUNT(DISTINCT mp.id) INTO v_critical_stock
    FROM public.maestro_productos mp
    JOIN public.productos p ON p.maestro_producto_id = mp.id
    GROUP BY mp.id
    HAVING SUM(p.stock_actual) <= mp.stock_critico;
    v_critical_stock := COALESCE(v_critical_stock, 0);

    -- Métricas Comerciales Reales
    SELECT SUM(total) INTO v_ventas_hoy FROM public.ventas WHERE creado_en::date = CURRENT_DATE AND tipo_venta != 'COTIZACION';
    SELECT SUM(saldo_actual) INTO v_fiado_pendiente FROM public.clientes WHERE saldo_actual > 0;

    -- Movimientos Recientes
    SELECT json_agg(t) INTO v_recent_movements FROM (
        SELECT m.creado_en as fecha, mp.nombre as producto, m.tipo_movimiento, m.cantidad, u.email as usuario
        FROM public.movimientos m
        JOIN public.productos p ON m.producto_id = p.id
        JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
        LEFT JOIN public.users u ON m.usuario_id = u.id
        ORDER BY m.creado_en DESC LIMIT 5
    ) t;

    -- Distribución por Categoría
    SELECT json_agg(t) INTO v_category_distribution FROM (
        SELECT mp.categoria as name, COUNT(*) as value
        FROM public.maestro_productos mp
        JOIN public.productos p ON p.maestro_producto_id = mp.id
        WHERE p.stock_actual > 0
        GROUP BY mp.categoria
    ) t;

    -- Top 5 Productos del Mes
    SELECT json_agg(t) INTO v_top_products FROM (
        SELECT mp.nombre, SUM(dv.cantidad * COALESCE(dv.factor_conversion, 1)) as total_vendido, SUM(dv.subtotal) as total_ingreso
        FROM public.detalle_ventas dv
        LEFT JOIN public.productos p ON dv.producto_id = p.id
        LEFT JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
        WHERE dv.creado_en >= date_trunc('month', CURRENT_DATE)
        GROUP BY mp.nombre ORDER BY total_vendido DESC LIMIT 5
    ) t;

    -- Tendencia 7 Días
    SELECT json_agg(t) INTO v_sales_trend FROM (
        SELECT to_char(date_trunc('day', v.creado_en), 'DD/MM') as fecha, SUM(v.total) as total
        FROM public.ventas v
        WHERE v.creado_en >= (CURRENT_DATE - INTERVAL '7 days') AND v.tipo_venta != 'COTIZACION'
        GROUP BY date_trunc('day', v.creado_en) ORDER BY date_trunc('day', v.creado_en)
    ) t;

    result := json_build_object(
        'total_products', COALESCE(v_total_products, 0),
        'critical_stock_products', COALESCE(v_critical_stock, 0),
        'total_ventas_hoy', COALESCE(v_ventas_hoy, 0),
        'total_fiado_pendiente', COALESCE(v_fiado_pendiente, 0),
        'recent_movements', COALESCE(v_recent_movements, '[]'::json),
        'category_distribution', COALESCE(v_category_distribution, '[]'::json),
        'top_products', COALESCE(v_top_products, '[]'::json),
        'sales_trend', COALESCE(v_sales_trend, '[]'::json)
    );
    RETURN result;
END;
$$;

-- 4. ACTUALIZACIÓN PROCESAR VENTA (Decimales y Auditoría)
CREATE OR REPLACE FUNCTION "public"."procesar_venta"("p_cliente_id" "uuid", "p_tipo_venta" "text", "p_items" "jsonb", "p_usuario_id" "uuid", "p_force_credit" boolean DEFAULT false) RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_venta_id uuid;
    v_total numeric(12,2) := 0;
    v_item jsonb;
    v_cantidad numeric(12,2);
    v_precio numeric(12,2);
    v_factor numeric(12,2);
    v_subtotal numeric(12,2);
    v_producto_id uuid;
    v_cantidad_descontar numeric(12,2);
    v_cliente_saldo numeric(12,2);
    v_cliente_cupo numeric(12,2);
    v_current_stock numeric(12,2);
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_total := v_total + ((v_item->>'cantidad')::numeric * (v_item->>'precio')::numeric);
    END LOOP;

    IF p_tipo_venta = 'FIADO' THEN
        SELECT saldo_actual, cupo_credito INTO v_cliente_saldo, v_cliente_cupo FROM public.clientes WHERE id = p_cliente_id;
        IF NOT p_force_credit AND (v_cliente_saldo + v_total) > v_cliente_cupo THEN
            RAISE EXCEPTION 'El cliente excede su cupo de crédito';
        END IF;

        UPDATE public.clientes SET saldo_actual = saldo_actual + v_total WHERE id = p_cliente_id;
    END IF;

    INSERT INTO public.ventas (cliente_id, tipo_venta, total, usuario_id)
    VALUES (p_cliente_id, p_tipo_venta::tipo_venta, v_total, p_usuario_id)
    RETURNING id INTO v_venta_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_producto_id := (v_item->>'producto_id')::uuid;
        v_cantidad := (v_item->>'cantidad')::numeric;
        v_precio := (v_item->>'precio')::numeric;
        v_factor := COALESCE((v_item->>'factor')::numeric, 1);
        v_subtotal := v_cantidad * v_precio;
        v_cantidad_descontar := v_cantidad * v_factor;

        SELECT stock_actual INTO v_current_stock FROM public.productos WHERE id = v_producto_id FOR UPDATE;
        
        UPDATE public.productos SET stock_actual = stock_actual - v_cantidad_descontar WHERE id = v_producto_id;
        INSERT INTO public.movimientos (producto_id, tipo_movimiento, cantidad, motivo, usuario_id)
        VALUES (v_producto_id, 'VENTA', v_cantidad_descontar, 'Venta Folio: ' || v_venta_id::text, p_usuario_id);
        INSERT INTO public.detalle_ventas (venta_id, producto_id, cantidad, precio_unitario, subtotal, factor_conversion)
        VALUES (v_venta_id, v_producto_id, v_cantidad, v_precio, v_subtotal, v_factor);
    END LOOP;

    RETURN v_venta_id;
END;
$$;

-- 5. ACTUALIZACIÓN HISTORIAL MOVIMIENTOS (Soporte decimal)
DROP FUNCTION IF EXISTS "public"."get_movement_history"(start_date date, end_date date, user_ids uuid[], movement_type text, search_term text);

CREATE OR REPLACE FUNCTION "public"."get_movement_history"(
    "start_date" "date", 
    "end_date" "date", 
    "user_ids" "uuid"[], 
    "movement_type" "text", 
    "search_term" "text"
) RETURNS TABLE(
    "fecha" timestamp with time zone, 
    "producto_nombre" "text", 
    "numero_lote" "text", 
    "proveedor_nombre" "text", 
    "tipo_movimiento" "text", 
    "cantidad" numeric, 
    "condicion" "text", 
    "usuario_nombre" "text", 
    "motivo" "text"
)
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.creado_en as fecha,
        mp.nombre as producto_nombre,
        p.numero_lote,
        prov.nombre as proveedor_nombre,
        m.tipo_movimiento,
        m.cantidad,
        m.condicion,
        COALESCE(u.name, u.email) as usuario_nombre,
        m.motivo
    FROM
        public.movimientos m
    LEFT JOIN
        public.productos p ON m.producto_id = p.id
    LEFT JOIN
        public.maestro_productos mp ON p.maestro_producto_id = mp.id
    LEFT JOIN
        public.users u ON m.usuario_id = u.id
    LEFT JOIN
        public.proveedores prov ON p.proveedor_id = prov.id
    WHERE
        (m.creado_en::date >= start_date AND m.creado_en::date <= end_date)
        AND (user_ids IS NULL OR array_length(user_ids, 1) IS NULL OR m.usuario_id = ANY(user_ids))
        AND (movement_type IS NULL OR m.tipo_movimiento = movement_type)
        AND (
            search_term IS NULL OR
            mp.nombre ILIKE '%' || search_term || '%' OR
            p.numero_lote ILIKE '%' || search_term || '%' OR
            prov.nombre ILIKE '%' || search_term || '%'
        )
    ORDER BY
        m.creado_en DESC;
END;
$$;

GRANT ALL ON FUNCTION "public"."get_movement_history" TO "anon";
GRANT ALL ON FUNCTION "public"."get_movement_history" TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_movement_history" TO "service_role";
