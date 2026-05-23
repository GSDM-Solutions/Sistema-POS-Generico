-- =====================================================
-- LIMPIAR STOCK - Eliminar todos los lotes/productos
-- ⚠️ CUIDADO: Esto eliminará todo el inventario actual
-- =====================================================

-- Primero verificar qué se va a eliminar
SELECT 'PREVIEW - Lotes a eliminar' as accion, count(*) as cantidad FROM productos;
SELECT 'PREVIEW - Movimientos a eliminar' as accion, count(*) as cantidad FROM movimientos;
SELECT 'PREVIEW - Recepciones a eliminar' as accion, count(*) as cantidad FROM recepciones;
SELECT 'PREVIEW - Detalles recepcion a eliminar' as accion, count(*) as cantidad FROM detalle_recepcion;

-- =====================================================
-- DESCOMENTAR LAS SIGUIENTES LÍNEAS PARA EJECUTAR LA LIMPIEZA
-- =====================================================

-- Paso 1: Eliminar movimientos (dependen de productos)
-- DELETE FROM movimientos;

-- Paso 2: Eliminar detalles de recepción
-- DELETE FROM detalle_recepcion;

-- Paso 3: Eliminar productos/lotes
-- DELETE FROM productos;

-- Paso 4: Eliminar recepciones
-- DELETE FROM recepciones;

-- Verificar que quedó limpio
-- SELECT 'Productos restantes' as tabla, count(*) as cantidad FROM productos
-- UNION ALL
-- SELECT 'Movimientos restantes', count(*) FROM movimientos
-- UNION ALL
-- SELECT 'Recepciones restantes', count(*) FROM recepciones;
