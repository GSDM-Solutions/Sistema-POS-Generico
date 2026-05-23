-- =============================================================
-- AJUSTES DE EFICIENCIA - Sistema POS Generico
-- Fecha: 2026-05-17
-- Descripcion: Indices faltantes, limpieza legacy, RLS, CHECK
-- Ejecutar en SQL Editor de Supabase
-- =============================================================

-- ============================================================
-- 1. INDICES FK FALTANTES (mejora rendimiento consultas)
-- ============================================================

-- Productos
CREATE INDEX IF NOT EXISTS idx_productos_maestro_producto_id ON public.productos(maestro_producto_id);
CREATE INDEX IF NOT EXISTS idx_productos_proveedor_id ON public.productos(proveedor_id);

-- Ventas
CREATE INDEX IF NOT EXISTS idx_ventas_usuario_id ON public.ventas(usuario_id);
CREATE INDEX IF NOT EXISTS idx_ventas_cliente_id ON public.ventas(cliente_id);

-- Detalle Ventas (critico para historial)
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_venta_id ON public.detalle_ventas(venta_id);
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_producto_id ON public.detalle_ventas(producto_id);

-- Movimientos / Kardex (critico)
CREATE INDEX IF NOT EXISTS idx_movimientos_producto_id ON public.movimientos(producto_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_usuario_id ON public.movimientos(usuario_id);

-- Recepciones
CREATE INDEX IF NOT EXISTS idx_recepciones_proveedor_id ON public.recepciones(proveedor_id);
CREATE INDEX IF NOT EXISTS idx_recepciones_usuario_id ON public.recepciones(usuario_id);

-- Detalle Recepcion
CREATE INDEX IF NOT EXISTS idx_detalle_recepcion_recepcion_id ON public.detalle_recepcion(recepcion_id);
CREATE INDEX IF NOT EXISTS idx_detalle_recepcion_producto_id ON public.detalle_recepcion(maestro_producto_id);

-- Cuenta Corriente
CREATE INDEX IF NOT EXISTS idx_movimientos_cc_cliente_id ON public.movimientos_cuenta_corriente(cliente_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_cc_venta_id ON public.movimientos_cuenta_corriente(venta_id);

-- Sesiones Caja
CREATE INDEX IF NOT EXISTS idx_sesiones_caja_caja_id ON public.sesiones_caja(caja_id);

-- Pre-ventas
CREATE INDEX IF NOT EXISTS idx_preventas_cliente_id ON public.pre_ventas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_preventas_venta_id ON public.pre_ventas(venta_id);

-- Traslados
CREATE INDEX IF NOT EXISTS idx_traslados_usuario_id ON public.traslados(usuario_id);
CREATE INDEX IF NOT EXISTS idx_traslado_items_producto_id ON public.traslado_items(producto_id);

-- Inventory Audit
CREATE INDEX IF NOT EXISTS idx_inventory_counts_session_id ON public.inventory_counts(session_id);
CREATE INDEX IF NOT EXISTS idx_inventory_counts_producto_id ON public.inventory_counts(maestro_producto_id);
CREATE INDEX IF NOT EXISTS idx_inventory_results_session_id ON public.inventory_session_results(session_id);
CREATE INDEX IF NOT EXISTS idx_inventory_results_producto_id ON public.inventory_session_results(maestro_producto_id);

-- Auditorias
-- (solo si la tabla existe)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'auditorias_checklist') THEN
    CREATE INDEX IF NOT EXISTS idx_auditorias_usuario_id ON public.auditorias_checklist(usuario_id);
  END IF;
END $$;

-- ============================================================
-- 2. CHECK CONSTRAINT EN movimientos.tipo_movimiento
-- ============================================================
ALTER TABLE public.movimientos 
  DROP CONSTRAINT IF EXISTS chk_movimientos_tipo;

ALTER TABLE public.movimientos
  ADD CONSTRAINT chk_movimientos_tipo 
  CHECK (tipo_movimiento IN ('entrada','salida','venta','ingreso_manual','ajuste','traslado_origen','traslado_destino'));

-- Normalizar valores inconsistentes
UPDATE public.movimientos SET tipo_movimiento = 'venta' WHERE tipo_movimiento = 'VENTA';

-- ============================================================
-- 3. ELIMINAR FUNCIONES LEGACY (nunca usadas)
-- ============================================================
DROP FUNCTION IF EXISTS public.crear_venta(json);
DROP FUNCTION IF EXISTS public.create_sale(json);
DROP FUNCTION IF EXISTS public.add_stock(uuid, integer, text);
DROP FUNCTION IF EXISTS public.agregar_stock(uuid, integer, text);

-- ============================================================
-- 4. ELIMINAR TABLAS LEGACY (solo si existen)
-- ============================================================
DO $$ BEGIN
  DROP TABLE IF EXISTS public.entregas_items CASCADE;
  DROP TABLE IF EXISTS public.entregas CASCADE;
  DROP TABLE IF EXISTS public.pacientes CASCADE;
  DROP TABLE IF EXISTS public.auditoria_preguntas CASCADE;
  DROP TABLE IF EXISTS public.auditorias_checklist CASCADE;
END $$;

-- ============================================================
-- 5. ELIMINAR TABLAS OBSOLETAS
-- ============================================================
DROP TABLE IF EXISTS public.items_venta CASCADE;
DROP TABLE IF EXISTS public.movimientos_stock CASCADE;

-- ============================================================
-- 6. ACTIVAR RLS EN BODEGAS
-- ============================================================
ALTER TABLE public.bodegas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.traslados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.traslado_items ENABLE ROW LEVEL SECURITY;

-- Eliminar politicas existentes si hay
DROP POLICY IF EXISTS "bodegas_empresa_policy" ON public.bodegas;
DROP POLICY IF EXISTS "traslados_empresa_policy" ON public.traslados;
DROP POLICY IF EXISTS "traslado_items_empresa_policy" ON public.traslado_items;

-- Politicas bodegas
CREATE POLICY "bodegas_select_empresa" ON public.bodegas
  FOR SELECT USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "bodegas_insert_empresa" ON public.bodegas
  FOR INSERT WITH CHECK (empresa_id = public.get_user_empresa_id());

CREATE POLICY "bodegas_update_empresa" ON public.bodegas
  FOR UPDATE USING (empresa_id = public.get_user_empresa_id());

-- Politicas traslados
CREATE POLICY "traslados_select_empresa" ON public.traslados
  FOR SELECT USING (
    bodega_origen_id IN (SELECT id FROM public.bodegas WHERE empresa_id = public.get_user_empresa_id())
    OR bodega_destino_id IN (SELECT id FROM public.bodegas WHERE empresa_id = public.get_user_empresa_id())
  );

CREATE POLICY "traslados_insert_empresa" ON public.traslados
  FOR INSERT WITH CHECK (
    bodega_origen_id IN (SELECT id FROM public.bodegas WHERE empresa_id = public.get_user_empresa_id())
  );

CREATE POLICY "traslados_update_empresa" ON public.traslados
  FOR UPDATE USING (
    bodega_origen_id IN (SELECT id FROM public.bodegas WHERE empresa_id = public.get_user_empresa_id())
  );

-- Politicas traslado_items
CREATE POLICY "traslado_items_select_empresa" ON public.traslado_items
  FOR SELECT USING (
    traslado_id IN (
      SELECT t.id FROM public.traslados t
      JOIN public.bodegas b ON b.id = t.bodega_origen_id
      WHERE b.empresa_id = public.get_user_empresa_id()
    )
  );

CREATE POLICY "traslado_items_insert_empresa" ON public.traslado_items
  FOR INSERT WITH CHECK (
    traslado_id IN (
      SELECT t.id FROM public.traslados t
      JOIN public.bodegas b ON b.id = t.bodega_origen_id
      WHERE b.empresa_id = public.get_user_empresa_id()
    )
  );

-- ============================================================
-- 7. LIMPIAR POLITICAS RLS DUPLICADAS
-- ============================================================

-- proveedores: eliminar politicas viejas, mantener multi-empresa
DROP POLICY IF EXISTS "Allow admin and bodega to manage providers" ON public.proveedores;
DROP POLICY IF EXISTS "Allow authenticated to read" ON public.proveedores;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.proveedores;
DROP POLICY IF EXISTS "Permitir lectura a autenticados" ON public.proveedores;
DROP POLICY IF EXISTS "proveedores_select_policy" ON public.proveedores;
DROP POLICY IF EXISTS "proveedores_insert_policy" ON public.proveedores;
DROP POLICY IF EXISTS "proveedores_update_policy" ON public.proveedores;

-- maestro_productos: eliminar politicas viejas, mantener multi-empresa
DROP POLICY IF EXISTS "Enable read access for all users" ON public.maestro_productos;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.maestro_productos;
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON public.maestro_productos;
DROP POLICY IF EXISTS "Enable delete for authenticated users only" ON public.maestro_productos;
DROP POLICY IF EXISTS "maestro_productos_select_policy" ON public.maestro_productos;
