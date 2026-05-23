


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."session_status" AS ENUM (
    'OPEN',
    'COUNTING',
    'REVIEW',
    'APPLIED',
    'CANCELLED'
);


ALTER TYPE "public"."session_status" OWNER TO "postgres";


CREATE TYPE "public"."tipo_movimiento_cc" AS ENUM (
    'COMPRA',
    'ABONO',
    'AJUSTE'
);


ALTER TYPE "public"."tipo_movimiento_cc" OWNER TO "postgres";


CREATE TYPE "public"."tipo_venta" AS ENUM (
    'TRANSFERENCIA',
    'BOLETA',
    'FIADO',
    'FACTURA'
);


ALTER TYPE "public"."tipo_venta" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."abrir_caja"("p_usuario_id" "uuid", "p_monto_inicial" numeric, "p_caja_id" "uuid", "p_codigo_auth" "text") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_sesion_id UUID;
    v_stored_code TEXT;
BEGIN
    -- 1. Validate Auth Code
    SELECT value INTO v_stored_code FROM public.configuracion WHERE key = 'CODIGO_CAJA';
    IF v_stored_code IS NULL OR v_stored_code != p_codigo_auth THEN
        RAISE EXCEPTION 'Código de autorización inválido';
    END IF;

    -- 2. Check if User already has an open session
    IF EXISTS (SELECT 1 FROM public.sesiones_caja WHERE usuario_id = p_usuario_id AND estado = 'ABIERTA') THEN
        RAISE EXCEPTION 'Usuario ya tiene una caja abierta.';
    END IF;

    -- 3. Check if Caja is already open (by anyone)
    IF EXISTS (SELECT 1 FROM public.sesiones_caja WHERE caja_id = p_caja_id AND estado = 'ABIERTA') THEN
        RAISE EXCEPTION 'Esta caja ya está abierta por otro usuario.';
    END IF;

    -- 4. Open Session
    INSERT INTO public.sesiones_caja (usuario_id, monto_inicial, caja_id)
    VALUES (p_usuario_id, p_monto_inicial, p_caja_id)
    RETURNING id INTO v_sesion_id;

    -- 5. Log Movement
    INSERT INTO public.movimientos_caja (sesion_id, tipo_movimiento, monto, descripcion)
    VALUES (v_sesion_id, 'APERTURA', p_monto_inicial, 'Monto Inicial de Caja');

    RETURN v_sesion_id;
END;
$$;


