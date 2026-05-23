-- ============================================================
-- MIGRACION: Optimizacion de Base de Datos
-- Fecha: 2026-05-21
-- Descripcion:
--   1. Indices faltantes en columnas de alta consulta
--   2. Limpieza de tablas/funciones duplicadas (legacy English)
--   3. Correccion de politicas RLS
--   4. Normalizacion de tipo_movimiento casing
-- ============================================================

BEGIN;

-- ============================================================
-- PARTE 1: INDICES FALTANTES
-- ============================================================

-- NOTA: Los indices simple-columna en empresa_id ya existen desde
-- la migracion multi_empresa_paso_2. Aqui solo agregamos indices
-- compuestos y de performance que faltan.

-- 1.1 Tabla movimientos (la mas consultada en toda la app)
CREATE INDEX IF NOT EXISTS idx_movimientos_producto_id ON public.movimientos(producto_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_tipo ON public.movimientos(tipo_movimiento);
CREATE INDEX IF NOT EXISTS idx_movimientos_creado_en ON public.movimientos(creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_movimientos_usuario_id ON public.movimientos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_condicion ON public.movimientos(condicion);

-- Indice compuesto para calculos de stock por producto/condicion (query mas frecuente)
CREATE INDEX IF NOT EXISTS idx_movimientos_stock_calc 
    ON public.movimientos(producto_id, tipo_movimiento, condicion);

-- 1.2 Tabla productos (segunda mas consultada)
CREATE INDEX IF NOT EXISTS idx_productos_maestro ON public.productos(maestro_producto_id);
CREATE INDEX IF NOT EXISTS idx_productos_stock ON public.productos(stock_actual) WHERE stock_actual > 0;

-- Indice compuesto para busqueda POS con bodega
CREATE INDEX IF NOT EXISTS idx_productos_bodega_stock 
    ON public.productos(bodega_id, stock_actual) WHERE stock_actual > 0;

-- Indice compuesto para busqueda FIFO en procesar_venta
CREATE INDEX IF NOT EXISTS idx_productos_maestro_stock 
    ON public.productos(maestro_producto_id, stock_actual, fecha_vencimiento) 
    WHERE stock_actual > 0;

-- 1.3 Tabla detalle_ventas
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_venta ON public.detalle_ventas(venta_id);
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_creado_en ON public.detalle_ventas(creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_producto ON public.detalle_ventas(producto_id);

-- 1.4 Tabla ventas
CREATE INDEX IF NOT EXISTS idx_ventas_creado_en ON public.ventas(creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_ventas_cliente ON public.ventas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_ventas_usuario ON public.ventas(usuario_id);

-- 1.5 Tabla maestro_productos
CREATE INDEX IF NOT EXISTS idx_maestro_activo ON public.maestro_productos(activo) WHERE activo = true;
CREATE INDEX IF NOT EXISTS idx_maestro_categoria ON public.maestro_productos(categoria);

-- 1.6 Tabla movimientos_cuenta_corriente
CREATE INDEX IF NOT EXISTS idx_mov_cc_cliente ON public.movimientos_cuenta_corriente(cliente_id);

-- 1.7 Tabla pre_ventas
CREATE INDEX IF NOT EXISTS idx_preventas_estado ON public.pre_ventas(estado);
CREATE INDEX IF NOT EXISTS idx_preventas_vendedor ON public.pre_ventas(vendedor_id);

-- 1.8 Tabla inventory_counts
CREATE INDEX IF NOT EXISTS idx_inv_counts_session ON public.inventory_counts(session_id);

-- 1.9 Tabla bodegas
CREATE INDEX IF NOT EXISTS idx_bodegas_empresa_tipo ON public.bodegas(empresa_id, tipo);

-- 1.10 Tabla traslados
CREATE INDEX IF NOT EXISTS idx_traslados_created ON public.traslados(created_at DESC);

-- ============================================================
-- PARTE 2: LIMPIEZA DE TABLAS Y FUNCIONES DUPLICADAS (LEGACY)
-- ============================================================

-- 2.1 Eliminar funciones duplicadas en ingles (reemplazadas por versiones en espanol)
DROP FUNCTION IF EXISTS public.create_sale(json);
DROP FUNCTION IF EXISTS public.add_stock(uuid, integer, text);
DROP FUNCTION IF EXISTS public.agregar_stock(uuid, integer, text);

-- 2.2 Eliminar funcion crear_venta antigua (reemplazada por procesar_venta)
DROP FUNCTION IF EXISTS public.crear_venta(json);

-- 2.3 Eliminar tabla items_venta si existe (reemplazada por detalle_ventas)
-- Solo si esta vacia o si las migraciones modernas ya no la usan
DO $$
DECLARE
    v_count bigint;
BEGIN
    SELECT COUNT(*) INTO v_count FROM public.items_venta;
    IF v_count = 0 THEN
        DROP TABLE IF EXISTS public.items_venta CASCADE;
        RAISE NOTICE 'Tabla items_venta eliminada (estaba vacia)';
    ELSE
        RAISE NOTICE 'Tabla items_venta tiene % registros. No se elimina automaticamente.', v_count;
    END IF;
END $$;

-- 2.4 Eliminar tabla movimientos_stock si existe (reemplazada por movimientos)
DO $$
DECLARE
    v_count bigint;
BEGIN
    SELECT COUNT(*) INTO v_count FROM public.movimientos_stock;
    IF v_count = 0 THEN
        DROP TABLE IF EXISTS public.movimientos_stock CASCADE;
        RAISE NOTICE 'Tabla movimientos_stock eliminada (estaba vacia)';
    ELSE
        RAISE NOTICE 'Tabla movimientos_stock tiene % registros. No se elimina automaticamente.', v_count;
    END IF;
END $$;

-- 2.5 Eliminar columna duplicada fecha_creacion de ventas (ya existe creado_en)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'ventas' AND column_name = 'fecha_creacion'
    ) THEN
        ALTER TABLE public.ventas DROP COLUMN IF EXISTS fecha_creacion;
    END IF;
END $$;

-- ============================================================
-- PARTE 3: CORRECCION DE POLITICAS RLS
-- ============================================================
-- Se usa get_user_empresa_id() (SECURITY DEFINER) para evitar
-- recursion infinita de RLS al consultar la tabla users.
-- ============================================================

-- 3.1 Ventas: Consolidar politicas y agregar filtro por empresa
DROP POLICY IF EXISTS "Los usuarios pueden crear ventas" ON public.ventas;
DROP POLICY IF EXISTS "Los usuarios pueden ver sus propias ventas" ON public.ventas;
DROP POLICY IF EXISTS "Permitir todo a autenticados" ON public.ventas;

CREATE POLICY "ventas_select" ON public.ventas 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "ventas_insert" ON public.ventas 
    FOR INSERT TO authenticated 
    WITH CHECK (
        usuario_id = auth.uid()
        AND empresa_id = public.get_user_empresa_id()
    );

CREATE POLICY "ventas_update" ON public.ventas 
    FOR UPDATE TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

-- 3.2 clientes: Restringir por empresa
DROP POLICY IF EXISTS "Permitir todo a autenticados" ON public.clientes;

CREATE POLICY "clientes_select" ON public.clientes 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "clientes_insert" ON public.clientes 
    FOR INSERT TO authenticated 
    WITH CHECK (empresa_id = public.get_user_empresa_id());

CREATE POLICY "clientes_update" ON public.clientes 
    FOR UPDATE TO authenticated 
    USING (empresa_id = public.get_user_empresa_id())
    WITH CHECK (empresa_id = public.get_user_empresa_id());

CREATE POLICY "clientes_delete" ON public.clientes 
    FOR DELETE TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

-- 3.3 detalle_ventas: Restringir por empresa via venta_id
DROP POLICY IF EXISTS "Permitir todo a autenticados" ON public.detalle_ventas;

CREATE POLICY "detalle_ventas_select" ON public.detalle_ventas 
    FOR SELECT TO authenticated 
    USING (
        venta_id IN (
            SELECT id FROM public.ventas 
            WHERE empresa_id = public.get_user_empresa_id()
        )
    );

CREATE POLICY "detalle_ventas_insert" ON public.detalle_ventas 
    FOR INSERT TO authenticated 
    WITH CHECK (true);

-- 3.4 movimientos_cuenta_corriente: Restringir por empresa
DROP POLICY IF EXISTS "Permitir todo a autenticados" ON public.movimientos_cuenta_corriente;

CREATE POLICY "mov_cc_select" ON public.movimientos_cuenta_corriente 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "mov_cc_insert" ON public.movimientos_cuenta_corriente 
    FOR INSERT TO authenticated 
    WITH CHECK (empresa_id = public.get_user_empresa_id());

-- 3.5 movimientos: Consolidar politicas
DROP POLICY IF EXISTS "Allow authenticated users to insert movements via function" ON public.movimientos;
DROP POLICY IF EXISTS "Permitir insercion a roles autorizados" ON public.movimientos;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.movimientos;
DROP POLICY IF EXISTS "Permitir actualizacion a admin" ON public.movimientos;
DROP POLICY IF EXISTS "Permitir eliminacion a admin" ON public.movimientos;

CREATE POLICY "movimientos_select" ON public.movimientos 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "movimientos_insert" ON public.movimientos 
    FOR INSERT TO authenticated 
    WITH CHECK (
        empresa_id = public.get_user_empresa_id()
        AND usuario_id = auth.uid()
    );

CREATE POLICY "movimientos_update" ON public.movimientos 
    FOR UPDATE TO authenticated 
    USING (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    );

CREATE POLICY "movimientos_delete" ON public.movimientos 
    FOR DELETE TO authenticated 
    USING (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    );

-- 3.6 categorias: Restringir gestion por empresa
DROP POLICY IF EXISTS "Permitir lectura a autenticados" ON public.categorias;
DROP POLICY IF EXISTS "Permitir gestion a admin/bodega" ON public.categorias;

CREATE POLICY "categorias_select" ON public.categorias 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "categorias_gestion" ON public.categorias 
    FOR ALL TO authenticated 
    USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'bodega', 'superadmin', 'supervisor')
        AND empresa_id = public.get_user_empresa_id()
    ) WITH CHECK (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'bodega', 'superadmin', 'supervisor')
        AND empresa_id = public.get_user_empresa_id()
    );

