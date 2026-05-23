-- ============================================
-- MIGRACIÓN CONSOLIDADA: Sistema de Bodegas
-- Versión: 1.0.0
-- Fecha: 2026-05-14
-- ============================================
-- 
-- ARQUITECTURA:
--   [Recepción] → [Bodega General] → [Traslado] → [Bodega Venta] → [POS]
--
-- CAMBIOS:
--   - Tabla bodegas: almacena las bodegas del sistema
--   - Columna bodega_id en productos: cada lote pertenece a una bodega
--   - Tabla traslados: registro de movimientos entre bodegas
--   - Tabla traslado_items: detalle de productos trasladados
--   - RPC get_inventory_por_bodega: inventario filtrado por bodega
--   - RPC search_products_pos_bodega: búsqueda solo en bodega venta
--   - RPC crear_traslado: mueve stock entre bodegas
--   - RPC listar_traslados: historial de traslados
--   - RPC procesar_recepcion_mercaderia (actualizada): acepta bodega_id
--   - RLS desactivado en tablas nuevas
--
-- ROLES:
--   Admin     → ve Bodega General + Venta, puede trasladar, recibe en cualquiera
--   Cajero    → solo ve Bodega Venta, POS consume de ahí
-- ============================================

BEGIN;

-- ============================================
-- PARTE 1: TABLAS
-- ============================================

-- 1.1 Bodegas
CREATE TABLE IF NOT EXISTS public.bodegas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('general', 'venta')),
    empresa_id UUID REFERENCES public.empresas(id),
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.2 Agregar bodega_id a productos
ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS bodega_id UUID REFERENCES public.bodegas(id);

-- 1.3 Traslados
CREATE TABLE IF NOT EXISTS public.traslados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bodega_origen_id UUID NOT NULL REFERENCES public.bodegas(id),
    bodega_destino_id UUID NOT NULL REFERENCES public.bodegas(id),
    usuario_id UUID REFERENCES auth.users(id),
    estado TEXT DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'COMPLETADO', 'CANCELADO')),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    completado_at TIMESTAMPTZ
);