ALTER FUNCTION "public"."abrir_caja"("p_usuario_id" "uuid", "p_monto_inicial" numeric, "p_caja_id" "uuid", "p_codigo_auth" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_clave_maestra"("p_actual_codigo" "text", "p_nuevo_codigo" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_stored_code TEXT;
BEGIN
    -- 1. Validate Current Code
    SELECT value INTO v_stored_code FROM public.configuracion WHERE key = 'CODIGO_CAJA';
    
    -- If no code exists, assume default '1234' or allow set if empty
    IF v_stored_code IS NOT NULL AND v_stored_code != p_actual_codigo THEN
        RAISE EXCEPTION 'La clave maestra actual es incorrecta.';
    END IF;

    -- 2. Update Code
    INSERT INTO public.configuracion (key, value)
    VALUES ('CODIGO_CAJA', p_nuevo_codigo)
    ON CONFLICT (key) DO UPDATE
    SET value = p_nuevo_codigo;

    RETURN true;
END;
$$;


ALTER FUNCTION "public"."actualizar_clave_maestra"("p_actual_codigo" "text", "p_nuevo_codigo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_stock"("p_product_id" "uuid", "p_qty" integer, "p_note" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Actualizar el stock del producto
  UPDATE products
  SET stock = stock + p_qty
  WHERE id = p_product_id;

  -- Registrar el movimiento de stock
  INSERT INTO stock_movements (product_id, user_id, qty, type, note)
  VALUES (p_product_id, auth.uid(), p_qty, 'ingreso_manual', p_note);
END;
$$;


ALTER FUNCTION "public"."add_stock"("p_product_id" "uuid", "p_qty" integer, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."agregar_stock"("p_producto_id" "uuid", "p_cantidad" integer, "p_nota" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE productos
  SET stock = stock + p_cantidad
  WHERE id = p_producto_id;

  INSERT INTO movimientos_stock (producto_id, usuario_id, cantidad, tipo, nota)
  VALUES (p_producto_id, auth.uid(), p_cantidad, 'ingreso_manual', p_nota);
END;
$$;


ALTER FUNCTION "public"."agregar_stock"("p_producto_id" "uuid", "p_cantidad" integer, "p_nota" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."analizar_diferencias_inventario"("p_session_id" "uuid") RETURNS TABLE("maestro_producto_id" "uuid", "nombre_producto" "text", "stock_sistema" numeric, "stock_fisico" numeric, "diferencia" numeric, "valor_diferencia" numeric)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    WITH conteo_agrupado AS (
        SELECT 
            c.maestro_producto_id AS m_id, 
            SUM(c.cantidad_total) as total_fisico
        FROM public.inventory_counts c
        WHERE c.session_id = p_session_id
        GROUP BY c.maestro_producto_id
    ),
    stock_sistema_agrupado AS (
        SELECT 
            p.maestro_producto_id AS p_m_id,
            SUM(p.stock_actual) as total_stock_sistema
        FROM public.productos p
        GROUP BY p.maestro_producto_id
    )
    SELECT 
        mp.id AS maestro_producto_id,
        mp.nombre AS nombre_producto,
        COALESCE(ssa.total_stock_sistema, 0)::numeric AS stock_sistema,
        COALESCE(ca.total_fisico, 0)::numeric AS stock_fisico,
        (COALESCE(ca.total_fisico, 0) - COALESCE(ssa.total_stock_sistema, 0))::numeric AS diferencia,
        ((COALESCE(ca.total_fisico, 0) - COALESCE(ssa.total_stock_sistema, 0)) * COALESCE(mp.precio_venta, 0))::numeric AS valor_diferencia
    FROM public.maestro_productos mp
    -- Join with counts (RIGHT JOIN ensures we see everything counted even if not in system, though unusual)
    -- Actually LEFT JOIN is better: We want to seeing discrepances for ALL products counted OR in system?
    -- For now, let's list products that have either system stock OR physical count.
    FULL OUTER JOIN stock_sistema_agrupado ssa ON mp.id = ssa.p_m_id
    FULL OUTER JOIN conteo_agrupado ca ON mp.id = ca.m_id
    WHERE 
        -- Filter to show only relevant items: those counted OR those with stock in system (to show missing items)
        (ca.total_fisico IS NOT NULL AND ca.total_fisico > 0) OR (ssa.total_stock_sistema > 0);
END;
$$;


ALTER FUNCTION "public"."analizar_diferencias_inventario"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."aplicar_ajuste_inventario"("p_session_id" "uuid", "p_usuario_id" "uuid", "p_maestro_producto_id" "uuid" DEFAULT NULL::"uuid", "p_motivo" "text" DEFAULT 'Ajuste inventario físico'::"text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_reporte RECORD;
    v_producto_lote uuid; 
    v_diferencia numeric;
BEGIN
    -- 1. Iterar sobre las diferencias (calculadas en vivo)
    FOR v_reporte IN 
        SELECT * FROM public.analizar_diferencias_inventario(p_session_id)
        WHERE (p_maestro_producto_id IS NULL OR maestro_producto_id = p_maestro_producto_id)
        AND diferencia != 0
    LOOP
        v_diferencia := v_reporte.diferencia;

        -- 1.1 GUARDAR SNAPSHOT (IMPORTANTE)
        INSERT INTO public.inventory_session_results (
            session_id, 
            maestro_producto_id, 
            nombre_producto, 
            stock_sistema_snapshot, 
            stock_fisico_final, 
            diferencia, 
            valor_ajuste
        ) VALUES (
            p_session_id,
            v_reporte.maestro_producto_id,
            v_reporte.nombre_producto,
            v_reporte.stock_sistema,
            v_reporte.stock_fisico,
            v_reporte.diferencia,
            v_reporte.valor_diferencia
        );

        -- 2. APLICAR AJUSTES (Igual que antes)
        
        -- CASO 1: Ajuste POSITIVO
        IF v_diferencia > 0 THEN
            SELECT id INTO v_producto_lote 
            FROM public.productos 
            WHERE maestro_producto_id = v_reporte.maestro_producto_id 
            ORDER BY creado_en DESC LIMIT 1;
            
            IF v_producto_lote IS NOT NULL THEN
                UPDATE public.productos SET stock_actual = stock_actual + v_diferencia WHERE id = v_producto_lote;
                INSERT INTO public.movimientos (producto_id, tipo_movimiento, cantidad, usuario_id, motivo, condicion, creado_en)
                VALUES (v_producto_lote, 'entrada', v_diferencia, p_usuario_id, p_motivo || ' (Sobrante)', 'Bueno', now());
            END IF;

        -- CASO 2: Ajuste NEGATIVO
        ELSIF v_diferencia < 0 THEN
            DECLARE
                v_lote_cursor RECORD;
                v_pendiente numeric := ABS(v_diferencia);
                v_descontar numeric;
            BEGIN
                FOR v_lote_cursor IN 
                    SELECT id, stock_actual FROM public.productos 
                    WHERE maestro_producto_id = v_reporte.maestro_producto_id AND stock_actual > 0
                    ORDER BY fecha_vencimiento ASC NULLS LAST, creado_en ASC
                LOOP
                    IF v_pendiente <= 0 THEN EXIT; END IF;
                    IF v_lote_cursor.stock_actual >= v_pendiente THEN
                        v_descontar := v_pendiente;
                    ELSE
                        v_descontar := v_lote_cursor.stock_actual;
                    END IF;
                    UPDATE public.productos SET stock_actual = stock_actual - v_descontar WHERE id = v_lote_cursor.id;
                    INSERT INTO public.movimientos (producto_id, tipo_movimiento, cantidad, usuario_id, motivo, condicion, creado_en)
                    VALUES (v_lote_cursor.id, 'salida', v_descontar, p_usuario_id, p_motivo || ' (Faltante)', 'Bueno', now());
                    v_pendiente := v_pendiente - v_descontar;
                END LOOP;
            END;
        END IF;

    END LOOP;

    -- Marcar sesión como APLICADA
    UPDATE public.inventory_sessions 
    SET estado = 'APPLIED', fecha_cierre = now() 
    WHERE id = p_session_id;

END;
$$;


ALTER FUNCTION "public"."aplicar_ajuste_inventario"("p_session_id" "uuid", "p_usuario_id" "uuid", "p_maestro_producto_id" "uuid", "p_motivo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cerrar_caja"("p_sesion_id" "uuid", "p_monto_declarado" numeric, "p_codigo_auth" "text", "p_nombre_cajera" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_monto_esperado NUMERIC;
    v_diferencia NUMERIC;
    v_stored_code TEXT;
BEGIN
    -- 1. Validate Auth Code
    SELECT value INTO v_stored_code FROM public.configuracion WHERE key = 'CODIGO_CAJA';
    IF v_stored_code IS NULL OR v_stored_code != p_codigo_auth THEN
        RAISE EXCEPTION 'Código de autorización inválido';
    END IF;

    -- 2. Calculate Expected
    SELECT COALESCE(SUM(monto), 0) INTO v_monto_esperado
    FROM public.movimientos_caja
    WHERE sesion_id = p_sesion_id;

    v_diferencia := p_monto_declarado - v_monto_esperado;

    -- 3. Update Session
    UPDATE public.sesiones_caja
    SET fecha_cierre = now(),
        estado = 'CERRADA',
        monto_final_declarado = p_monto_declarado,
        monto_final_esperado = v_monto_esperado,
        diferencia = v_diferencia,
        nombre_cajera_cierre = p_nombre_cajera
    WHERE id = p_sesion_id;

    RETURN jsonb_build_object(
        'success', true,
        'esperado', v_monto_esperado,
        'declarado', p_monto_declarado,
        'diferencia', v_diferencia
    );
END;
$$;


ALTER FUNCTION "public"."cerrar_caja"("p_sesion_id" "uuid", "p_monto_declarado" numeric, "p_codigo_auth" "text", "p_nombre_cajera" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_nueva_caja"("p_nombre" "text", "p_codigo_auth" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_stored_code TEXT;
    v_new_id UUID;
BEGIN
    -- 1. Validate Auth Code
    SELECT value INTO v_stored_code FROM public.configuracion WHERE key = 'CODIGO_CAJA';
    IF v_stored_code IS NULL OR v_stored_code != p_codigo_auth THEN
        RAISE EXCEPTION 'Código de autorización inválido';
    END IF;

    -- 2. Validate Uniqueness
    IF EXISTS (SELECT 1 FROM public.cajas WHERE lower(nombre) = lower(p_nombre)) THEN
        RAISE EXCEPTION 'Ya existe una caja con ese nombre';
    END IF;

    -- 3. Insert
    INSERT INTO public.cajas (nombre, activo)
    VALUES (p_nombre, true)
    RETURNING id INTO v_new_id;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_new_id,
        'nombre', p_nombre
    );
END;
$$;


ALTER FUNCTION "public"."crear_nueva_caja"("p_nombre" "text", "p_codigo_auth" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_venta"("p_items" json) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_venta_id uuid;
  v_total numeric := 0;
  v_item record;
  v_precio_producto numeric;
BEGIN
  -- 1. Calcular el total y verificar stock
  FOR v_item IN SELECT * FROM json_to_recordset(p_items) AS x(producto_id uuid, cantidad int)
  LOOP
    SELECT precio INTO v_precio_producto FROM productos WHERE id = v_item.producto_id;
    
    IF (SELECT stock FROM productos WHERE id = v_item.producto_id) < v_item.cantidad THEN
      RAISE EXCEPTION 'No hay stock suficiente para el producto %', (SELECT nombre FROM productos WHERE id = v_item.producto_id);
    END IF;
    
    v_total := v_total + (v_precio_producto * v_item.cantidad);
  END LOOP;

  -- 2. Crear la venta
  INSERT INTO ventas (usuario_id, total)
  VALUES (auth.uid(), v_total)
  RETURNING id INTO v_venta_id;

  -- 3. Insertar items y actualizar stock
  FOR v_item IN SELECT * FROM json_to_recordset(p_items) AS x(producto_id uuid, cantidad int)
  LOOP
    SELECT precio INTO v_precio_producto FROM productos WHERE id = v_item.producto_id;

    INSERT INTO items_venta (venta_id, producto_id, cantidad, precio)
    VALUES (v_venta_id, v_item.producto_id, v_item.cantidad, v_precio_producto);

    UPDATE productos
    SET stock = stock - v_item.cantidad
    WHERE id = v_item.producto_id;

    INSERT INTO movimientos_stock (producto_id, usuario_id, cantidad, tipo, nota)
    VALUES (v_item.producto_id, auth.uid(), -v_item.cantidad, 'venta', 'Venta ID: ' || v_venta_id);
  END LOOP;

  RETURN v_venta_id;
END;
$$;


ALTER FUNCTION "public"."crear_venta"("p_items" json) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_sale"("p_items" json) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_sale_id uuid;
  v_total numeric := 0;
  v_item record;
  v_product_price numeric;
BEGIN
  -- 1. Calcular el total y verificar stock
  FOR v_item IN SELECT * FROM json_to_recordset(p_items) AS x(product_id uuid, qty int)
  LOOP
    SELECT price INTO v_product_price FROM products WHERE id = v_item.product_id;
    
    -- Verificar si hay stock suficiente
    IF (SELECT stock FROM products WHERE id = v_item.product_id) < v_item.qty THEN
      RAISE EXCEPTION 'No hay stock suficiente para el producto %', (SELECT name FROM products WHERE id = v_item.product_id);
    END IF;
    
    v_total := v_total + (v_product_price * v_item.qty);
  END LOOP;

  -- 2. Crear la venta
  INSERT INTO sales (user_id, total)
  VALUES (auth.uid(), v_total)
  RETURNING id INTO v_sale_id;

  -- 3. Insertar los items de la venta y actualizar stock
  FOR v_item IN SELECT * FROM json_to_recordset(p_items) AS x(product_id uuid, qty int)
  LOOP
    -- Obtener el precio actual para registrarlo
    SELECT price INTO v_product_price FROM products WHERE id = v_item.product_id;

    -- Insertar el item en la venta
    INSERT INTO sale_items (sale_id, product_id, qty, price)
    VALUES (v_sale_id, v_item.product_id, v_item.qty, v_product_price);

    -- Actualizar el stock del producto
    UPDATE products
    SET stock = stock - v_item.qty
    WHERE id = v_item.product_id;

    -- Registrar el movimiento de stock
    INSERT INTO stock_movements (product_id, user_id, qty, type, note)
    VALUES (v_item.product_id, auth.uid(), -v_item.qty, 'venta', 'Venta ID: ' || v_sale_id);
  END LOOP;

  RETURN v_sale_id;
END;
$$;


ALTER FUNCTION "public"."create_sale"("p_items" json) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_critical_stock_products_list"() RETURNS TABLE("producto_id" "uuid", "producto_nombre" "text", "numero_lote" "text", "stock_actual" bigint, "stock_critico" integer, "fecha_vencimiento" "date", "condicion" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    -- CTE to calculate stock for 'Bueno' condition only
    WITH bueno_stock AS (
        SELECT
            m.producto_id,
            SUM(CASE WHEN m.tipo_movimiento = 'entrada' THEN m.cantidad ELSE -m.cantidad END) as stock
        FROM
            public.movimientos m
        WHERE
            LOWER(m.condicion) = 'bueno'
        GROUP BY
            m.producto_id
    )
    SELECT
        p.id as producto_id,
        mp.nombre as producto_nombre,
        p.numero_lote,
        bs.stock::bigint as stock_actual,
        mp.stock_critico,
        p.fecha_vencimiento,
        'Bueno'::text as condicion -- The condition for this list is always 'Bueno'
    FROM
        bueno_stock bs
    JOIN
        public.productos p ON bs.producto_id = p.id
    JOIN
        public.maestro_productos mp ON p.maestro_producto_id = mp.id
    WHERE
        bs.stock <= mp.stock_critico AND bs.stock > 0
    ORDER BY
        mp.nombre, p.numero_lote;
END;
$$;


ALTER FUNCTION "public"."get_critical_stock_products_list"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dashboard_stats"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_total_products bigint;
  v_critical_stock bigint;
  v_expired_products bigint;
  v_quarantine_products bigint;
  
  v_recent_movements json;
  v_category_distribution json;
  v_top_products json;
  v_sales_trend json;
  
  result json;
BEGIN
    -- 1. Calcular escalares primero (más seguro y limpio)
    SELECT COUNT(*) INTO v_total_products FROM public.productos WHERE stock_actual > 0;
    
    SELECT COUNT(DISTINCT mp.id) INTO v_critical_stock
    FROM public.maestro_productos mp
    JOIN public.productos p ON p.maestro_producto_id = mp.id
    GROUP BY mp.id
    HAVING SUM(p.stock_actual) <= mp.stock_critico;
    
    -- Manejo seguro si no hay items críticos (COUNT puede devolver null en HAVING vacío si no se envuelve)
    v_critical_stock := COALESCE(v_critical_stock, 0);

    SELECT COUNT(*) INTO v_expired_products FROM public.productos WHERE fecha_vencimiento < CURRENT_DATE;
    SELECT COUNT(*) INTO v_quarantine_products FROM public.productos WHERE condicion = 'Cuarentena';

    -- 2. Calcular JSONs complejos por separado

    -- A. Movimientos Recientes
    SELECT json_agg(t) INTO v_recent_movements FROM (
        SELECT 
           m.creado_en as fecha,
           mp.nombre as producto,
           m.tipo_movimiento,
           m.cantidad,
           u.email as usuario
        FROM public.movimientos m
        JOIN public.productos p ON m.producto_id = p.id
        JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
        LEFT JOIN public.users u ON m.usuario_id = u.id
        ORDER BY m.creado_en DESC
        LIMIT 5
    ) t;

    -- B. Distribución
    SELECT json_agg(t) INTO v_category_distribution FROM (
        SELECT mp.categoria as name, COUNT(*) as value
        FROM public.maestro_productos mp
        JOIN public.productos p ON p.maestro_producto_id = mp.id
        WHERE p.stock_actual > 0
        GROUP BY mp.categoria
    ) t;

    -- C. Top Productos
    SELECT json_agg(t) INTO v_top_products FROM (
        SELECT 
          mp.nombre, 
          SUM(dv.cantidad * COALESCE(dv.factor_conversion, 1)) as total_vendido,
          SUM(dv.subtotal) as total_ingreso
        FROM public.detalle_ventas dv
        LEFT JOIN public.productos p ON dv.producto_id = p.id
        LEFT JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
        WHERE dv.creado_en >= date_trunc('month', CURRENT_DATE)
        GROUP BY mp.nombre
        ORDER BY total_vendido DESC
        LIMIT 5
    ) t;

    -- D. Tendencia Ventas
    SELECT json_agg(t) INTO v_sales_trend FROM (
        SELECT 
            to_char(date_trunc('day', dv.creado_en), 'DD/MM') as fecha,
            SUM(dv.subtotal) as total
        FROM public.detalle_ventas dv
        WHERE dv.creado_en >= (CURRENT_DATE - INTERVAL '7 days')
        GROUP BY date_trunc('day', dv.creado_en)
        ORDER BY date_trunc('day', dv.creado_en)
    ) t;

    -- 3. Construir resultado final
    -- Usamos COALESCE(..., '[]'::json) para asegurar que nunca devolvemos null en los arrays
    result := json_build_object(
        'total_products', COALESCE(v_total_products, 0),
        'critical_stock_products', COALESCE(v_critical_stock, 0),
        'expired_products', COALESCE(v_expired_products, 0),
        'quarantine_products', COALESCE(v_quarantine_products, 0),
        'recent_movements', COALESCE(v_recent_movements, '[]'::json),
        'category_distribution', COALESCE(v_category_distribution, '[]'::json),
        'top_products', COALESCE(v_top_products, '[]'::json),
        'sales_trend', COALESCE(v_sales_trend, '[]'::json)
    );

  RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_dashboard_stats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dispatch_lots"("param_maestro_producto_id" "uuid") RETURNS TABLE("producto_id" "uuid", "numero_lote" "text", "fecha_vencimiento" "date", "condicion_lote" "text", "stock_actual" bigint, "maestro_producto_nombre" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    WITH movements_summary AS (
        -- Calculate stock for each product/condition pair, ignoring case
        SELECT
            m.producto_id,
            LOWER(m.condicion) as condicion,
            SUM(CASE WHEN m.tipo_movimiento = 'entrada' THEN m.cantidad ELSE -m.cantidad END)::bigint as stock
        FROM
            public.movimientos m
        GROUP BY
            m.producto_id, LOWER(m.condicion)
    )
    SELECT
        p.id::uuid,
        p.numero_lote::text,
        p.fecha_vencimiento,
        initcap(ms.condicion)::text, -- Standardize capitalization for display
        ms.stock::bigint,
        mp.nombre::text
    FROM
        movements_summary ms
    JOIN
        public.productos p ON ms.producto_id = p.id
    JOIN
        public.maestro_productos mp ON p.maestro_producto_id = mp.id
    WHERE
        p.maestro_producto_id = param_maestro_producto_id AND ms.stock > 0
    ORDER BY
        p.fecha_vencimiento ASC, p.numero_lote, ms.condicion;
END;
$$;


ALTER FUNCTION "public"."get_dispatch_lots"("param_maestro_producto_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_expiring_products_list"("days_threshold" integer) RETURNS TABLE("producto_id" "uuid", "producto_nombre" "text", "numero_lote" "text", "stock_actual" bigint, "fecha_vencimiento" "date", "condicion" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id as producto_id,
        mp.nombre as producto_nombre,
        p.numero_lote,
        COALESCE(aspp.total_stock_for_product, 0)::bigint as stock_actual,
        p.fecha_vencimiento,
        p.condicion
    FROM
        public.productos p
    JOIN
        public.maestro_productos mp ON p.maestro_producto_id = mp.id
    LEFT JOIN (
        SELECT
            m.producto_id,
            SUM(CASE WHEN m.tipo_movimiento = 'entrada' THEN m.cantidad ELSE -m.cantidad END)::bigint as total_stock_for_product
        FROM
            public.movimientos m
        GROUP BY
            m.producto_id
    ) aspp ON p.id = aspp.producto_id
    WHERE
        p.fecha_vencimiento <= (NOW() + INTERVAL '1 day' * days_threshold)::date AND COALESCE(aspp.total_stock_for_product, 0) > 0
    ORDER BY
        p.fecha_vencimiento ASC, mp.nombre;
END;
$$;


ALTER FUNCTION "public"."get_expiring_products_list"("days_threshold" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_inventory_stock"() RETURNS TABLE("row_id" "text", "id" "uuid", "maestro_producto_id" "uuid", "proveedor_id" "uuid", "stock_actual" bigint, "numero_lote" "text", "fecha_vencimiento" timestamp with time zone, "observaciones" "text", "creado_en" timestamp with time zone, "bloqueado" boolean, "fecha_ingreso" timestamp with time zone, "condicion" "text", "maestro_productos" json, "proveedores" json, "total_stock_lote" bigint, "ultima_observacion" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    WITH stock_per_condition AS (
        SELECT
            m.producto_id,
            initcap(trim(m.condicion)) as condicion_raw, -- Normalizar al leer
            SUM(CASE WHEN m.tipo_movimiento = 'entrada' THEN m.cantidad ELSE -m.cantidad END) as stock
        FROM public.movimientos m
        GROUP BY m.producto_id, initcap(trim(m.condicion)) -- Agrupar normalizado
        HAVING SUM(CASE WHEN m.tipo_movimiento = 'entrada' THEN m.cantidad ELSE -m.cantidad END) > 0
    ),
    total_stock_per_product AS (
        SELECT
            s.producto_id,
            SUM(s.stock) as total_stock
        FROM stock_per_condition s
        GROUP BY s.producto_id
    ),
    latest_observation AS (
        SELECT DISTINCT ON (mov.producto_id, initcap(trim(mov.condicion)))
            mov.producto_id,
            initcap(trim(mov.condicion)) as condicion,
            mov.motivo
        FROM public.movimientos mov
        WHERE mov.motivo IS NOT NULL AND TRIM(mov.motivo) <> ''
        ORDER BY mov.producto_id, initcap(trim(mov.condicion)), mov.creado_en DESC
    )
    SELECT
        (p.id::text || '-' || spc.condicion_raw) AS row_id, -- Generar ID único
        p.id,
        p.maestro_producto_id,
        p.proveedor_id,
        spc.stock::BIGINT AS stock_actual,
        p.numero_lote,
        p.fecha_vencimiento::TIMESTAMPTZ,
        p.observaciones,
        p.creado_en,
        p.bloqueado,
        p.fecha_ingreso,
        spc.condicion_raw AS condicion,
        json_build_object(
            'id', mp.id,
            'nombre', mp.nombre,
            'codigo_barra', mp.codigo_barra, -- Add Barcode
            'precio_venta', mp.precio_venta, -- Add Selling Price
            'categoria', mp.categoria,
            'stock_critico', mp.stock_critico
        ) AS maestro_productos,
        json_build_object(
            'id', prv.id,
            'nombre', prv.nombre
        ) AS proveedores,
        tsp.total_stock::BIGINT AS total_stock_lote,
        lo.motivo AS ultima_observacion
    FROM
        stock_per_condition spc
    JOIN
        public.productos p ON spc.producto_id = p.id
    JOIN
        total_stock_per_product tsp ON p.id = tsp.producto_id
    JOIN
        public.maestro_productos mp ON p.maestro_producto_id = mp.id
    LEFT JOIN
        public.proveedores prv ON p.proveedor_id = prv.id
    LEFT JOIN
        latest_observation lo ON spc.producto_id = lo.producto_id AND spc.condicion_raw = lo.condicion
    ORDER BY
        mp.nombre ASC, p.numero_lote ASC, spc.condicion_raw ASC;
END;
$$;


ALTER FUNCTION "public"."get_inventory_stock"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_movement_history"("start_date" "date", "end_date" "date", "user_ids" "uuid"[], "movement_type" "text", "search_term" "text") RETURNS TABLE("fecha" timestamp with time zone, "producto_nombre" "text", "numero_lote" "text", "proveedor_nombre" "text", "tipo_movimiento" "text", "cantidad" integer, "condicion" "text", "usuario_nombre" "text", "motivo" "text")
    LANGUAGE "plpgsql"
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
        -- FIX: Use the 'name' column directly as it exists in the table
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


ALTER FUNCTION "public"."get_movement_history"("start_date" "date", "end_date" "date", "user_ids" "uuid"[], "movement_type" "text", "search_term" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_quarantine_products_list"() RETURNS TABLE("producto_id" "uuid", "producto_nombre" "text", "numero_lote" "text", "stock_actual" bigint, "fecha_vencimiento" "date", "condicion" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    WITH stock_in_quarantine AS (
        -- Calculate stock for each product specifically in 'Cuarentena', case-insensitive
        SELECT
            m.producto_id,
            LOWER(m.condicion) as condicion_actual,
            SUM(CASE WHEN m.tipo_movimiento = 'entrada' THEN m.cantidad ELSE -m.cantidad END) as stock
        FROM
            public.movimientos m
        GROUP BY
            m.producto_id, LOWER(m.condicion)
        HAVING
            LOWER(m.condicion) = 'cuarentena' AND SUM(CASE WHEN m.tipo_movimiento = 'entrada' THEN m.cantidad ELSE -m.cantidad END) > 0
    )
    SELECT
        p.id as producto_id,
        mp.nombre as producto_nombre,
        p.numero_lote,
        siq.stock::bigint as stock_actual,
        p.fecha_vencimiento,
        initcap(siq.condicion_actual) as condicion
    FROM
        stock_in_quarantine siq
    JOIN
        public.productos p ON siq.producto_id = p.id
    JOIN
        public.maestro_productos mp ON p.maestro_producto_id = mp.id
    ORDER BY
        mp.nombre, p.numero_lote;
END;
$$;


ALTER FUNCTION "public"."get_quarantine_products_list"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_todays_deliveries"() RETURNS TABLE("id" "uuid", "created_at" timestamp with time zone, "paciente_id" "uuid", "mes_entrega" "date", "indicaciones_medicas" "text", "usuario_id" "uuid", "pacientes" json, "usuario" json, "entregas_items" "jsonb"[])
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        e.created_at,
        e.paciente_id,
        e.mes_entrega,
        e.indicaciones_medicas,
        e.usuario_id,
        json_build_object('nombre', p.nombre, 'rut', p.rut) as pacientes,
        json_build_object('name', u.name) as usuario,
        (SELECT COALESCE(array_agg(jsonb_build_object(
            'cantidad', ei.cantidad,
            'maestro_productos', jsonb_build_object('nombre', mp.nombre)
        )), '{}')
         FROM entregas_items ei
         JOIN maestro_productos mp ON ei.maestro_producto_id = mp.id
         WHERE ei.entrega_id = e.id
        ) as entregas_items
    FROM
        entregas e
    LEFT JOIN
        pacientes p ON e.paciente_id = p.id
    LEFT JOIN
        users u ON e.usuario_id = u.id
    WHERE
        e.created_at >= date_trunc('day', now() AT TIME ZONE 'utc') AND
        e.created_at < date_trunc('day', now() AT TIME ZONE 'utc') + interval '1 day'
    ORDER BY
        e.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_todays_deliveries"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_users"() RETURNS TABLE("id" "uuid", "email" "text", "name" "text", "role" "text", "created_at" timestamp with time zone, "last_sign_in_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  select
    id,
    email,
    raw_user_meta_data->>'name' as name,
    raw_user_meta_data->>'role' as role,
    created_at,
    last_sign_in_at
  from auth.users;
$$;


ALTER FUNCTION "public"."get_users"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'name', 'user'); -- Default role to 'user'
  RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  is_admin_result boolean;
BEGIN
  SELECT (role = 'admin')
  INTO is_admin_result
  FROM public.users
  WHERE id = auth.uid();
  RETURN COALESCE(is_admin_result, false);
END;
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."procesar_recepcion_mercaderia"("p_numero_documento" "text", "p_tipo_documento" "text", "p_proveedor_id" "uuid", "p_usuario_id" "uuid", "p_detalles" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_recepcion_id UUID;
    v_item JSONB;
    v_producto_id UUID;
    v_total_neto NUMERIC := 0;
BEGIN
    -- A. Create Receipt Header
    INSERT INTO public.recepciones (numero_documento, tipo_documento, proveedor_id, usuario_id)
    VALUES (p_numero_documento, p_tipo_documento, p_proveedor_id, p_usuario_id)
    RETURNING id INTO v_recepcion_id;

    -- B. Loop through items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles)
    LOOP
        -- Calculate Total
        v_total_neto := v_total_neto + ((v_item->>'cantidad')::NUMERIC * (v_item->>'precio_costo')::NUMERIC);

        -- 1. Save Detail Record
        INSERT INTO public.detalle_recepcion (recepcion_id, maestro_producto_id, cantidad, precio_costo_unitario, numero_lote, fecha_vencimiento)
        VALUES (
            v_recepcion_id,
            (v_item->>'id')::UUID, -- Maestro ID
            (v_item->>'cantidad')::NUMERIC,
            (v_item->>'precio_costo')::NUMERIC,
            v_item->>'lote',
            (v_item->>'vencimiento')::DATE
        );

        -- 2. Create/Update Inventory Stock
        -- Logic: Create a new unique Entry/Batch in 'productos' table to maintain traceability of this specific lot arrival
        INSERT INTO public.productos (
            maestro_producto_id,
            proveedor_id,
            stock_actual,
            numero_lote,
            fecha_vencimiento,
            condicion,
            fecha_ingreso
        )
        VALUES (
            (v_item->>'id')::UUID,
            p_proveedor_id,
            (v_item->>'cantidad')::NUMERIC,
            v_item->>'lote',
            (v_item->>'vencimiento')::DATE,
            'Bueno',
            now()
        )
        RETURNING id INTO v_producto_id;

        -- 3. Record Movement Log
        INSERT INTO public.movimientos (
            producto_id,
            usuario_id,
            tipo_movimiento,
            cantidad,
            motivo
        )
        VALUES (
            v_producto_id,
            p_usuario_id,
            'entrada',
            (v_item->>'cantidad')::NUMERIC,
            'Recepción Compra ' || p_tipo_documento || ' ' || p_numero_documento
        );

    END LOOP;

    -- C. Update Total
    UPDATE public.recepciones SET total_neto = v_total_neto WHERE id = v_recepcion_id;

    RETURN jsonb_build_object('success', true, 'recepcion_id', v_recepcion_id);
EXCEPTION WHEN OTHERS THEN
    -- Rollback is automatic in Postgres RPC if an exception is raised
    RAISE;
END;
$$;


ALTER FUNCTION "public"."procesar_recepcion_mercaderia"("p_numero_documento" "text", "p_tipo_documento" "text", "p_proveedor_id" "uuid", "p_usuario_id" "uuid", "p_detalles" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."procesar_venta"("p_cliente_id" "uuid", "p_tipo_venta" "text", "p_items" "jsonb", "p_usuario_id" "uuid", "p_force_credit" boolean DEFAULT false) RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_venta_id uuid;
    v_total numeric(10,2) := 0;
    v_item jsonb;
    v_cantidad numeric; -- Puede ser decimal si vendemos kg? Por ahora int, pero numeric es más seguro.
    v_precio numeric(10,2);
    v_factor numeric;
    v_subtotal numeric(10,2);
    v_producto_id uuid;
    v_cantidad_descontar numeric;
    v_cliente_saldo numeric(10,2);
    v_cliente_cupo numeric(10,2);
    v_current_stock int;
BEGIN
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
        FROM public.clientes WHERE id = p_cliente_id;
        
        IF v_cliente_saldo IS NULL THEN 
            RAISE EXCEPTION 'Cliente no encontrado';
        END IF;

        IF NOT p_force_credit AND (v_cliente_saldo + v_total) > v_cliente_cupo THEN
            RAISE EXCEPTION 'El cliente excede su cupo de crédito';
        END IF;
    END IF;

    -- 3. Crear cabecera Venta
    INSERT INTO public.ventas (cliente_id, tipo_venta, total, usuario_id)
    VALUES (p_cliente_id, p_tipo_venta::tipo_venta, v_total, p_usuario_id)
    RETURNING id INTO v_venta_id;

    -- 4. Procesar Detalle y Stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_producto_id := (v_item->>'producto_id')::uuid;
        v_cantidad := (v_item->>'cantidad')::numeric;
        v_precio := (v_item->>'precio')::numeric;
        v_factor := COALESCE((v_item->>'factor')::numeric, 1);
        v_subtotal := v_cantidad * v_precio;
        
        -- Cantidad real a sacar del inventario (ej. 1 caja * 12 = 12 unidades)
        v_cantidad_descontar := v_cantidad * v_factor;

        -- Verificar Stock
        SELECT stock_actual INTO v_current_stock FROM public.productos WHERE id = v_producto_id FOR UPDATE;
        
        IF v_current_stock < v_cantidad_descontar THEN
             RAISE EXCEPTION 'Stock insuficiente para el producto % (Stock: %, Necesario: %)', v_producto_id, v_current_stock, v_cantidad_descontar;
        END IF;

        -- Descontar Stock
        UPDATE public.productos 
        SET stock_actual = stock_actual - v_cantidad_descontar
        WHERE id = v_producto_id;
        
        -- Registrar Movimiento de Salida (Kardex)
        INSERT INTO public.movimientos (producto_id, tipo_movimiento, cantidad, motivo, usuario_id)
        VALUES (v_producto_id, 'VENTA', v_cantidad_descontar, 'Venta Foli: ' || v_venta_id::text, p_usuario_id);

        -- Insertar Detalle Venta (Guardamos cantidad vendida (cajas) y el factor)
        INSERT INTO public.detalle_ventas (venta_id, producto_id, cantidad, precio_unitario, subtotal, factor_conversion)
        VALUES (v_venta_id, v_producto_id, v_cantidad, v_precio, v_subtotal, v_factor);
    END LOOP;

    -- 5. Actualizar Cta Cte Fiado
    IF p_tipo_venta = 'FIADO' THEN
        UPDATE public.clientes
        SET saldo_actual = saldo_actual + v_total,
            actualizado_en = now()
        WHERE id = p_cliente_id;

        INSERT INTO public.movimientos_cuenta_corriente (cliente_id, venta_id, tipo, monto, saldo_posterior, usuario_id)
        VALUES (p_cliente_id, v_venta_id, 'COMPRA', v_total, v_cliente_saldo + v_total, p_usuario_id);
    END IF;

    RETURN v_venta_id;
END;
$$;


ALTER FUNCTION "public"."procesar_venta"("p_cliente_id" "uuid", "p_tipo_venta" "text", "p_items" "jsonb", "p_usuario_id" "uuid", "p_force_credit" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recepcionar_orden_compra"("p_orden_id" "uuid", "p_usuario_id" "uuid", "p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_item JSONB;
    v_detalle_id UUID;
    v_cantidad INT;
    v_lote TEXT;
    v_vencimiento DATE;
    v_maestro_id UUID;
    v_orden_status TEXT := 'COMPLETADA';
    v_new_product_id UUID;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_detalle_id := (v_item->>'detalle_id')::uuid;
        v_cantidad := (v_item->>'cantidad')::int;
        v_lote := v_item->>'lote';
        v_vencimiento := (v_item->>'vencimiento')::date;

        SELECT maestro_producto_id INTO v_maestro_id
        FROM public.detalle_ordenes_compra
        WHERE id = v_detalle_id;

        IF v_maestro_id IS NULL THEN
            RAISE EXCEPTION 'Detalle de orden no encontrado: %', v_detalle_id;
        END IF;

        UPDATE public.detalle_ordenes_compra
        SET cantidad_recibida = COALESCE(cantidad_recibida, 0) + v_cantidad
        WHERE id = v_detalle_id;

        INSERT INTO public.productos (
            maestro_producto_id,
            stock_actual,
            numero_lote,
            fecha_vencimiento,
            fecha_ingreso,
            condicion,
            ubicacion
        ) VALUES (
            v_maestro_id,
            v_cantidad,
            v_lote,
            v_vencimiento,
            now(),
            'Bueno',
            'Bodega General'
        ) 
        RETURNING id INTO v_new_product_id;
        
        INSERT INTO public.movimientos (
            producto_id,
            tipo_movimiento,
            cantidad,
            usuario_id,
            motivo,
            origen_destino,
            condicion,
            creado_en -- FIXED
        ) VALUES (
            v_new_product_id,
            'entrada',
            v_cantidad,
            p_usuario_id,
            'Recepción Orden Compra',
            'Proveedor',
            'Bueno',
            now()
        );

    END LOOP;

    IF EXISTS (
        SELECT 1 FROM public.detalle_ordenes_compra
        WHERE orden_id = p_orden_id AND cantidad_recibida < cantidad_solicitada
    ) THEN
        v_orden_status := 'RECEPCION_PARCIAL';
    END IF;

    UPDATE public.ordenes_compra
    SET estado = v_orden_status,
        fecha_recepcion_final = CASE WHEN v_orden_status = 'COMPLETADA' THEN now() ELSE NULL END
    WHERE id = p_orden_id;

END;
$$;


ALTER FUNCTION "public"."recepcionar_orden_compra"("p_orden_id" "uuid", "p_usuario_id" "uuid", "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registrar_salida_manual"("p_usuario_id" "uuid", "p_motivo" "text", "p_salidas" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    salida_item jsonb;
    v_stock_disponible BIGINT;
BEGIN
    -- Ensure the array is not empty
    IF jsonb_array_length(p_salidas) = 0 THEN
        RAISE EXCEPTION 'La lista de salidas no puede estar vacía.';
    END IF;

    -- 1. Validation Pass: Check all items before making any changes
    FOR salida_item IN SELECT * FROM jsonb_array_elements(p_salidas)
    LOOP
        -- Check for required fields
        IF NOT (salida_item ? 'producto_id' AND salida_item ? 'cantidad' AND salida_item ? 'condicion') THEN
            RAISE EXCEPTION 'Cada item de salida debe tener "producto_id", "cantidad" y "condicion".';
        END IF;

        -- Get current stock for the specific product and condition
        SELECT COALESCE(SUM(CASE WHEN m.tipo_movimiento = 'entrada' THEN m.cantidad ELSE -m.cantidad END), 0)
        INTO v_stock_disponible
        FROM public.movimientos m
        WHERE m.producto_id = (salida_item->>'producto_id')::uuid
          AND m.condicion = (salida_item->>'condicion')::text;

        -- Validate stock
        IF v_stock_disponible < (salida_item->>'cantidad')::bigint THEN
            RAISE EXCEPTION 'Stock insuficiente para el producto con ID % y condición %. Stock disponible: %, Cantidad solicitada: %',
                salida_item->>'producto_id', salida_item->>'condicion', v_stock_disponible, salida_item->>'cantidad';
        END IF;

        -- Validate quantity
        IF (salida_item->>'cantidad')::bigint <= 0 THEN
            RAISE EXCEPTION 'La cantidad a retirar debe ser mayor que cero.';
        END IF;
    END LOOP;

    -- 2. Insertion Pass: If all validations passed, insert the movements
    FOR salida_item IN SELECT * FROM jsonb_array_elements(p_salidas)
    LOOP
        -- Record the dispatch movement
        INSERT INTO public.movimientos (producto_id, usuario_id, tipo_movimiento, cantidad, motivo, condicion)
        VALUES (
            (salida_item->>'producto_id')::uuid,
            p_usuario_id,
            'salida',
            (salida_item->>'cantidad')::integer,
            p_motivo,
            (salida_item->>'condicion')::text
        );
    END LOOP;

END;
$$;


ALTER FUNCTION "public"."registrar_salida_manual"("p_usuario_id" "uuid", "p_motivo" "text", "p_salidas" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_products_pos"("p_query" "text") RETURNS TABLE("id" "uuid", "maestro_id" "uuid", "nombre_producto" "text", "codigo_barra" "text", "precio_venta" numeric, "stock_actual" integer, "numero_lote" "text", "fecha_vencimiento" "date", "es_presentacion" boolean, "nombre_presentacion" "text", "factor_conversion" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  /* 
    Caso 1: Coincidencia Directa con Producto Unitario (o búsqueda por nombre)
    Buscamos en la tabla de lotes (productos) y unimos con maestro.
  */
  SELECT 
    p.id,
    mp.id as maestro_id,
    mp.nombre as nombre_producto,
    mp.codigo_barra,
    mp.precio_venta,
    p.stock_actual,
    p.numero_lote,
    p.fecha_vencimiento,
    false as es_presentacion,
    NULL::text as nombre_presentacion,
    1.0 as factor_conversion
  FROM public.productos p
  JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
  WHERE 
    p.stock_actual > 0 
    AND (
      mp.codigo_barra ILIKE p_query 
      OR mp.nombre ILIKE '%' || p_query || '%'
    )

  UNION ALL

  /* 
    Caso 2: Coincidencia con Presentación (Caja/Pack)
    Buscamos si el query coincide con un código de presentación.
  */
  SELECT 
    p.id,
    mp.id as maestro_id,
    mp.nombre as nombre_producto,
    pp.codigo_barra, -- Devolvemos el código de la presentación escaneada
    COALESCE(pp.precio_venta, mp.precio_venta * pp.factor_conversion) as precio_venta, -- Precio específico o calculado
    p.stock_actual, -- Mostramos stock real en unidades base
    p.numero_lote,
    p.fecha_vencimiento,
    true as es_presentacion,
    pp.nombre_presentacion,
    pp.factor_conversion
  FROM public.productos p
  JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
  JOIN public.producto_presentaciones pp ON mp.id = pp.maestro_producto_id
  WHERE 
    p.stock_actual > 0 
    AND pp.codigo_barra ILIKE p_query;

END;
$$;


ALTER FUNCTION "public"."search_products_pos"("p_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_stock_disponible integer;
BEGIN
    -- Check current stock for the given condition, ignoring case
    SELECT COALESCE(SUM(CASE WHEN tipo_movimiento = 'entrada' THEN cantidad ELSE -cantidad END), 0)
    INTO v_stock_disponible
    FROM movimientos
    WHERE producto_id = p_producto_id AND LOWER(condicion) = LOWER(p_condicion_origen);

    -- Verify if there is enough stock to move
    IF v_stock_disponible < p_cantidad_a_mover THEN
        RAISE EXCEPTION 'No hay suficiente stock en la condición % para mover. Stock disponible: %', p_condicion_origen, v_stock_disponible;
    END IF;

    -- Create a movement to "remove" stock from the source condition
    INSERT INTO movimientos (producto_id, tipo_movimiento, cantidad, creado_en, condicion)
    VALUES (p_producto_id, 'salida', p_cantidad_a_mover, NOW(), p_condicion_origen);

    -- Create a movement to "add" stock to the destination condition
    INSERT INTO movimientos (producto_id, tipo_movimiento, cantidad, creado_en, condicion)
    VALUES (p_producto_id, 'entrada', p_cantidad_a_mover, NOW(), p_condicion_destino);
END;
$$;


ALTER FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text", "p_usuario_id" "uuid", "p_motivo" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_stock_disponible integer;
    v_condicion_origen_norm text;
    v_condicion_destino_norm text;
BEGIN
    -- Normalizar condiciones (Capitalizar primera letra)
    v_condicion_origen_norm := initcap(trim(p_condicion_origen));
    v_condicion_destino_norm := initcap(trim(p_condicion_destino));

    -- Validar motivo si sale de Bueno
    IF v_condicion_origen_norm = 'Bueno' AND v_condicion_destino_norm != 'Bueno' AND (p_motivo IS NULL OR TRIM(p_motivo) = '') THEN
        RAISE EXCEPTION 'Se requiere una observación para mover stock desde la condición Bueno.';
    END IF;

    -- Verificar Stock Disponible (Case Insensitive comparison for safety)
    SELECT COALESCE(SUM(CASE WHEN tipo_movimiento = 'entrada' THEN cantidad ELSE -cantidad END), 0)
    INTO v_stock_disponible
    FROM movimientos
    WHERE producto_id = p_producto_id 
    AND LOWER(condicion) = LOWER(v_condicion_origen_norm);

    -- Validación
    IF v_stock_disponible < p_cantidad_a_mover THEN
        RAISE EXCEPTION 'No hay suficiente stock en la condición % para mover. Stock disponible: %', v_condicion_origen_norm, v_stock_disponible;
    END IF;

    -- 1. Registrar SALIDA de la condición origen
    INSERT INTO movimientos (producto_id, tipo_movimiento, cantidad, creado_en, condicion, usuario_id, motivo)
    VALUES (p_producto_id, 'salida', p_cantidad_a_mover, NOW(), v_condicion_origen_norm, p_usuario_id, p_motivo);

    -- 2. Registrar ENTRADA a la condición destino (Aquí se crea el nuevo "bucket" de stock)
    INSERT INTO movimientos (producto_id, tipo_movimiento, cantidad, creado_en, condicion, usuario_id, motivo)
    VALUES (p_producto_id, 'entrada', p_cantidad_a_mover, NOW(), v_condicion_destino_norm, p_usuario_id, p_motivo);

    -- 3. Actualizar Stock VISIBLE (Para el POS)
    -- Si sacamos de 'Bueno', restamos del stock_actual del producto principal
    IF v_condicion_origen_norm = 'Bueno' AND v_condicion_destino_norm != 'Bueno' THEN
        UPDATE productos 
        SET stock_actual = stock_actual - p_cantidad_a_mover
        WHERE id = p_producto_id;
    END IF;

    -- Si devolvemos a 'Bueno', sumamos al stock_actual
    IF v_condicion_origen_norm != 'Bueno' AND v_condicion_destino_norm = 'Bueno' THEN
        UPDATE productos 
        SET stock_actual = stock_actual + p_cantidad_a_mover
        WHERE id = p_producto_id;
    END IF;

END;
$$;


ALTER FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text", "p_usuario_id" "uuid", "p_motivo" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."auditoria_preguntas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auditoria_id" "uuid" NOT NULL,
    "pregunta_id" "text" NOT NULL,
    "respuesta" "text" NOT NULL,
    "plan_accion" "text",
    "evidencia_url" "text"
);


ALTER TABLE "public"."auditoria_preguntas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."auditorias_checklist" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tipo_checklist" "text" NOT NULL,
    "fecha_auditoria" timestamp with time zone DEFAULT "now"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "porcentaje_completado" integer NOT NULL,
    "total_hallazgos" integer NOT NULL,
    "observaciones_generales" "text"
);


ALTER TABLE "public"."auditorias_checklist" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cajas" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "nombre" "text" NOT NULL,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."cajas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categorias" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."categorias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rut" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "direccion" "text",
    "telefono" "text",
    "cupo_credito" numeric(10,2) DEFAULT 70000.00,
    "saldo_actual" numeric(10,2) DEFAULT 0.00,
    "activo" boolean DEFAULT true,
    "creado_en" timestamp with time zone DEFAULT "now"(),
    "actualizado_en" timestamp with time zone DEFAULT "now"(),
    "giro" "text",
    "es_empresa" boolean DEFAULT false,
    "comuna" "text"
);


ALTER TABLE "public"."clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."configuracion" (
    "key" "text" NOT NULL,
    "value" "text" NOT NULL
);


ALTER TABLE "public"."configuracion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."detalle_ordenes_compra" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "orden_id" "uuid",
    "maestro_producto_id" "uuid",
    "cantidad_solicitada" integer NOT NULL,
    "costo_unitario" numeric(10,2) DEFAULT 0,
    "cantidad_recibida" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "detalle_ordenes_compra_cantidad_solicitada_check" CHECK (("cantidad_solicitada" > 0))
);


ALTER TABLE "public"."detalle_ordenes_compra" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."detalle_recepcion" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "recepcion_id" "uuid",
    "maestro_producto_id" "uuid",
    "cantidad" numeric(12,2) NOT NULL,
    "precio_costo_unitario" numeric(12,2),
    "numero_lote" "text",
    "fecha_vencimiento" "date",
    "condicion" "text" DEFAULT 'Bueno'::"text"
);


ALTER TABLE "public"."detalle_recepcion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."detalle_ventas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venta_id" "uuid",
    "producto_id" "uuid",
    "cantidad" integer NOT NULL,
    "precio_unitario" numeric(10,2) NOT NULL,
    "subtotal" numeric(10,2) NOT NULL,
    "creado_en" timestamp with time zone DEFAULT "now"(),
    "factor_conversion" numeric DEFAULT 1
);


ALTER TABLE "public"."detalle_ventas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entregas" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "mes_entrega" "text" NOT NULL,
    "paciente_id" "uuid" NOT NULL,
    "indicaciones_medicas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."entregas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entregas_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "entrega_id" "uuid" NOT NULL,
    "maestro_producto_id" "uuid",
    "medicamento" "text" NOT NULL,
    "cantidad" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."entregas_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_counts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid",
    "maestro_producto_id" "uuid",
    "codigo_escaneado" "text",
    "cantidad_escaneada" numeric NOT NULL,
    "factor_conversion" numeric DEFAULT 1,
    "cantidad_total" numeric GENERATED ALWAYS AS (("cantidad_escaneada" * "factor_conversion")) STORED,
    "usuario_id" "uuid",
    "registrado_en" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_counts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_session_results" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid",
    "maestro_producto_id" "uuid",
    "nombre_producto" "text",
    "stock_sistema_snapshot" numeric,
    "stock_fisico_final" numeric,
    "diferencia" numeric,
    "valor_ajuste" numeric,
    "ajustado_en" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_session_results" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "estado" "public"."session_status" DEFAULT 'OPEN'::"public"."session_status",
    "observaciones" "text",
    "creado_por" "uuid",
    "fecha_inicio" timestamp with time zone DEFAULT "now"(),
    "fecha_cierre" timestamp with time zone,
    "creado_en" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."items_venta" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venta_id" "uuid" NOT NULL,
    "producto_id" "uuid" NOT NULL,
    "cantidad" integer NOT NULL,
    "precio" numeric NOT NULL,
    CONSTRAINT "items_venta_cantidad_check" CHECK (("cantidad" > 0)),
    CONSTRAINT "items_venta_precio_check" CHECK (("precio" >= (0)::numeric))
);


ALTER TABLE "public"."items_venta" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."maestro_productos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "categoria" "text" NOT NULL,
    "descripcion" "text",
    "stock_critico" integer DEFAULT 5 NOT NULL,
    "creado_en" timestamp with time zone DEFAULT "now"(),
    "actualizado_en" timestamp with time zone DEFAULT "now"(),
    "codigo_barra" "text",
    "precio_venta" numeric(10,2) DEFAULT 0,
    "unidad_medida" "text" DEFAULT 'UN'::"text"
);


ALTER TABLE "public"."maestro_productos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."movimientos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "producto_id" "uuid",
    "usuario_id" "uuid",
    "tipo_movimiento" "text" NOT NULL,
    "cantidad" integer NOT NULL,
    "motivo" "text",
    "rut_paciente" "text",
    "nombre_paciente" "text",
    "creado_en" timestamp with time zone DEFAULT "now"(),
    "numero_guia" "text",
    "condicion" "text" DEFAULT 'Bueno'::"text",
    "origen_destino" "text" DEFAULT 'Sistema'::"text"
);


ALTER TABLE "public"."movimientos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."movimientos_caja" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "sesion_id" "uuid",
    "tipo_movimiento" "text",
    "monto" numeric(12,2) NOT NULL,
    "descripcion" "text",
    "referencia_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "movimientos_caja_tipo_movimiento_check" CHECK (("tipo_movimiento" = ANY (ARRAY['VENTA_EFECTIVO'::"text", 'APERTURA'::"text", 'GASTO'::"text", 'RETIRO'::"text", 'OTROS'::"text"])))
);


ALTER TABLE "public"."movimientos_caja" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."movimientos_cuenta_corriente" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "venta_id" "uuid",
    "fecha" timestamp with time zone DEFAULT "now"(),
    "tipo" "public"."tipo_movimiento_cc" NOT NULL,
    "monto" numeric(10,2) NOT NULL,
    "saldo_posterior" numeric(10,2) NOT NULL,
    "descripcion" "text",
    "usuario_id" "uuid",
    "creado_en" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."movimientos_cuenta_corriente" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."movimientos_stock" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "fecha_creacion" timestamp with time zone DEFAULT "now"() NOT NULL,
    "producto_id" "uuid" NOT NULL,
    "usuario_id" "uuid",
    "cantidad" integer NOT NULL,
    "tipo" "text" NOT NULL,
    "nota" "text"
);


ALTER TABLE "public"."movimientos_stock" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ordenes_compra" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "folio" integer NOT NULL,
    "proveedor_id" "uuid",
    "usuario_id" "uuid",
    "estado" "text" DEFAULT 'BORRADOR'::"text",
    "fecha_creacion" timestamp with time zone DEFAULT "now"(),
    "fecha_emision" timestamp with time zone,
    "fecha_recepcion_final" timestamp with time zone,
    "total_estimado" numeric(12,2) DEFAULT 0,
    "observaciones" "text",
    CONSTRAINT "ordenes_compra_estado_check" CHECK (("estado" = ANY (ARRAY['BORRADOR'::"text", 'EMITIDA'::"text", 'RECEPCION_PARCIAL'::"text", 'COMPLETADA'::"text", 'CANCELADA'::"text"])))
);


ALTER TABLE "public"."ordenes_compra" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."ordenes_compra_folio_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."ordenes_compra_folio_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."ordenes_compra_folio_seq" OWNED BY "public"."ordenes_compra"."folio";



CREATE TABLE IF NOT EXISTS "public"."pacientes" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "rut" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."pacientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."producto_presentaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "maestro_producto_id" "uuid" NOT NULL,
    "codigo_barra" "text" NOT NULL,
    "nombre_presentacion" "text" NOT NULL,
    "factor_conversion" numeric DEFAULT 1 NOT NULL,
    "costo_referencial" numeric,
    "precio_venta" numeric,
    "creado_en" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."producto_presentaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."productos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "maestro_producto_id" "uuid" NOT NULL,
    "stock_actual" integer NOT NULL,
    "numero_lote" "text",
    "fecha_vencimiento" "date",
    "condicion" "text" DEFAULT 'bueno'::"text",
    "observaciones" "text",
    "bloqueado" boolean DEFAULT false,
    "fecha_ingreso" timestamp with time zone DEFAULT "now"(),
    "creado_en" timestamp with time zone DEFAULT "now"(),
    "actualizado_en" timestamp with time zone DEFAULT "now"(),
    "proveedor_id" "uuid",
    "ubicacion" "text" DEFAULT 'Bodega General'::"text"
);


ALTER TABLE "public"."productos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."proveedores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "direccion" "text",
    "clasificacion" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "rut" "text",
    "contacto" "text",
    "telefono" "text",
    "email" "text"
);


ALTER TABLE "public"."proveedores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."recepciones" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "numero_documento" "text" NOT NULL,
    "tipo_documento" "text",
    "proveedor_id" "uuid",
    "fecha_recepcion" timestamp with time zone DEFAULT "now"(),
    "usuario_id" "uuid",
    "total_neto" numeric(12,2) DEFAULT 0,
    "estado" "text" DEFAULT 'COMPLETADO'::"text",
    "observaciones" "text",
    CONSTRAINT "recepciones_tipo_documento_check" CHECK (("tipo_documento" = ANY (ARRAY['FACTURA'::"text", 'GUIA'::"text", 'BOLETA'::"text"])))
);


ALTER TABLE "public"."recepciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sesiones_caja" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "usuario_id" "uuid",
    "fecha_apertura" timestamp with time zone DEFAULT "now"(),
    "fecha_cierre" timestamp with time zone,
    "monto_inicial" numeric(12,2) DEFAULT 0,
    "monto_final_declarado" numeric(12,2),
    "monto_final_esperado" numeric(12,2),
    "diferencia" numeric(12,2),
    "estado" "text" DEFAULT 'ABIERTA'::"text",
    "observaciones" "text",
    "caja_id" "uuid",
    "nombre_cajera_cierre" "text",
    CONSTRAINT "sesiones_caja_estado_check" CHECK (("estado" = ANY (ARRAY['ABIERTA'::"text", 'CERRADA'::"text"])))
);


