-- =====================================================
-- MIGRACIÓN MULTI-EMPRESA - PASO 3: MIGRAR DATOS EXISTENTES
-- =====================================================
-- Fecha: 2026-02-02
-- Descripción: Asigna empresa_id a todos los registros existentes
-- =====================================================

-- ⚠️ IMPORTANTE: Ejecuta PASO 1 y PASO 2 primero

-- ID de la empresa default
DO $$
DECLARE
    v_empresa_default UUID := '00000000-0000-0000-0000-000000000001'::uuid;
    v_count INTEGER;
BEGIN
    -- 1. Usuarios
    UPDATE public.users SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Usuarios actualizados: %', v_count;

    -- 2. Maestro de Productos
    UPDATE public.maestro_productos SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Maestro productos actualizados: %', v_count;

    -- 3. Productos (Lotes)
    UPDATE public.productos SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Productos actualizados: %', v_count;

    -- 4. Clientes
    UPDATE public.clientes SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Clientes actualizados: %', v_count;

    -- 5. Proveedores
    UPDATE public.proveedores SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Proveedores actualizados: %', v_count;

    -- 6. Ventas
    UPDATE public.ventas SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Ventas actualizadas: %', v_count;

    -- 7. Movimientos
    UPDATE public.movimientos SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Movimientos actualizados: %', v_count;

    -- 8. Recepciones
    UPDATE public.recepciones SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Recepciones actualizadas: %', v_count;

    -- 9. Pre-Ventas
    UPDATE public.pre_ventas SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Pre-ventas actualizadas: %', v_count;

    -- 10. Sesiones de Caja
    UPDATE public.sesiones_caja SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Sesiones de caja actualizadas: %', v_count;

    -- 11. Cajas
    UPDATE public.cajas SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Cajas actualizadas: %', v_count;

    -- 12. Categorías
    UPDATE public.categorias SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Categorías actualizadas: %', v_count;

    -- 13. Órdenes de Compra
    UPDATE public.ordenes_compra SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Órdenes de compra actualizadas: %', v_count;

    -- 14. Configuración
    UPDATE public.configuracion SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Configuración actualizada: %', v_count;

    -- 15. Movimientos de Cuenta Corriente
    UPDATE public.movimientos_cuenta_corriente SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Movimientos CC actualizados: %', v_count;

    -- 16. Movimientos de Caja
    UPDATE public.movimientos_caja SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Movimientos de caja actualizados: %', v_count;

    -- 17. Presentaciones de Productos
    UPDATE public.producto_presentaciones SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Presentaciones actualizadas: %', v_count;

    -- 18. Sesiones de Inventario
    UPDATE public.inventory_sessions SET empresa_id = v_empresa_default WHERE empresa_id IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Sesiones de inventario actualizadas: %', v_count;

    RAISE NOTICE '✅ Migración de datos completada';
END $$;


-- ========== HACER empresa_id OBLIGATORIO (NOT NULL) ==========
-- Ahora que todos los registros tienen empresa_id, lo hacemos obligatorio

ALTER TABLE public.users ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.maestro_productos ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.productos ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.clientes ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.proveedores ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.ventas ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.movimientos ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.recepciones ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.pre_ventas ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.sesiones_caja ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.cajas ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.categorias ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.ordenes_compra ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.configuracion ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.movimientos_cuenta_corriente ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.movimientos_caja ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.producto_presentaciones ALTER COLUMN empresa_id SET NOT NULL;
ALTER TABLE public.inventory_sessions ALTER COLUMN empresa_id SET NOT NULL;


-- ========== VERIFICAR ==========
-- Ver cuántos registros hay por empresa
SELECT 
    'users' as tabla, 
    empresa_id, 
    COUNT(*) as registros 
FROM public.users 
GROUP BY empresa_id

UNION ALL

SELECT 
    'maestro_productos', 
    empresa_id, 
    COUNT(*) 
FROM public.maestro_productos 
GROUP BY empresa_id

UNION ALL

SELECT 
    'clientes', 
    empresa_id, 
    COUNT(*) 
FROM public.clientes 
GROUP BY empresa_id

UNION ALL

SELECT 
    'ventas', 
    empresa_id, 
    COUNT(*) 
FROM public.ventas 
GROUP BY empresa_id

ORDER BY tabla;


-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- Todos los registros existentes tienen empresa_id
-- empresa_id es ahora NOT NULL en todas las tablas
-- Todos los datos están asignados a la empresa default
-- =====================================================