-- 3.7 proveedores: Consolidar politicas duplicadas
DROP POLICY IF EXISTS "Allow admin and bodega to manage providers" ON public.proveedores;
DROP POLICY IF EXISTS "Allow authenticated users to read providers" ON public.proveedores;
DROP POLICY IF EXISTS "Permitir lectura a autenticados" ON public.proveedores;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.proveedores;

CREATE POLICY "proveedores_select" ON public.proveedores 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "proveedores_gestion" ON public.proveedores 
    FOR ALL TO authenticated 
    USING (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    ) WITH CHECK (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    );

-- 3.8 cajas: Agregar filtro por empresa
DROP POLICY IF EXISTS "Permitir lectura de cajas a autenticados" ON public.cajas;

CREATE POLICY "cajas_select" ON public.cajas 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "cajas_gestion" ON public.cajas 
    FOR ALL TO authenticated 
    USING (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    ) WITH CHECK (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    );

-- 3.9 sesiones_caja: Agregar filtro por empresa
DROP POLICY IF EXISTS "Ver sesiones propias o admin" ON public.sesiones_caja;

CREATE POLICY "sesiones_select" ON public.sesiones_caja 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "sesiones_insert" ON public.sesiones_caja 
    FOR INSERT TO authenticated 
    WITH CHECK (
        usuario_id = auth.uid()
        AND empresa_id = public.get_user_empresa_id()
    );