ALTER TABLE "public"."sesiones_caja" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "name" "text",
    "role" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "fecha_creacion" timestamp with time zone DEFAULT "now"() NOT NULL,
    "usuario_id" "uuid",
    "total" numeric NOT NULL,
    "cliente_id" "uuid",
    "creado_en" timestamp with time zone DEFAULT "now"(),
    "tipo_venta" "public"."tipo_venta",
    CONSTRAINT "ventas_total_check" CHECK (("total" > (0)::numeric))
);


ALTER TABLE "public"."ventas" OWNER TO "postgres";


ALTER TABLE ONLY "public"."ordenes_compra" ALTER COLUMN "folio" SET DEFAULT "nextval"('"public"."ordenes_compra_folio_seq"'::"regclass");



ALTER TABLE ONLY "public"."auditoria_preguntas"
    ADD CONSTRAINT "auditoria_preguntas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."auditorias_checklist"
    ADD CONSTRAINT "auditorias_checklist_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cajas"
    ADD CONSTRAINT "cajas_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."cajas"
    ADD CONSTRAINT "cajas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categorias"
    ADD CONSTRAINT "categorias_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."categorias"
    ADD CONSTRAINT "categorias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clientes"
    ADD CONSTRAINT "clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clientes"
    ADD CONSTRAINT "clientes_rut_key" UNIQUE ("rut");



