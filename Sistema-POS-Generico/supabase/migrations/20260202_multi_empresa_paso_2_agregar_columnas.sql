-- =====================================================
-- MIGRACIÓN MULTI-EMPRESA - PASO 2: AGREGAR COLUMNA EMPRESA_ID
-- =====================================================
-- Fecha: 2026-02-02
-- Descripción: Agrega columna empresa_id a todas las tablas principales
-- =====================================================

-- ⚠️ IMPORTANTE: Ejecuta PASO 1 primero

-- ID de la empresa default
-- 00000000-0000-0000-0000-000000000001

-- ========== AGREGAR COLUMNA empresa_id ==========

-- 1. Usuarios
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 2. Maestro de Productos
ALTER TABLE public.maestro_productos 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 3. Productos (Lotes)
ALTER TABLE public.productos 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 4. Clientes
ALTER TABLE public.clientes 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 5. Proveedores
ALTER TABLE public.proveedores 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 6. Ventas
ALTER TABLE public.ventas 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 7. Movimientos
ALTER TABLE public.movimientos 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 8. Recepciones
ALTER TABLE public.recepciones 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 9. Pre-Ventas
ALTER TABLE public.pre_ventas 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 10. Sesiones de Caja
ALTER TABLE public.sesiones_caja 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 11. Cajas
ALTER TABLE public.cajas 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 12. Categorías
ALTER TABLE public.categorias 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 13. Órdenes de Compra
ALTER TABLE public.ordenes_compra 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 14. Configuración
ALTER TABLE public.configuracion 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 15. Movimientos de Cuenta Corriente
ALTER TABLE public.movimientos_cuenta_corriente 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 16. Movimientos de Caja
ALTER TABLE public.movimientos_caja 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 17. Presentaciones de Productos
ALTER TABLE public.producto_presentaciones 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);

-- 18. Sesiones de Inventario
ALTER TABLE public.inventory_sessions 
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id);


-- ========== CREAR ÍNDICES PARA PERFORMANCE ==========

CREATE INDEX IF NOT EXISTS idx_users_empresa_id ON public.users(empresa_id);
CREATE INDEX IF NOT EXISTS idx_maestro_productos_empresa_id ON public.maestro_productos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_productos_empresa_id ON public.productos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_clientes_empresa_id ON public.clientes(empresa_id);
CREATE INDEX IF NOT EXISTS idx_proveedores_empresa_id ON public.proveedores(empresa_id);
CREATE INDEX IF NOT EXISTS idx_ventas_empresa_id ON public.ventas(empresa_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_empresa_id ON public.movimientos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_recepciones_empresa_id ON public.recepciones(empresa_id);
CREATE INDEX IF NOT EXISTS idx_pre_ventas_empresa_id ON public.pre_ventas(empresa_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_caja_empresa_id ON public.sesiones_caja(empresa_id);
CREATE INDEX IF NOT EXISTS idx_cajas_empresa_id ON public.cajas(empresa_id);
CREATE INDEX IF NOT EXISTS idx_categorias_empresa_id ON public.categorias(empresa_id);
CREATE INDEX IF NOT EXISTS idx_ordenes_compra_empresa_id ON public.ordenes_compra(empresa_id);
CREATE INDEX IF NOT EXISTS idx_configuracion_empresa_id ON public.configuracion(empresa_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_cc_empresa_id ON public.movimientos_cuenta_corriente(empresa_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_caja_empresa_id ON public.movimientos_caja(empresa_id);
CREATE INDEX IF NOT EXISTS idx_producto_presentaciones_empresa_id ON public.producto_presentaciones(empresa_id);
CREATE INDEX IF NOT EXISTS idx_inventory_sessions_empresa_id ON public.inventory_sessions(empresa_id);


-- ========== VERIFICAR ==========
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE column_name = 'empresa_id'
  AND table_schema = 'public'
ORDER BY table_name;


-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- 18 tablas con columna empresa_id agregada
-- 18 índices creados para performance
-- =====================================================
