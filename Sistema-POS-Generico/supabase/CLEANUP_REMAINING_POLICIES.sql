-- =====================================================
-- ELIMINAR POLÍTICAS ANTIGUAS RESTANTES
-- =====================================================

-- CAJAS
DROP POLICY IF EXISTS "Permitir lectura de cajas a autenticados" ON public.cajas;

-- MOVIMIENTOS_CAJA
DROP POLICY IF EXISTS "Ver movimientos propios o admin" ON public.movimientos_caja;

-- ORDENES_COMPRA
DROP POLICY IF EXISTS "Accesible para usuarios autenticados" ON public.ordenes_compra;

-- RECEPCIONES
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.recepciones;

-- SESIONES_CAJA
DROP POLICY IF EXISTS "Ver sesiones propias o admin" ON public.sesiones_caja;

-- VENTAS
DROP POLICY IF EXISTS "Permitir todo a autenticados" ON public.ventas;

-- MOVIMIENTOS (políticas duplicadas)
DROP POLICY IF EXISTS "Allow authenticated users to insert movements via function" ON public.movimientos;
DROP POLICY IF EXISTS "Permitir insercion a roles autorizados" ON public.movimientos;
DROP POLICY IF EXISTS "Permitir eliminacion a admin" ON public.movimientos;
DROP POLICY IF EXISTS "Permitir actualizacion a admin" ON public.movimientos;

-- PRE_VENTAS (políticas duplicadas)
DROP POLICY IF EXISTS "Vendedores crean preventas" ON public.pre_ventas;
DROP POLICY IF EXISTS "Vendedores ven sus preventas" ON public.pre_ventas;
DROP POLICY IF EXISTS "Vendedores editan borradores" ON public.pre_ventas;

-- VENTAS (políticas duplicadas)
DROP POLICY IF EXISTS "Los usuarios pueden crear ventas" ON public.ventas;
DROP POLICY IF EXISTS "Los usuarios pueden ver sus propias ventas" ON public.ventas;

-- =====================================================
-- VERIFICACIÓN FINAL
-- =====================================================

SELECT 
    tablename,
    COUNT(*) as total_policies,
    SUM(CASE WHEN qual LIKE '%empresa_id%' THEN 1 ELSE 0 END) as con_filtro_empresa,
    SUM(CASE WHEN qual = 'true' OR qual LIKE '%authenticated%' THEN 1 ELSE 0 END) as sin_filtro
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'maestro_productos', 'productos', 'clientes', 'ventas',
    'movimientos', 'recepciones', 'pre_ventas', 'proveedores',
    'cajas', 'sesiones_caja', 'movimientos_caja', 'categorias',
    'ordenes_compra', 'configuracion'
  )
GROUP BY tablename
ORDER BY tablename;
