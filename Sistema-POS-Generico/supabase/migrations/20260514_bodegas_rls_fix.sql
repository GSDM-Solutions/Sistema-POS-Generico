-- ============================================
-- FIX: Desactivar RLS en tablas de bodegas
-- (o crear políticas si prefieres RLS activo)
-- ============================================

-- Desactivar RLS temporalmente para debug
ALTER TABLE public.bodegas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.traslados DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.traslado_items DISABLE ROW LEVEL SECURITY;

-- Verificar que las bodegas existen
SELECT * FROM public.bodegas;

-- Si no hay registros, insertarlos manualmente
INSERT INTO public.bodegas (nombre, tipo)
SELECT 'Bodega General', 'general'
WHERE NOT EXISTS (SELECT 1 FROM public.bodegas WHERE tipo = 'general');

INSERT INTO public.bodegas (nombre, tipo)
SELECT 'Bodega de Venta', 'venta'
WHERE NOT EXISTS (SELECT 1 FROM public.bodegas WHERE tipo = 'venta');

-- Verificar que productos tienen bodega_id asignado
SELECT COUNT(*) AS total, bodega_id IS NULL AS sin_bodega
FROM public.productos
GROUP BY bodega_id IS NULL;
