-- =====================================================
-- AUDITORÍA: Tablas y Funciones del Sistema
-- =====================================================
-- Este script identifica qué tablas y funciones existen
-- y cuáles son del sistema médico antiguo (no se usan)
-- =====================================================

-- ========== PASO 1: VER TODAS LAS TABLAS ==========
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;


-- ========== PASO 2: VER TODAS LAS FUNCIONES ==========
SELECT 
    n.nspname as schema,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
ORDER BY p.proname;


-- =====================================================
-- TABLAS DEL SISTEMA POS (MANTENER):
-- =====================================================
-- ✅ users - Usuarios del sistema
-- ✅ clientes - Clientes
-- ✅ maestro_productos - Catálogo de productos
-- ✅ productos - Lotes/Stock de productos
-- ✅ proveedores - Proveedores
-- ✅ ventas - Cabecera de ventas
-- ✅ detalle_ventas - Detalle de ventas
-- ✅ movimientos - Kardex/Movimientos de inventario
-- ✅ movimientos_cuenta_corriente - Cuenta corriente clientes
-- ✅ recepciones - Recepción de mercadería
-- ✅ detalle_recepcion - Detalle de recepciones
-- ✅ pre_ventas - Pre-ventas
-- ✅ detalle_pre_ventas - Detalle de pre-ventas
-- ✅ sesiones_caja - Sesiones de caja
-- ✅ presentaciones - Presentaciones de productos (cajas, unidades, etc.)
-- ✅ ordenes_compra - Órdenes de compra (si se usa)
-- ✅ detalle_ordenes_compra - Detalle órdenes de compra (si se usa)


-- =====================================================
-- TABLAS DEL SISTEMA MÉDICO (ELIMINAR):
-- =====================================================
-- ❌ pacientes - Sistema médico
-- ❌ entregas - Sistema médico
-- ❌ entregas_items - Sistema médico
-- ❌ checklists - Sistema médico
-- ❌ checklist_items - Sistema médico
-- ❌ paciente_medicamentos - Sistema médico


-- =====================================================
-- FUNCIONES DEL SISTEMA MÉDICO (ELIMINAR):
-- =====================================================
-- ❌ get_todays_deliveries - Sistema médico
-- ❌ Cualquier función relacionada con pacientes/entregas


-- =====================================================
-- RESULTADO DEL ANÁLISIS:
-- =====================================================
-- Ejecuta los PASOS 1 y 2 arriba
-- Luego revisa los resultados y confirma qué eliminar
-- =====================================================