ALTER TABLE ONLY "public"."configuracion"
    ADD CONSTRAINT "configuracion_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."detalle_ordenes_compra"
    ADD CONSTRAINT "detalle_ordenes_compra_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."detalle_recepcion"
    ADD CONSTRAINT "detalle_recepcion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."detalle_ventas"
    ADD CONSTRAINT "detalle_ventas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entregas_items"
    ADD CONSTRAINT "entregas_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entregas"
    ADD CONSTRAINT "entregas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_counts"
    ADD CONSTRAINT "inventory_counts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_session_results"
    ADD CONSTRAINT "inventory_session_results_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory_sessions"
    ADD CONSTRAINT "inventory_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."items_venta"
    ADD CONSTRAINT "items_venta_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."maestro_productos"
    ADD CONSTRAINT "maestro_productos_codigo_barra_key" UNIQUE ("codigo_barra");



ALTER TABLE ONLY "public"."maestro_productos"
    ADD CONSTRAINT "maestro_productos_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."maestro_productos"
    ADD CONSTRAINT "maestro_productos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."movimientos_caja"
    ADD CONSTRAINT "movimientos_caja_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."movimientos_cuenta_corriente"
    ADD CONSTRAINT "movimientos_cuenta_corriente_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."movimientos"
    ADD CONSTRAINT "movimientos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."movimientos_stock"
    ADD CONSTRAINT "movimientos_stock_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ordenes_compra"
    ADD CONSTRAINT "ordenes_compra_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pacientes"
    ADD CONSTRAINT "pacientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pacientes"
    ADD CONSTRAINT "pacientes_rut_key" UNIQUE ("rut");



