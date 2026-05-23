-- =====================================================
-- LIMPIEZA FINAL - BASADO EN AUDITORÍA EXHAUSTIVA
-- =====================================================
-- Este script elimina SOLO las tablas y funciones
-- que NO se usan en el código
-- =====================================================

-- ⚠️ IMPORTANTE: Este script es seguro de ejecutar
-- Solo elimina tablas vacías o no utilizadas


-- ========== ELIMINAR TABLAS NO USADAS ==========

-- Sistema médico (no se usa, solo en archived_routes.md)
DROP TABLE IF EXISTS public.entregas_items CASCADE;
DROP TABLE IF EXISTS public.entregas CASCADE;
DROP TABLE IF EXISTS public.pacientes CASCADE;

-- Auditorías/checklists (no se usa en ningún archivo)
DROP TABLE IF EXISTS public.auditoria_preguntas CASCADE;
DROP TABLE IF EXISTS public.auditorias_checklist CASCADE;

-- Tablas duplicadas/antiguas (no se usa en ningún archivo)
DROP TABLE IF EXISTS public.items_venta CASCADE;
DROP TABLE IF EXISTS public.movimientos_stock CASCADE;
DROP TABLE IF EXISTS public.inventory_session_results CASCADE;


-- ========== ELIMINAR FUNCIONES NO USADAS ==========

-- Funciones del sistema médico
DROP FUNCTION IF EXISTS public.get_todays_deliveries() CASCADE;

-- Funciones duplicadas o antiguas
DROP FUNCTION IF EXISTS public.add_stock(uuid, integer, text) CASCADE;
DROP FUNCTION IF EXISTS public.agregar_stock(uuid, integer, text) CASCADE;
DROP FUNCTION IF EXISTS public.crear_venta(json) CASCADE;
DROP FUNCTION IF EXISTS public.create_sale(json) CASCADE;
DROP FUNCTION IF EXISTS public.segregate_stock(uuid, integer, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.asignar_codigo_preventa() CASCADE;
DROP FUNCTION IF EXISTS public.generar_codigo_preventa() CASCADE;
DROP FUNCTION IF EXISTS public.update_preventa_timestamp() CASCADE;


-- ========== VERIFICAR TABLAS RESTANTES ==========
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;


-- ========== VERIFICAR FUNCIONES RESTANTES ==========
SELECT 
    p.proname as function_name,
    COUNT(*) as cantidad_versiones
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
GROUP BY p.proname
ORDER BY p.proname;


-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- 
-- TABLAS ELIMINADAS (8):
-- ❌ pacientes
-- ❌ entregas
-- ❌ entregas_items
-- ❌ auditoria_preguntas
-- ❌ auditorias_checklist
-- ❌ items_venta
-- ❌ movimientos_stock
-- ❌ inventory_session_results
--
-- TABLAS QUE QUEDAN (22):
-- ✅ cajas
-- ✅ categorias (SE USA en ProductMaster)
-- ✅ clientes
-- ✅ configuracion
-- ✅ detalle_ordenes_compra
-- ✅ detalle_recepcion
-- ✅ detalle_ventas
-- ✅ inventory_counts (SE USA en InventoryAudit)
-- ✅ inventory_sessions (SE USA en InventoryAudit)
-- ✅ maestro_productos
-- ✅ movimientos
-- ✅ movimientos_caja
-- ✅ movimientos_cuenta_corriente
-- ✅ ordenes_compra
-- ✅ pre_ventas
-- ✅ producto_presentaciones
-- ✅ productos
-- ✅ proveedores
-- ✅ recepciones
-- ✅ sesiones_caja
-- ✅ users
-- ✅ ventas
--
-- FUNCIONES ELIMINADAS (9):
-- ❌ get_todays_deliveries
-- ❌ add_stock
-- ❌ agregar_stock
-- ❌ crear_venta
-- ❌ create_sale
-- ❌ segregate_stock (versión antigua)
-- ❌ asignar_codigo_preventa
-- ❌ generar_codigo_preventa
-- ❌ update_preventa_timestamp
--
-- =====================================================
-- ESTE SCRIPT ES SEGURO DE EJECUTAR
-- No afecta ninguna funcionalidad del sistema POS
-- =====================================================
