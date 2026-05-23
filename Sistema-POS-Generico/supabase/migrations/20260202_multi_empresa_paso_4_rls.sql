-- =====================================================
-- MIGRACIÓN MULTI-EMPRESA - PASO 4: ROW LEVEL SECURITY (RLS)
-- =====================================================
-- Fecha: 2026-02-02
-- Descripción: Implementa políticas de seguridad para segregar datos por empresa
-- =====================================================

-- ⚠️ IMPORTANTE: Ejecuta PASOS 1, 2 y 3 primero

-- ========== FUNCIÓN HELPER: Obtener empresa del usuario actual ==========
CREATE OR REPLACE FUNCTION public.get_user_empresa_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT empresa_id FROM public.users WHERE id = auth.uid();
$$;


-- ========== HABILITAR RLS EN TODAS LAS TABLAS ==========

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maestro_productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recepciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pre_ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sesiones_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cajas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordenes_compra ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_cuenta_corriente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.producto_presentaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_sessions ENABLE ROW LEVEL SECURITY;


-- ========== POLÍTICAS DE SEGURIDAD ==========

-- 1. USERS
DROP POLICY IF EXISTS "Users can only see their company users" ON public.users;
CREATE POLICY "Users can only see their company users"
ON public.users FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert users for their company" ON public.users;
CREATE POLICY "Users can only insert users for their company"
ON public.users FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company users" ON public.users;
CREATE POLICY "Users can only update their company users"
ON public.users FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 2. MAESTRO_PRODUCTOS
DROP POLICY IF EXISTS "Users can only see their company products" ON public.maestro_productos;
CREATE POLICY "Users can only see their company products"
ON public.maestro_productos FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert products for their company" ON public.maestro_productos;
CREATE POLICY "Users can only insert products for their company"
ON public.maestro_productos FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company products" ON public.maestro_productos;
CREATE POLICY "Users can only update their company products"
ON public.maestro_productos FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only delete their company products" ON public.maestro_productos;
CREATE POLICY "Users can only delete their company products"
ON public.maestro_productos FOR DELETE
USING (empresa_id = public.get_user_empresa_id());


-- 3. PRODUCTOS (Lotes)
DROP POLICY IF EXISTS "Users can only see their company stock" ON public.productos;
CREATE POLICY "Users can only see their company stock"
ON public.productos FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert stock for their company" ON public.productos;
CREATE POLICY "Users can only insert stock for their company"
ON public.productos FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company stock" ON public.productos;
CREATE POLICY "Users can only update their company stock"
ON public.productos FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 4. CLIENTES
DROP POLICY IF EXISTS "Users can only see their company customers" ON public.clientes;
CREATE POLICY "Users can only see their company customers"
ON public.clientes FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert customers for their company" ON public.clientes;
CREATE POLICY "Users can only insert customers for their company"
ON public.clientes FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company customers" ON public.clientes;
CREATE POLICY "Users can only update their company customers"
ON public.clientes FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 5. PROVEEDORES
DROP POLICY IF EXISTS "Users can only see their company suppliers" ON public.proveedores;
CREATE POLICY "Users can only see their company suppliers"
ON public.proveedores FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert suppliers for their company" ON public.proveedores;
CREATE POLICY "Users can only insert suppliers for their company"
ON public.proveedores FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company suppliers" ON public.proveedores;
CREATE POLICY "Users can only update their company suppliers"
ON public.proveedores FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 6. VENTAS
DROP POLICY IF EXISTS "Users can only see their company sales" ON public.ventas;
CREATE POLICY "Users can only see their company sales"
ON public.ventas FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert sales for their company" ON public.ventas;
CREATE POLICY "Users can only insert sales for their company"
ON public.ventas FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());


-- 7. MOVIMIENTOS
DROP POLICY IF EXISTS "Users can only see their company movements" ON public.movimientos;
CREATE POLICY "Users can only see their company movements"
ON public.movimientos FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert movements for their company" ON public.movimientos;
CREATE POLICY "Users can only insert movements for their company"
ON public.movimientos FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());


-- 8. RECEPCIONES
DROP POLICY IF EXISTS "Users can only see their company receptions" ON public.recepciones;
CREATE POLICY "Users can only see their company receptions"
ON public.recepciones FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert receptions for their company" ON public.recepciones;
CREATE POLICY "Users can only insert receptions for their company"
ON public.recepciones FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());