ALTER TABLE ONLY "public"."producto_presentaciones"
    ADD CONSTRAINT "producto_presentaciones_codigo_barra_key" UNIQUE ("codigo_barra");



ALTER TABLE ONLY "public"."producto_presentaciones"
    ADD CONSTRAINT "producto_presentaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."productos"
    ADD CONSTRAINT "productos_pkey1" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."proveedores"
    ADD CONSTRAINT "proveedores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."proveedores"
    ADD CONSTRAINT "proveedores_rut_key" UNIQUE ("rut");



ALTER TABLE ONLY "public"."recepciones"
    ADD CONSTRAINT "recepciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sesiones_caja"
    ADD CONSTRAINT "sesiones_caja_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."productos"
    ADD CONSTRAINT "unique_numero_lote_condicion" UNIQUE ("numero_lote", "condicion");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas"
    ADD CONSTRAINT "ventas_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_detalle_oc_orden" ON "public"."detalle_ordenes_compra" USING "btree" ("orden_id");



CREATE INDEX "idx_entregas_items_maestro_producto_id" ON "public"."entregas_items" USING "btree" ("maestro_producto_id");



CREATE INDEX "idx_movimientos_sesion" ON "public"."movimientos_caja" USING "btree" ("sesion_id");



CREATE INDEX "idx_ordenes_compra_estado" ON "public"."ordenes_compra" USING "btree" ("estado");