CREATE POLICY "sesiones_update" ON public.sesiones_caja 
    FOR UPDATE TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

-- 3.10 movimientos_caja: Agregar filtro por empresa
DROP POLICY IF EXISTS "Ver movimientos propios o admin" ON public.movimientos_caja;

CREATE POLICY "mov_caja_select" ON public.movimientos_caja 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "mov_caja_insert" ON public.movimientos_caja 
    FOR INSERT TO authenticated 
    WITH CHECK (empresa_id = public.get_user_empresa_id());

-- 3.11 recepciones: Agregar filtro por empresa
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.recepciones;

CREATE POLICY "recepciones_select" ON public.recepciones 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "recepciones_insert" ON public.recepciones 
    FOR INSERT TO authenticated 
    WITH CHECK (empresa_id = public.get_user_empresa_id());

-- 3.12 detalle_recepcion: Agregar filtro por empresa
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.detalle_recepcion;

CREATE POLICY "detalle_rec_select" ON public.detalle_recepcion 
    FOR SELECT TO authenticated 
    USING (
        recepcion_id IN (
            SELECT id FROM public.recepciones 
            WHERE empresa_id = public.get_user_empresa_id()
        )
    );

CREATE POLICY "detalle_rec_insert" ON public.detalle_recepcion 
    FOR INSERT TO authenticated 
    WITH CHECK (true);

