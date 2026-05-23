-- EVOLUCIÓN: PRODUCTOS SIN CONTROL DE STOCK (Ej. Pan, Servicios)

-- 1. Agregar columna en maestro_productos
ALTER TABLE "public"."maestro_productos" ADD COLUMN IF NOT EXISTS "controla_stock" BOOLEAN DEFAULT TRUE;

-- 2. Asegurar que todos los productos existentes tengan un registro en la tabla productos para poder venderse
-- Aunque no tengan lote, necesitamos el ID para la relación en detalle_ventas.
INSERT INTO public.productos (maestro_producto_id, stock_actual, numero_lote, fecha_vencimiento, proveedor_id)
SELECT mp.id, 0, 'S/L', NULL, (SELECT id FROM public.proveedores LIMIT 1)
FROM public.maestro_productos mp
LEFT JOIN public.productos p ON p.maestro_producto_id = mp.id
WHERE p.id IS NULL;

-- 3. ACTUALIZACIÓN SEARCH POS: Mostrar productos sin stock si controla_stock es FALSE
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
    "factor_conversion" numeric,
    "controla_stock" boolean,
    "unidad_medida" "text"
)
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  /* Producto Unitario */
  SELECT 
    p.id, mp.id as maestro_id, mp.nombre as nombre_producto, mp.codigo_barra,
    mp.precio_venta, p.stock_actual::numeric, p.numero_lote, p.fecha_vencimiento,
    false as es_presentacion, NULL::text as nombre_presentacion, 1.0::numeric as factor_conversion,
    mp.controla_stock,
    mp.unidad_medida
  FROM public.productos p
  JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
  WHERE (mp.controla_stock = false OR p.stock_actual > 0)
    AND (
      mp.codigo_barra ILIKE p_query 
      OR mp.nombre ILIKE '%' || p_query || '%'
    )

  UNION ALL

  /* Packs/Presentaciones */
  SELECT 
    p.id, mp.id as maestro_id, mp.nombre as nombre_producto, pp.codigo_barra,
    COALESCE(pp.precio_venta, mp.precio_venta * pp.factor_conversion) as precio_venta, 
    p.stock_actual::numeric, p.numero_lote, p.fecha_vencimiento,
    true as es_presentacion, pp.nombre_presentacion, pp.factor_conversion::numeric,
    mp.controla_stock,
    mp.unidad_medida
  FROM public.productos p
  JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
  JOIN public.producto_presentaciones pp ON mp.id = pp.maestro_producto_id
  WHERE (mp.controla_stock = false OR p.stock_actual > 0)
    AND pp.codigo_barra ILIKE p_query;
END;
$$;

GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_products_pos"("p_query" "text") TO "service_role";

-- 4. ACTUALIZACIÓN PROCESAR VENTA: Saltar descuento de stock si controla_stock es false
CREATE OR REPLACE FUNCTION "public"."procesar_venta"(
    "p_cliente_id" "uuid", 
    "p_tipo_venta" "text", 
    "p_items" "jsonb", 
    "p_usuario_id" "uuid", 
    "p_force_credit" boolean DEFAULT false
) RETURNS "uuid"
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
    v_controla_stock boolean;
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

        -- Verificar si el producto controla stock
        SELECT mp.controla_stock INTO v_controla_stock
        FROM public.productos p
        JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
        WHERE p.id = v_producto_id FOR SHARE;

        IF COALESCE(v_controla_stock, true) THEN
            SELECT stock_actual INTO v_current_stock FROM public.productos WHERE id = v_producto_id FOR UPDATE;
            UPDATE public.productos SET stock_actual = stock_actual - v_cantidad_descontar WHERE id = v_producto_id;
            
            INSERT INTO public.movimientos (producto_id, tipo_movimiento, cantidad, motivo, usuario_id)
            VALUES (v_producto_id, 'VENTA', v_cantidad_descontar, 'Venta Folio: ' || v_venta_id::text, p_usuario_id);
        END IF;

        INSERT INTO public.detalle_ventas (venta_id, producto_id, cantidad, precio_unitario, subtotal, factor_conversion)
        VALUES (v_venta_id, v_producto_id, v_cantidad, v_precio, v_subtotal, v_factor);
    END LOOP;

    RETURN v_venta_id;
END;
$$;