-- 9. PRE_VENTAS
DROP POLICY IF EXISTS "Users can only see their company presales" ON public.pre_ventas;
CREATE POLICY "Users can only see their company presales"
ON public.pre_ventas FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert presales for their company" ON public.pre_ventas;
CREATE POLICY "Users can only insert presales for their company"
ON public.pre_ventas FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company presales" ON public.pre_ventas;
CREATE POLICY "Users can only update their company presales"
ON public.pre_ventas FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 10. SESIONES_CAJA
DROP POLICY IF EXISTS "Users can only see their company cash sessions" ON public.sesiones_caja;
CREATE POLICY "Users can only see their company cash sessions"
ON public.sesiones_caja FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert cash sessions for their company" ON public.sesiones_caja;
CREATE POLICY "Users can only insert cash sessions for their company"
ON public.sesiones_caja FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company cash sessions" ON public.sesiones_caja;
CREATE POLICY "Users can only update their company cash sessions"
ON public.sesiones_caja FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 11. CAJAS
DROP POLICY IF EXISTS "Users can only see their company cash registers" ON public.cajas;
CREATE POLICY "Users can only see their company cash registers"
ON public.cajas FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert cash registers for their company" ON public.cajas;
CREATE POLICY "Users can only insert cash registers for their company"
ON public.cajas FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company cash registers" ON public.cajas;
CREATE POLICY "Users can only update their company cash registers"
ON public.cajas FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 12. CATEGORIAS
DROP POLICY IF EXISTS "Users can only see their company categories" ON public.categorias;
CREATE POLICY "Users can only see their company categories"
ON public.categorias FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert categories for their company" ON public.categorias;
CREATE POLICY "Users can only insert categories for their company"
ON public.categorias FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company categories" ON public.categorias;
CREATE POLICY "Users can only update their company categories"
ON public.categorias FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only delete their company categories" ON public.categorias;
CREATE POLICY "Users can only delete their company categories"
ON public.categorias FOR DELETE
USING (empresa_id = public.get_user_empresa_id());


-- 13. ORDENES_COMPRA
DROP POLICY IF EXISTS "Users can only see their company purchase orders" ON public.ordenes_compra;
CREATE POLICY "Users can only see their company purchase orders"
ON public.ordenes_compra FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert purchase orders for their company" ON public.ordenes_compra;
CREATE POLICY "Users can only insert purchase orders for their company"
ON public.ordenes_compra FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company purchase orders" ON public.ordenes_compra;
CREATE POLICY "Users can only update their company purchase orders"
ON public.ordenes_compra FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 14. CONFIGURACION
DROP POLICY IF EXISTS "Users can only see their company config" ON public.configuracion;
CREATE POLICY "Users can only see their company config"
ON public.configuracion FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert config for their company" ON public.configuracion;
CREATE POLICY "Users can only insert config for their company"
ON public.configuracion FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company config" ON public.configuracion;
CREATE POLICY "Users can only update their company config"
ON public.configuracion FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 15. MOVIMIENTOS_CUENTA_CORRIENTE
DROP POLICY IF EXISTS "Users can only see their company account movements" ON public.movimientos_cuenta_corriente;
CREATE POLICY "Users can only see their company account movements"
ON public.movimientos_cuenta_corriente FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert account movements for their company" ON public.movimientos_cuenta_corriente;
CREATE POLICY "Users can only insert account movements for their company"
ON public.movimientos_cuenta_corriente FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());


-- 16. MOVIMIENTOS_CAJA
DROP POLICY IF EXISTS "Users can only see their company cash movements" ON public.movimientos_caja;
CREATE POLICY "Users can only see their company cash movements"
ON public.movimientos_caja FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert cash movements for their company" ON public.movimientos_caja;
CREATE POLICY "Users can only insert cash movements for their company"
ON public.movimientos_caja FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());


-- 17. PRODUCTO_PRESENTACIONES
DROP POLICY IF EXISTS "Users can only see their company presentations" ON public.producto_presentaciones;
CREATE POLICY "Users can only see their company presentations"
ON public.producto_presentaciones FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert presentations for their company" ON public.producto_presentaciones;
CREATE POLICY "Users can only insert presentations for their company"
ON public.producto_presentaciones FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company presentations" ON public.producto_presentaciones;
CREATE POLICY "Users can only update their company presentations"
ON public.producto_presentaciones FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- 18. INVENTORY_SESSIONS
DROP POLICY IF EXISTS "Users can only see their company inventory sessions" ON public.inventory_sessions;
CREATE POLICY "Users can only see their company inventory sessions"
ON public.inventory_sessions FOR SELECT
USING (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only insert inventory sessions for their company" ON public.inventory_sessions;
CREATE POLICY "Users can only insert inventory sessions for their company"
ON public.inventory_sessions FOR INSERT
WITH CHECK (empresa_id = public.get_user_empresa_id());

DROP POLICY IF EXISTS "Users can only update their company inventory sessions" ON public.inventory_sessions;
CREATE POLICY "Users can only update their company inventory sessions"
ON public.inventory_sessions FOR UPDATE
USING (empresa_id = public.get_user_empresa_id());


-- ========== VERIFICAR POLÍTICAS ==========
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;


-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- RLS habilitado en 18 tablas
-- ~50 políticas de seguridad creadas
-- Cada empresa solo puede ver sus propios datos
-- =====================================================
