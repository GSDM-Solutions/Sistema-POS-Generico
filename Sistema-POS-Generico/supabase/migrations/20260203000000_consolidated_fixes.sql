-- =====================================================
-- MIGRACIÓN CONSOLIDADA DE CORRECCIONES
-- Fecha: 2026-02-03
-- Descripción: Unificación de correcciones críticas para Inventario, Recepción y Preventas
-- =====================================================

-- 1. FIX get_inventory_stock: Incluir proveedor y manejar productos activos
DROP FUNCTION IF EXISTS public.get_inventory_stock();

CREATE OR REPLACE FUNCTION public.get_inventory_stock()
RETURNS TABLE(
    maestro_producto_id uuid,
    nombre text,
    codigo_barra text,
    categoria text,
    stock_total numeric,
    precio_venta numeric,
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
        COALESCE(SUM(p.stock_actual * COALESCE(mp.precio_venta, 0)), 0) AS valor_inventario,
        mp.controla_stock,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'stock_actual', p.stock_actual,
                    'fecha_vencimiento', p.fecha_vencimiento,
                    'proveedor_id', p.proveedor_id,
                    'proveedor_nombre', prov.nombre,
                    'numero_lote', p.numero_lote,
                    'observaciones', p.observaciones,
                    'creado_en', p.creado_en
                ) ORDER BY p.fecha_vencimiento ASC NULLS LAST
            ) FILTER (WHERE p.id IS NOT NULL),
            '[]'::jsonb
        ) AS lotes
    FROM public.maestro_productos mp
    LEFT JOIN public.productos p ON mp.id = p.maestro_producto_id AND p.empresa_id = v_empresa_id
    LEFT JOIN public.proveedores prov ON p.proveedor_id = prov.id
    WHERE mp.empresa_id = v_empresa_id
      AND COALESCE(mp.activo, true) = true
    GROUP BY mp.id, mp.nombre, mp.codigo_barra, mp.categoria, mp.precio_venta, mp.controla_stock
    ORDER BY mp.nombre;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_inventory_stock() TO authenticated;


-- 2. FIX procesar_recepcion_mercaderia: Asignar proveedor_id a lotes
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
    v_lote_final TEXT;
BEGIN
    -- Obtener empresa
    v_empresa_id := public.get_user_empresa_id();
    
    -- Validar proveedor
    IF NOT EXISTS (SELECT 1 FROM public.proveedores WHERE id = p_proveedor_id AND empresa_id = v_empresa_id) THEN
        RAISE EXCEPTION 'Proveedor no encontrado o no pertenece a esta empresa';
    END IF;
    
    -- Crear recepción
    INSERT INTO public.recepciones (
        numero_documento, tipo_documento, proveedor_id, usuario_id, empresa_id, fecha_recepcion
    ) VALUES (
        p_numero_documento, p_tipo_documento, p_proveedor_id, p_usuario_id, v_empresa_id, NOW()
    ) RETURNING id INTO v_recepcion_id;
    
    -- Procesar detalles
    FOR v_detalle IN SELECT * FROM jsonb_to_recordset(p_detalles) AS x(
        id uuid, cantidad integer, precio_costo numeric, lote text, vencimiento date
    )
    LOOP
        v_lote_final := COALESCE(NULLIF(TRIM(v_detalle.lote), ''), 'S/L');

        -- Crear producto (lote) CON PROVEEDOR
        INSERT INTO public.productos (
            maestro_producto_id, 
            empresa_id, 
            proveedor_id, 
            stock_actual, 
            numero_lote, 
            fecha_vencimiento, 
            condicion, 
            creado_en
        ) VALUES (
            v_detalle.id,
            v_empresa_id,
            p_proveedor_id,
            v_detalle.cantidad,
            v_lote_final,
            v_detalle.vencimiento,
            'Bueno',
            NOW()
        ) RETURNING id INTO v_producto_id;
        
        -- Detalle recepción
        INSERT INTO public.detalle_recepcion (
            recepcion_id,
            maestro_producto_id,
            cantidad,
            precio_costo_unitario,
            numero_lote,
            fecha_vencimiento,
            condicion
        ) VALUES (
            v_recepcion_id,
            v_detalle.id,
            v_detalle.cantidad,
            v_detalle.precio_costo,
            v_lote_final,
            v_detalle.vencimiento,
            'Bueno'
        );
        
        -- Movimiento
        INSERT INTO public.movimientos (
            producto_id,
            tipo_movimiento,
            cantidad,
            usuario_id,
            empresa_id,
            motivo,
            condicion,
            creado_en
        ) VALUES (
            v_producto_id,
            'entrada',
            v_detalle.cantidad,
            p_usuario_id,
            v_empresa_id,
            'Recepción ' || p_tipo_documento || ' ' || p_numero_documento,
            'Bueno',
            NOW()
        );
    END LOOP;
    
    RETURN v_recepcion_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.procesar_recepcion_mercaderia(text, text, uuid, uuid, jsonb) TO authenticated;


-- 3. FIX Columnas ACTIVO en tablas maestras
ALTER TABLE public.maestro_productos ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT true;
ALTER TABLE public.proveedores ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT true;
ALTER TABLE public.categorias ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT true;

-- Asegurar índices
CREATE INDEX IF NOT EXISTS idx_maestro_productos_activo ON public.maestro_productos(activo);
CREATE INDEX IF NOT EXISTS idx_proveedores_activo ON public.proveedores(activo);


-- 4. FIX Políticas RLS críticas
ALTER TABLE public.maestro_productos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "maestro_productos_select_policy" ON public.maestro_productos;
CREATE POLICY "maestro_productos_select_policy" ON public.maestro_productos
    FOR SELECT USING (auth.uid() IS NOT NULL); -- Lectura global para usuarios autenticados

DROP POLICY IF EXISTS "maestro_productos_insert_policy" ON public.maestro_productos;
CREATE POLICY "maestro_productos_insert_policy" ON public.maestro_productos
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "maestro_productos_update_policy" ON public.maestro_productos;
CREATE POLICY "maestro_productos_update_policy" ON public.maestro_productos
    FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Asegurar que las políticas de proveedores y categorías permitan lectura
DROP POLICY IF EXISTS "proveedores_select_policy" ON public.proveedores;
CREATE POLICY "proveedores_select_policy" ON public.proveedores FOR SELECT USING (true);

DROP POLICY IF EXISTS "categorias_select_policy" ON public.categorias;
CREATE POLICY "categorias_select_policy" ON public.categorias FOR SELECT USING (true);