-- 3.13 ordenes_compra + detalle_ordenes_compra: Agregar filtro por empresa
DROP POLICY IF EXISTS "Accesible para usuarios autenticados" ON public.ordenes_compra;

CREATE POLICY "oc_select" ON public.ordenes_compra 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "oc_gestion" ON public.ordenes_compra 
    FOR ALL TO authenticated 
    USING (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    ) WITH CHECK (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    );

DROP POLICY IF EXISTS "Accesible para usuarios autenticados" ON public.detalle_ordenes_compra;

CREATE POLICY "det_oc_select" ON public.detalle_ordenes_compra 
    FOR SELECT TO authenticated 
    USING (
        orden_id IN (
            SELECT id FROM public.ordenes_compra 
            WHERE empresa_id = public.get_user_empresa_id()
        )
    );

CREATE POLICY "det_oc_insert" ON public.detalle_ordenes_compra 
    FOR INSERT TO authenticated 
    WITH CHECK (true);

-- 3.14 maestro_productos: Agregar filtro por empresa a SELECT
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.maestro_productos;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.maestro_productos;

CREATE POLICY "maestro_select" ON public.maestro_productos 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "maestro_gestion" ON public.maestro_productos 
    FOR ALL TO authenticated 
    USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'bodega', 'superadmin', 'supervisor')
        AND empresa_id = public.get_user_empresa_id()
    ) WITH CHECK (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'bodega', 'superadmin', 'supervisor')
        AND empresa_id = public.get_user_empresa_id()
    );

-- 3.15 productos: Agregar filtro por empresa
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.productos;
DROP POLICY IF EXISTS "Permitir gestion a admin y bodega" ON public.productos;

CREATE POLICY "productos_select" ON public.productos 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "productos_gestion" ON public.productos 
    FOR ALL TO authenticated 
    USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'bodega', 'superadmin', 'supervisor')
        AND empresa_id = public.get_user_empresa_id()
    ) WITH CHECK (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'bodega', 'superadmin', 'supervisor')
        AND empresa_id = public.get_user_empresa_id()
    );

-- 3.16 users: Evitar recursion de RLS usando SECURITY DEFINER functions
DROP POLICY IF EXISTS "Allow authenticated users to view all users" ON public.users;
DROP POLICY IF EXISTS "Allow admin to manage all users" ON public.users;