CREATE INDEX "idx_ordenes_compra_proveedor" ON "public"."ordenes_compra" USING "btree" ("proveedor_id");



CREATE INDEX "idx_producto_presentaciones_codigo" ON "public"."producto_presentaciones" USING "btree" ("codigo_barra");



CREATE INDEX "idx_producto_presentaciones_producto" ON "public"."producto_presentaciones" USING "btree" ("maestro_producto_id");



CREATE INDEX "idx_sesiones_estado" ON "public"."sesiones_caja" USING "btree" ("estado");



CREATE INDEX "idx_sesiones_usuario" ON "public"."sesiones_caja" USING "btree" ("usuario_id");



ALTER TABLE ONLY "public"."auditoria_preguntas"
    ADD CONSTRAINT "auditoria_preguntas_auditoria_id_fkey" FOREIGN KEY ("auditoria_id") REFERENCES "public"."auditorias_checklist"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."auditorias_checklist"
    ADD CONSTRAINT "auditorias_checklist_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."detalle_ordenes_compra"
    ADD CONSTRAINT "detalle_ordenes_compra_maestro_producto_id_fkey" FOREIGN KEY ("maestro_producto_id") REFERENCES "public"."maestro_productos"("id");



ALTER TABLE ONLY "public"."detalle_ordenes_compra"
    ADD CONSTRAINT "detalle_ordenes_compra_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."ordenes_compra"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."detalle_recepcion"
    ADD CONSTRAINT "detalle_recepcion_maestro_producto_id_fkey" FOREIGN KEY ("maestro_producto_id") REFERENCES "public"."maestro_productos"("id");



