-- =====================================================
-- BACKUP MANUAL - Tablas a Eliminar
-- =====================================================
-- Ejecuta esto ANTES de eliminar las tablas
-- Guarda los datos por si acaso los necesitas después
-- =====================================================

-- ========== VERIFICAR SI HAY DATOS ==========

-- Tablas del sistema médico
SELECT 'pacientes' as tabla, COUNT(*) as registros FROM public.pacientes
UNION ALL
SELECT 'entregas', COUNT(*) FROM public.entregas
UNION ALL
SELECT 'entregas_items', COUNT(*) FROM public.entregas_items
UNION ALL
SELECT 'auditoria_preguntas', COUNT(*) FROM public.auditoria_preguntas
UNION ALL
SELECT 'auditorias_checklist', COUNT(*) FROM public.auditorias_checklist
UNION ALL
SELECT 'items_venta', COUNT(*) FROM public.items_venta
UNION ALL
SELECT 'movimientos_stock', COUNT(*) FROM public.movimientos_stock
UNION ALL
SELECT 'categorias', COUNT(*) FROM public.categorias
UNION ALL
SELECT 'inventory_counts', COUNT(*) FROM public.inventory_counts
UNION ALL
SELECT 'inventory_session_results', COUNT(*) FROM public.inventory_session_results
UNION ALL
SELECT 'inventory_sessions', COUNT(*) FROM public.inventory_sessions;


-- =====================================================
-- SI TODAS LAS TABLAS TIENEN 0 REGISTROS:
-- Puedes eliminarlas sin problema
-- 
-- SI ALGUNA TABLA TIENE DATOS:
-- Revisa si necesitas esos datos antes de eliminar
-- =====================================================
