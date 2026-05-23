-- =====================================================
-- LIMPIEZA FINAL: ELIMINAR TODAS LAS POLÍTICAS ANTIGUAS
-- =====================================================

-- Este script elimina todas las políticas antiguas que permiten
-- ver datos sin filtrar por empresa_id

-- ========== MAESTRO_PRODUCTOS ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.maestro_productos;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.maestro_productos;

-- ========== PROVEEDORES ==========
DROP POLICY IF EXISTS "Permitir lectura a autenticados" ON public.proveedores;
DROP POLICY IF EXISTS "Allow authenticated users to read providers" ON public.proveedores;
DROP POLICY IF EXISTS "Allow admin and bodega to manage providers" ON public.proveedores;

-- ========== CATEGORÍAS ==========
DROP POLICY IF EXISTS "Permitir lectura a autenticados" ON public.categorias;
DROP POLICY IF EXISTS "Permitir gestion a admin/bodega" ON public.categorias;

-- ========== CLIENTES ==========
DROP POLICY IF EXISTS "Permitir todo a autenticados" ON public.clientes;

-- ========== PRODUCTOS ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.productos;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.productos;

-- ========== VENTAS ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.ventas;
DROP POLICY IF EXISTS "Permitir gestion a admin y empleado" ON public.ventas;

-- ========== MOVIMIENTOS ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.movimientos;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.movimientos;

-- ========== RECEPCIONES ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.recepciones;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.recepciones;

-- ========== PRE_VENTAS ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.pre_ventas;
DROP POLICY IF EXISTS "Permitir gestion a empleados" ON public.pre_ventas;

-- ========== CAJAS ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.cajas;
DROP POLICY IF EXISTS "Permitir gestion a admin" ON public.cajas;

-- ========== SESIONES_CAJA ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.sesiones_caja;
DROP POLICY IF EXISTS "Permitir gestion a empleados" ON public.sesiones_caja;

-- ========== MOVIMIENTOS_CAJA ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.movimientos_caja;
DROP POLICY IF EXISTS "Permitir gestion a empleados" ON public.movimientos_caja;

-- ========== ORDENES_COMPRA ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.ordenes_compra;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.ordenes_compra;

-- ========== CONFIGURACION ==========
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.configuracion;
DROP POLICY IF EXISTS "Permitir gestion a admin" ON public.configuracion;

-- =====================================================
-- VERIFICACIÓN FINAL
-- =====================================================

-- Ver todas las políticas que quedan (deben filtrar por empresa_id)
SELECT 
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN qual LIKE '%empresa_id%' THEN '✅ Filtra por empresa'
        WHEN qual = 'true' OR qual LIKE '%authenticated%' THEN '❌ NO FILTRA'
        ELSE '⚠️ Revisar: ' || qual
    END as estado
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'maestro_productos', 'productos', 'clientes', 'ventas',
    'movimientos', 'recepciones', 'pre_ventas', 'proveedores',
    'cajas', 'sesiones_caja', 'movimientos_caja', 'categorias',
    'ordenes_compra', 'configuracion'
  )
ORDER BY tablename, cmd;