ALTER TABLE ONLY "public"."detalle_recepcion"
    ADD CONSTRAINT "detalle_recepcion_recepcion_id_fkey" FOREIGN KEY ("recepcion_id") REFERENCES "public"."recepciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."detalle_ventas"
    ADD CONSTRAINT "detalle_ventas_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."productos"("id");



ALTER TABLE ONLY "public"."detalle_ventas"
    ADD CONSTRAINT "detalle_ventas_venta_id_fkey" FOREIGN KEY ("venta_id") REFERENCES "public"."ventas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entregas_items"
    ADD CONSTRAINT "entregas_items_entrega_id_fkey" FOREIGN KEY ("entrega_id") REFERENCES "public"."entregas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entregas_items"
    ADD CONSTRAINT "entregas_items_maestro_producto_id_fkey" FOREIGN KEY ("maestro_producto_id") REFERENCES "public"."maestro_productos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."entregas"
    ADD CONSTRAINT "entregas_paciente_id_fkey" FOREIGN KEY ("paciente_id") REFERENCES "public"."pacientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."productos"
    ADD CONSTRAINT "fk_proveedor" FOREIGN KEY ("proveedor_id") REFERENCES "public"."proveedores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inventory_counts"
    ADD CONSTRAINT "inventory_counts_maestro_producto_id_fkey" FOREIGN KEY ("maestro_producto_id") REFERENCES "public"."maestro_productos"("id");



ALTER TABLE ONLY "public"."inventory_counts"
    ADD CONSTRAINT "inventory_counts_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."inventory_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_counts"
    ADD CONSTRAINT "inventory_counts_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."inventory_session_results"
    ADD CONSTRAINT "inventory_session_results_maestro_producto_id_fkey" FOREIGN KEY ("maestro_producto_id") REFERENCES "public"."maestro_productos"("id");



ALTER TABLE ONLY "public"."inventory_session_results"
    ADD CONSTRAINT "inventory_session_results_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."inventory_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_sessions"
    ADD CONSTRAINT "inventory_sessions_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."items_venta"
    ADD CONSTRAINT "items_venta_venta_id_fkey" FOREIGN KEY ("venta_id") REFERENCES "public"."ventas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."movimientos_caja"
    ADD CONSTRAINT "movimientos_caja_sesion_id_fkey" FOREIGN KEY ("sesion_id") REFERENCES "public"."sesiones_caja"("id");



ALTER TABLE ONLY "public"."movimientos_cuenta_corriente"
    ADD CONSTRAINT "movimientos_cuenta_corriente_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."movimientos_cuenta_corriente"
    ADD CONSTRAINT "movimientos_cuenta_corriente_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."movimientos_cuenta_corriente"
    ADD CONSTRAINT "movimientos_cuenta_corriente_venta_id_fkey" FOREIGN KEY ("venta_id") REFERENCES "public"."ventas"("id");



ALTER TABLE ONLY "public"."movimientos"
    ADD CONSTRAINT "movimientos_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."productos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."movimientos_stock"
    ADD CONSTRAINT "movimientos_stock_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."movimientos"
    ADD CONSTRAINT "movimientos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ordenes_compra"
    ADD CONSTRAINT "ordenes_compra_proveedor_id_fkey" FOREIGN KEY ("proveedor_id") REFERENCES "public"."proveedores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ordenes_compra"
    ADD CONSTRAINT "ordenes_compra_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."producto_presentaciones"
    ADD CONSTRAINT "producto_presentaciones_maestro_producto_id_fkey" FOREIGN KEY ("maestro_producto_id") REFERENCES "public"."maestro_productos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."productos"
    ADD CONSTRAINT "productos_maestro_producto_id_fkey" FOREIGN KEY ("maestro_producto_id") REFERENCES "public"."maestro_productos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recepciones"
    ADD CONSTRAINT "recepciones_proveedor_id_fkey" FOREIGN KEY ("proveedor_id") REFERENCES "public"."proveedores"("id");



ALTER TABLE ONLY "public"."recepciones"
    ADD CONSTRAINT "recepciones_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."sesiones_caja"
    ADD CONSTRAINT "sesiones_caja_caja_id_fkey" FOREIGN KEY ("caja_id") REFERENCES "public"."cajas"("id");



ALTER TABLE ONLY "public"."sesiones_caja"
    ADD CONSTRAINT "sesiones_caja_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas"
    ADD CONSTRAINT "ventas_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id");



ALTER TABLE ONLY "public"."ventas"
    ADD CONSTRAINT "ventas_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "auth"."users"("id");



CREATE POLICY "Accesible para usuarios autenticados" ON "public"."detalle_ordenes_compra" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Accesible para usuarios autenticados" ON "public"."ordenes_compra" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Admin y Bodega gestionan conteos" ON "public"."inventory_counts" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Admin y Bodega ven resultados" ON "public"."inventory_session_results" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Admin y Bodega ven sesiones" ON "public"."inventory_sessions" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Allow admin and bodega to manage providers" ON "public"."proveedores" USING (("public"."is_admin"() OR (( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = 'bodega'::"text"))) WITH CHECK (("public"."is_admin"() OR (( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = 'bodega'::"text")));



CREATE POLICY "Allow admin to manage all users" ON "public"."users" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());



CREATE POLICY "Allow authenticated users to delete deliveries" ON "public"."entregas" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to delete delivery items" ON "public"."entregas_items" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to delete patients" ON "public"."pacientes" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to insert deliveries" ON "public"."entregas" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to insert delivery items" ON "public"."entregas_items" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to insert movements via function" ON "public"."movimientos" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to insert patients" ON "public"."pacientes" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to read auditoria_preguntas" ON "public"."auditoria_preguntas" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to read auditorias_checklist" ON "public"."auditorias_checklist" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to read providers" ON "public"."proveedores" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to update deliveries" ON "public"."entregas" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated users to update delivery items" ON "public"."entregas_items" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated users to update patients" ON "public"."pacientes" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated users to view all deliveries" ON "public"."entregas" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to view all delivery items" ON "public"."entregas_items" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to view all patients" ON "public"."pacientes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to view all users" ON "public"."users" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authorized roles to delete auditoria_preguntas" ON "public"."auditoria_preguntas" FOR DELETE TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Allow authorized roles to delete auditorias_checklist" ON "public"."auditorias_checklist" FOR DELETE TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Allow authorized roles to insert auditoria_preguntas" ON "public"."auditoria_preguntas" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text", 'enfermero'::"text"])));



CREATE POLICY "Allow authorized roles to insert auditorias_checklist" ON "public"."auditorias_checklist" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text", 'enfermero'::"text"])));



CREATE POLICY "Allow authorized roles to update auditoria_preguntas" ON "public"."auditoria_preguntas" FOR UPDATE TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Allow authorized roles to update auditorias_checklist" ON "public"."auditorias_checklist" FOR UPDATE TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Enable all access for authenticated users" ON "public"."detalle_recepcion" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Enable all access for authenticated users" ON "public"."recepciones" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Gestion presentaciones admin y bodega" ON "public"."producto_presentaciones" TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"]))) WITH CHECK ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Lectura presentaciones usuarios autenticados" ON "public"."producto_presentaciones" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Los usuarios autenticados pueden gestionar el stock" ON "public"."movimientos_stock" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Los usuarios pueden crear ventas" ON "public"."ventas" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Los usuarios pueden gestionar los items de sus ventas" ON "public"."items_venta" TO "authenticated" USING (("venta_id" IN ( SELECT "ventas"."id"
   FROM "public"."ventas"
  WHERE ("ventas"."usuario_id" = "auth"."uid"()))));



CREATE POLICY "Los usuarios pueden ver sus propias ventas" ON "public"."ventas" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Permitir actualizacion a admin" ON "public"."movimientos" FOR UPDATE TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = 'admin'::"text"));



CREATE POLICY "Permitir eliminacion a admin" ON "public"."movimientos" FOR DELETE TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = 'admin'::"text"));



CREATE POLICY "Permitir gestion a admin y bodega" ON "public"."maestro_productos" TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"]))) WITH CHECK ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Permitir gestion a admin y bodega" ON "public"."productos" TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"]))) WITH CHECK ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Permitir gestion a admin y bodega" ON "public"."proveedores" TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"]))) WITH CHECK ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text"])));



CREATE POLICY "Permitir gestion a admin/bodega" ON "public"."categorias" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Permitir gestion a roles autorizados" ON "public"."entregas_items" TO "authenticated" USING ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text", 'enfermero'::"text"]))) WITH CHECK ((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text", 'enfermero'::"text"])));



CREATE POLICY "Permitir insercion a roles autorizados" ON "public"."movimientos" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "users"."role"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())) = ANY (ARRAY['admin'::"text", 'bodega'::"text", 'enfermero'::"text"])) AND ("usuario_id" = "auth"."uid"())));



CREATE POLICY "Permitir lectura a autenticados" ON "public"."categorias" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Permitir lectura a autenticados" ON "public"."proveedores" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Permitir lectura a usuarios autenticados" ON "public"."entregas_items" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Permitir lectura a usuarios autenticados" ON "public"."maestro_productos" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Permitir lectura a usuarios autenticados" ON "public"."movimientos" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Permitir lectura a usuarios autenticados" ON "public"."productos" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Permitir lectura de cajas a autenticados" ON "public"."cajas" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Permitir todo a autenticados" ON "public"."clientes" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir todo a autenticados" ON "public"."detalle_ventas" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir todo a autenticados" ON "public"."movimientos_cuenta_corriente" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir todo a autenticados" ON "public"."ventas" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Ver movimientos propios o admin" ON "public"."movimientos_caja" USING ((("sesion_id" IN ( SELECT "sesiones_caja"."id"
   FROM "public"."sesiones_caja"
  WHERE ("sesiones_caja"."usuario_id" = "auth"."uid"()))) OR ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Ver sesiones propias o admin" ON "public"."sesiones_caja" USING ((("auth"."uid"() = "usuario_id") OR ("auth"."role"() = 'authenticated'::"text")));