CREATE POLICY "users_select" ON public.users 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "users_gestion" ON public.users 
    FOR ALL TO authenticated 
    USING (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    ) WITH CHECK (
        public.is_admin()
        AND empresa_id = public.get_user_empresa_id()
    );

-- 3.17 producto_presentaciones: Agregar filtro por empresa
DROP POLICY IF EXISTS "Lectura presentaciones usuarios autenticados" ON public.producto_presentaciones;
DROP POLICY IF EXISTS "Gestion presentaciones admin y bodega" ON public.producto_presentaciones;

CREATE POLICY "pp_select" ON public.producto_presentaciones 
    FOR SELECT TO authenticated 
    USING (empresa_id = public.get_user_empresa_id());

CREATE POLICY "pp_gestion" ON public.producto_presentaciones 
    FOR ALL TO authenticated 
    USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'bodega', 'superadmin', 'supervisor')
        AND empresa_id = public.get_user_empresa_id()
    ) WITH CHECK (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'bodega', 'superadmin', 'supervisor')
        AND empresa_id = public.get_user_empresa_id()
    );

-- ============================================================
-- PARTE 4: NORMALIZACION DE TIPO_MOVIMIENTO
-- ============================================================

-- 4.1 Asegurar consistencia en movimientos (todo lowercase)
DO $$
BEGIN
    -- Convertir 'VENTA' -> 'salida' (valor usado en procesar_venta original dice 'VENTA')
    UPDATE public.movimientos 
    SET tipo_movimiento = 'salida' 
    WHERE tipo_movimiento = 'VENTA';
    
    -- Convertir 'entrada' (ya esta bien)
    -- Convertir 'salida' (ya esta bien)
    -- Convertir 'ajuste' (ya esta bien)
    
    RAISE NOTICE 'Tipos de movimiento normalizados a lowercase';
END $$;

-- ============================================================
-- PARTE 5: GRANTS PARA NUEVAS FUNCIONES
-- ============================================================

-- Asegurar grants para funciones multi-empresa actualizadas
GRANT EXECUTE ON FUNCTION public.get_user_empresa_id() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_products_pos(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_products_pos_bodega(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_inventory_por_bodega(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_critical_stock_products_list() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_expiring_products_list(integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_quarantine_products_list() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_dispatch_lots(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_movement_history(date, date, uuid[], text, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.listar_traslados() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_users() TO authenticated, anon;

GRANT EXECUTE ON FUNCTION public.procesar_venta(uuid, text, jsonb, uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.procesar_recepcion_mercaderia(text, text, uuid, uuid, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.crear_traslado(uuid, jsonb, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_salida_manual(uuid, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.segregate_stock(uuid, integer, text, text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recepcionar_orden_compra(uuid, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.abrir_caja(uuid, numeric, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_caja(uuid, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.crear_nueva_caja(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.actualizar_clave_maestra(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.crear_preventa(uuid, jsonb, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enviar_preventa(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirmar_preventa(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rechazar_preventa(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_preventa(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.listar_preventas(uuid, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.buscar_preventa_por_codigo(text) TO authenticated;

-- ============================================================
-- VERIFICACION
-- ============================================================
DO $$
DECLARE
    v_idx_count integer;
    v_policy_count integer;
BEGIN
    SELECT COUNT(*) INTO v_idx_count FROM pg_indexes WHERE schemaname = 'public';
    SELECT COUNT(*) INTO v_policy_count FROM pg_policies WHERE schemaname = 'public';
    
    RAISE NOTICE '=======================================';
    RAISE NOTICE 'Migracion completada:';
    RAISE NOTICE '  - Indices totales en public: %', v_idx_count;
    RAISE NOTICE '  - Politicas RLS totales en public: %', v_policy_count;
    RAISE NOTICE '=======================================';
END $$;

COMMIT;
