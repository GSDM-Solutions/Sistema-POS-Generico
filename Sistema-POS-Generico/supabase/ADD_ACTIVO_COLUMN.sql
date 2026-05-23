-- =====================================================
-- AGREGAR COLUMNA ACTIVO A PROVEEDORES Y CATEGORIAS
-- Fecha: 2026-02-03
-- Esta columna permite soft-delete (desactivar en lugar de eliminar)
-- =====================================================

-- 1. Agregar columna activo a proveedores
ALTER TABLE public.proveedores 
ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

-- 2. Agregar columna activo a categorias (si no existe)
ALTER TABLE public.categorias 
ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

-- 3. Crear índices para mejorar rendimiento de filtros
CREATE INDEX IF NOT EXISTS idx_proveedores_activo ON public.proveedores(activo);
CREATE INDEX IF NOT EXISTS idx_categorias_activo ON public.categorias(activo);

-- Verificación
SELECT 'proveedores' as tabla, count(*) as total, count(*) FILTER (WHERE activo = true) as activos 
FROM public.proveedores
UNION ALL
SELECT 'categorias' as tabla, count(*) as total, count(*) FILTER (WHERE activo = true) as activos 
FROM public.categorias;