ALTER TABLE "public"."auditoria_preguntas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."auditorias_checklist" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cajas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categorias" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clientes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."detalle_ordenes_compra" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."detalle_recepcion" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."detalle_ventas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."entregas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."entregas_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_counts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_session_results" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."items_venta" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."maestro_productos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."movimientos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."movimientos_caja" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."movimientos_cuenta_corriente" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."movimientos_stock" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ordenes_compra" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pacientes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."producto_presentaciones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."productos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."proveedores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."recepciones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sesiones_caja" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ventas" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."abrir_caja"("p_usuario_id" "uuid", "p_monto_inicial" numeric, "p_caja_id" "uuid", "p_codigo_auth" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."abrir_caja"("p_usuario_id" "uuid", "p_monto_inicial" numeric, "p_caja_id" "uuid", "p_codigo_auth" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."abrir_caja"("p_usuario_id" "uuid", "p_monto_inicial" numeric, "p_caja_id" "uuid", "p_codigo_auth" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_clave_maestra"("p_actual_codigo" "text", "p_nuevo_codigo" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_clave_maestra"("p_actual_codigo" "text", "p_nuevo_codigo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_clave_maestra"("p_actual_codigo" "text", "p_nuevo_codigo" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_stock"("p_product_id" "uuid", "p_qty" integer, "p_note" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_stock"("p_product_id" "uuid", "p_qty" integer, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_stock"("p_product_id" "uuid", "p_qty" integer, "p_note" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."agregar_stock"("p_producto_id" "uuid", "p_cantidad" integer, "p_nota" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."agregar_stock"("p_producto_id" "uuid", "p_cantidad" integer, "p_nota" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."agregar_stock"("p_producto_id" "uuid", "p_cantidad" integer, "p_nota" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."analizar_diferencias_inventario"("p_session_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."analizar_diferencias_inventario"("p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."analizar_diferencias_inventario"("p_session_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."aplicar_ajuste_inventario"("p_session_id" "uuid", "p_usuario_id" "uuid", "p_maestro_producto_id" "uuid", "p_motivo" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."aplicar_ajuste_inventario"("p_session_id" "uuid", "p_usuario_id" "uuid", "p_maestro_producto_id" "uuid", "p_motivo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."aplicar_ajuste_inventario"("p_session_id" "uuid", "p_usuario_id" "uuid", "p_maestro_producto_id" "uuid", "p_motivo" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."cerrar_caja"("p_sesion_id" "uuid", "p_monto_declarado" numeric, "p_codigo_auth" "text", "p_nombre_cajera" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."cerrar_caja"("p_sesion_id" "uuid", "p_monto_declarado" numeric, "p_codigo_auth" "text", "p_nombre_cajera" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cerrar_caja"("p_sesion_id" "uuid", "p_monto_declarado" numeric, "p_codigo_auth" "text", "p_nombre_cajera" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_nueva_caja"("p_nombre" "text", "p_codigo_auth" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."crear_nueva_caja"("p_nombre" "text", "p_codigo_auth" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_nueva_caja"("p_nombre" "text", "p_codigo_auth" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_venta"("p_items" json) TO "anon";
GRANT ALL ON FUNCTION "public"."crear_venta"("p_items" json) TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_venta"("p_items" json) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_sale"("p_items" json) TO "anon";
GRANT ALL ON FUNCTION "public"."create_sale"("p_items" json) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_sale"("p_items" json) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_critical_stock_products_list"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_critical_stock_products_list"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_critical_stock_products_list"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dashboard_stats"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_dashboard_stats"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dashboard_stats"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dispatch_lots"("param_maestro_producto_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dispatch_lots"("param_maestro_producto_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dispatch_lots"("param_maestro_producto_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_expiring_products_list"("days_threshold" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_expiring_products_list"("days_threshold" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_expiring_products_list"("days_threshold" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_inventory_stock"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_inventory_stock"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_inventory_stock"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_movement_history"("start_date" "date", "end_date" "date", "user_ids" "uuid"[], "movement_type" "text", "search_term" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_movement_history"("start_date" "date", "end_date" "date", "user_ids" "uuid"[], "movement_type" "text", "search_term" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_movement_history"("start_date" "date", "end_date" "date", "user_ids" "uuid"[], "movement_type" "text", "search_term" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_quarantine_products_list"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_quarantine_products_list"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_quarantine_products_list"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_todays_deliveries"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_todays_deliveries"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_todays_deliveries"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."procesar_recepcion_mercaderia"("p_numero_documento" "text", "p_tipo_documento" "text", "p_proveedor_id" "uuid", "p_usuario_id" "uuid", "p_detalles" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."procesar_recepcion_mercaderia"("p_numero_documento" "text", "p_tipo_documento" "text", "p_proveedor_id" "uuid", "p_usuario_id" "uuid", "p_detalles" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."procesar_recepcion_mercaderia"("p_numero_documento" "text", "p_tipo_documento" "text", "p_proveedor_id" "uuid", "p_usuario_id" "uuid", "p_detalles" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."procesar_venta"("p_cliente_id" "uuid", "p_tipo_venta" "text", "p_items" "jsonb", "p_usuario_id" "uuid", "p_force_credit" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."procesar_venta"("p_cliente_id" "uuid", "p_tipo_venta" "text", "p_items" "jsonb", "p_usuario_id" "uuid", "p_force_credit" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."procesar_venta"("p_cliente_id" "uuid", "p_tipo_venta" "text", "p_items" "jsonb", "p_usuario_id" "uuid", "p_force_credit" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."recepcionar_orden_compra"("p_orden_id" "uuid", "p_usuario_id" "uuid", "p_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."recepcionar_orden_compra"("p_orden_id" "uuid", "p_usuario_id" "uuid", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recepcionar_orden_compra"("p_orden_id" "uuid", "p_usuario_id" "uuid", "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."registrar_salida_manual"("p_usuario_id" "uuid", "p_motivo" "text", "p_salidas" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."registrar_salida_manual"("p_usuario_id" "uuid", "p_motivo" "text", "p_salidas" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."registrar_salida_manual"("p_usuario_id" "uuid", "p_motivo" "text", "p_salidas" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text", "p_usuario_id" "uuid", "p_motivo" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text", "p_usuario_id" "uuid", "p_motivo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."segregate_stock"("p_producto_id" "uuid", "p_cantidad_a_mover" integer, "p_condicion_origen" "text", "p_condicion_destino" "text", "p_usuario_id" "uuid", "p_motivo" "text") TO "service_role";


















GRANT ALL ON TABLE "public"."auditoria_preguntas" TO "anon";
GRANT ALL ON TABLE "public"."auditoria_preguntas" TO "authenticated";
GRANT ALL ON TABLE "public"."auditoria_preguntas" TO "service_role";



GRANT ALL ON TABLE "public"."auditorias_checklist" TO "anon";
GRANT ALL ON TABLE "public"."auditorias_checklist" TO "authenticated";
GRANT ALL ON TABLE "public"."auditorias_checklist" TO "service_role";



GRANT ALL ON TABLE "public"."cajas" TO "anon";
GRANT ALL ON TABLE "public"."cajas" TO "authenticated";
GRANT ALL ON TABLE "public"."cajas" TO "service_role";



GRANT ALL ON TABLE "public"."categorias" TO "anon";
GRANT ALL ON TABLE "public"."categorias" TO "authenticated";
GRANT ALL ON TABLE "public"."categorias" TO "service_role";



GRANT ALL ON TABLE "public"."clientes" TO "anon";
GRANT ALL ON TABLE "public"."clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."clientes" TO "service_role";



GRANT ALL ON TABLE "public"."configuracion" TO "anon";
GRANT ALL ON TABLE "public"."configuracion" TO "authenticated";
GRANT ALL ON TABLE "public"."configuracion" TO "service_role";



GRANT ALL ON TABLE "public"."detalle_ordenes_compra" TO "anon";
GRANT ALL ON TABLE "public"."detalle_ordenes_compra" TO "authenticated";
GRANT ALL ON TABLE "public"."detalle_ordenes_compra" TO "service_role";



GRANT ALL ON TABLE "public"."detalle_recepcion" TO "anon";
GRANT ALL ON TABLE "public"."detalle_recepcion" TO "authenticated";
GRANT ALL ON TABLE "public"."detalle_recepcion" TO "service_role";



GRANT ALL ON TABLE "public"."detalle_ventas" TO "anon";
GRANT ALL ON TABLE "public"."detalle_ventas" TO "authenticated";
GRANT ALL ON TABLE "public"."detalle_ventas" TO "service_role";



GRANT ALL ON TABLE "public"."entregas" TO "anon";
GRANT ALL ON TABLE "public"."entregas" TO "authenticated";
GRANT ALL ON TABLE "public"."entregas" TO "service_role";



GRANT ALL ON TABLE "public"."entregas_items" TO "anon";
GRANT ALL ON TABLE "public"."entregas_items" TO "authenticated";
GRANT ALL ON TABLE "public"."entregas_items" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_counts" TO "anon";
GRANT ALL ON TABLE "public"."inventory_counts" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_counts" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_session_results" TO "anon";
GRANT ALL ON TABLE "public"."inventory_session_results" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_session_results" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_sessions" TO "anon";
GRANT ALL ON TABLE "public"."inventory_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."items_venta" TO "anon";
GRANT ALL ON TABLE "public"."items_venta" TO "authenticated";
GRANT ALL ON TABLE "public"."items_venta" TO "service_role";



GRANT ALL ON TABLE "public"."maestro_productos" TO "anon";
GRANT ALL ON TABLE "public"."maestro_productos" TO "authenticated";
GRANT ALL ON TABLE "public"."maestro_productos" TO "service_role";



GRANT ALL ON TABLE "public"."movimientos" TO "anon";
GRANT ALL ON TABLE "public"."movimientos" TO "authenticated";
GRANT ALL ON TABLE "public"."movimientos" TO "service_role";



GRANT ALL ON TABLE "public"."movimientos_caja" TO "anon";
GRANT ALL ON TABLE "public"."movimientos_caja" TO "authenticated";
GRANT ALL ON TABLE "public"."movimientos_caja" TO "service_role";



GRANT ALL ON TABLE "public"."movimientos_cuenta_corriente" TO "anon";
GRANT ALL ON TABLE "public"."movimientos_cuenta_corriente" TO "authenticated";
GRANT ALL ON TABLE "public"."movimientos_cuenta_corriente" TO "service_role";



GRANT ALL ON TABLE "public"."movimientos_stock" TO "anon";
GRANT ALL ON TABLE "public"."movimientos_stock" TO "authenticated";
GRANT ALL ON TABLE "public"."movimientos_stock" TO "service_role";



GRANT ALL ON TABLE "public"."ordenes_compra" TO "anon";
GRANT ALL ON TABLE "public"."ordenes_compra" TO "authenticated";
GRANT ALL ON TABLE "public"."ordenes_compra" TO "service_role";



GRANT ALL ON SEQUENCE "public"."ordenes_compra_folio_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."ordenes_compra_folio_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."ordenes_compra_folio_seq" TO "service_role";



GRANT ALL ON TABLE "public"."pacientes" TO "anon";
GRANT ALL ON TABLE "public"."pacientes" TO "authenticated";
GRANT ALL ON TABLE "public"."pacientes" TO "service_role";



GRANT ALL ON TABLE "public"."producto_presentaciones" TO "anon";
GRANT ALL ON TABLE "public"."producto_presentaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."producto_presentaciones" TO "service_role";



GRANT ALL ON TABLE "public"."productos" TO "anon";
GRANT ALL ON TABLE "public"."productos" TO "authenticated";
GRANT ALL ON TABLE "public"."productos" TO "service_role";



GRANT ALL ON TABLE "public"."proveedores" TO "anon";
GRANT ALL ON TABLE "public"."proveedores" TO "authenticated";
GRANT ALL ON TABLE "public"."proveedores" TO "service_role";



GRANT ALL ON TABLE "public"."recepciones" TO "anon";
GRANT ALL ON TABLE "public"."recepciones" TO "authenticated";
GRANT ALL ON TABLE "public"."recepciones" TO "service_role";



GRANT ALL ON TABLE "public"."sesiones_caja" TO "anon";
GRANT ALL ON TABLE "public"."sesiones_caja" TO "authenticated";
GRANT ALL ON TABLE "public"."sesiones_caja" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."ventas" TO "anon";
GRANT ALL ON TABLE "public"."ventas" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































RESET ALL;