-- 1.4 Items de traslado
CREATE TABLE IF NOT EXISTS public.traslado_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    traslado_id UUID NOT NULL REFERENCES public.traslados(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES public.productos(id),
    cantidad NUMERIC(10,3) NOT NULL CHECK (cantidad > 0),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.5 Índices
CREATE INDEX IF NOT EXISTS idx_productos_bodega ON public.productos(bodega_id);
CREATE INDEX IF NOT EXISTS idx_traslados_origen ON public.traslados(bodega_origen_id);
CREATE INDEX IF NOT EXISTS idx_traslados_destino ON public.traslados(bodega_destino_id);
CREATE INDEX IF NOT EXISTS idx_traslado_items_traslado ON public.traslado_items(traslado_id);

-- ============================================
-- PARTE 2: RLS
-- ============================================
ALTER TABLE public.bodegas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.traslados DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.traslado_items DISABLE ROW LEVEL SECURITY;

-- ============================================
-- PARTE 3: DATOS INICIALES
-- ============================================
INSERT INTO public.bodegas (nombre, tipo) VALUES ('Bodega General', 'general') ON CONFLICT DO NOTHING;
INSERT INTO public.bodegas (nombre, tipo) VALUES ('Bodega de Venta', 'venta') ON CONFLICT DO NOTHING;

-- Asignar bodega general por defecto a productos existentes sin bodega
UPDATE public.productos SET bodega_id = (SELECT id FROM public.bodegas WHERE tipo = 'general' LIMIT 1)
WHERE bodega_id IS NULL;

-- ============================================
-- PARTE 4: RPCs
-- ============================================

-- 4.1 Inventario filtrado por bodega
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
    SELECT mp.id, p.id, mp.nombre, mp.codigo_barra, mp.precio_venta,
           p.stock_actual, p.numero_lote, p.fecha_vencimiento,
           COALESCE(mp.unidad_medida, 'UN'), COALESCE(mp.controla_stock, true),
           b.id, b.nombre
    FROM public.productos p
    JOIN public.maestro_productos mp ON mp.id = p.maestro_producto_id
    LEFT JOIN public.bodegas b ON b.id = p.bodega_id
    WHERE (p_bodega_id IS NULL OR p.bodega_id = p_bodega_id)
      AND p.stock_actual > 0
    ORDER BY mp.nombre, p.numero_lote;
END;
$$;

-- 4.2 Búsqueda POS (solo bodega venta)
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
    v_bodega_venta UUID;
BEGIN
    SELECT id INTO v_bodega_venta FROM public.bodegas WHERE tipo = 'venta' LIMIT 1;
    RETURN QUERY
    SELECT p.id, mp.nombre, mp.codigo_barra, mp.precio_venta,
           p.stock_actual, p.numero_lote, p.fecha_vencimiento,
           COALESCE(mp.unidad_medida, 'UN'), COALESCE(mp.controla_stock, true),
           1, false, NULL::TEXT
    FROM public.productos p
    JOIN public.maestro_productos mp ON mp.id = p.maestro_producto_id
    WHERE p.bodega_id = v_bodega_venta
      AND p.stock_actual > 0
      AND (p_query = '' OR mp.nombre ILIKE '%' || p_query || '%' OR mp.codigo_barra ILIKE '%' || p_query || '%')
    ORDER BY mp.nombre
    LIMIT 50;
END;
$$;

-- 4.3 Crear traslado entre bodegas
CREATE OR REPLACE FUNCTION public.crear_traslado(
    p_bodega_destino_id UUID,
    p_items JSONB,
    p_usuario_id UUID,
    p_notas TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_origen UUID;
    v_traslado_id UUID;
    v_item JSONB;
    v_pid UUID;
    v_cant NUMERIC;
    v_stock NUMERIC;
BEGIN
    SELECT id INTO v_origen FROM public.bodegas WHERE tipo = 'general' LIMIT 1;
    
    INSERT INTO public.traslados (bodega_origen_id, bodega_destino_id, usuario_id, notas, estado)
    VALUES (v_origen, p_bodega_destino_id, p_usuario_id, p_notas, 'COMPLETADO')
    RETURNING id INTO v_traslado_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_pid := (v_item->>'producto_id')::UUID;
        v_cant := (v_item->>'cantidad')::NUMERIC;
        
        SELECT stock_actual INTO v_stock FROM public.productos WHERE id = v_pid;
        IF v_stock < v_cant THEN
            RAISE EXCEPTION 'Stock insuficiente: producto % tiene % disponible', v_pid, v_stock;
        END IF;
        
        -- Descontar de origen
        UPDATE public.productos SET stock_actual = stock_actual - v_cant WHERE id = v_pid;
        
        -- Sumar en destino (crea nuevo registro con los mismos datos del producto)
        INSERT INTO public.productos (maestro_producto_id, bodega_id, stock_actual, numero_lote, fecha_vencimiento, condicion)
        SELECT maestro_producto_id, p_bodega_destino_id, v_cant, numero_lote, fecha_vencimiento, 'Bueno'
        FROM public.productos WHERE id = v_pid;
        
        INSERT INTO public.traslado_items (traslado_id, producto_id, cantidad) VALUES (v_traslado_id, v_pid, v_cant);
    END LOOP;
    
    RETURN v_traslado_id;
END;
$$;

-- 4.4 Listar historial de traslados
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
    SELECT t.id, bo.nombre, bd.nombre, COALESCE(u.name, 'Sistema'),
           t.estado, COUNT(ti.id), t.notas, t.created_at
    FROM public.traslados t
    JOIN public.bodegas bo ON bo.id = t.bodega_origen_id
    JOIN public.bodegas bd ON bd.id = t.bodega_destino_id
    LEFT JOIN public.users u ON u.id = t.usuario_id
    LEFT JOIN public.traslado_items ti ON ti.traslado_id = t.id
    GROUP BY t.id, bo.nombre, bd.nombre, u.name
    ORDER BY t.created_at DESC;
END;
$$;

-- 4.5 Recepción con bodega (actualiza la existente)
DROP FUNCTION IF EXISTS public.procesar_recepcion_mercaderia(text, text, uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS public.procesar_recepcion_mercaderia(text, text, uuid, uuid, uuid, jsonb);

CREATE OR REPLACE FUNCTION public.procesar_recepcion_mercaderia(
    p_numero_documento TEXT,
    p_tipo_documento TEXT,
    p_proveedor_id UUID,
    p_usuario_id UUID,
    p_bodega_id UUID,
    p_detalles JSONB
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_detalle JSONB;
    v_maestro_id UUID;
    v_cantidad NUMERIC;
    v_lote TEXT;
    v_vencimiento DATE;
    v_producto_id UUID;
    v_afectados INT := 0;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.bodegas WHERE id = p_bodega_id) THEN
        RAISE EXCEPTION 'Bodega no encontrada';
    END IF;

    FOR v_detalle IN SELECT * FROM jsonb_array_elements(p_detalles) LOOP
        v_maestro_id := (v_detalle->>'id')::UUID;
        v_cantidad := (v_detalle->>'cantidad')::NUMERIC;
        v_lote := COALESCE(v_detalle->>'lote', 'S/L');
        v_vencimiento := NULLIF(v_detalle->>'vencimiento', '')::DATE;

        INSERT INTO public.productos (maestro_producto_id, bodega_id, stock_actual, numero_lote, fecha_vencimiento, condicion)
        VALUES (v_maestro_id, p_bodega_id, v_cantidad, v_lote, v_vencimiento, 'Bueno')
        RETURNING id INTO v_producto_id;

        v_afectados := v_afectados + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'productos_afectados', v_afectados);
END;
$$;

-- ============================================
-- PARTE 5: PERMISOS
-- ============================================
GRANT EXECUTE ON FUNCTION public.get_inventory_por_bodega TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_products_pos_bodega TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.crear_traslado TO authenticated;
GRANT EXECUTE ON FUNCTION public.listar_traslados TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.procesar_recepcion_mercaderia(text, text, uuid, uuid, uuid, jsonb) TO authenticated;

COMMIT;
