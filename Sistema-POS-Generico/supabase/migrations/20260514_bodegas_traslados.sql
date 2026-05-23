-- ============================================
-- MIGRACIÓN: Sistema de Bodegas y Traslados
-- ============================================

-- 1. Tabla de Bodegas
CREATE TABLE IF NOT EXISTS public.bodegas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('general', 'venta')),
    empresa_id UUID REFERENCES public.empresas(id),
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Insertar bodegas por defecto
INSERT INTO public.bodegas (nombre, tipo) VALUES
    ('Bodega General', 'general'),
    ('Bodega de Venta', 'venta')
ON CONFLICT DO NOTHING;

-- 2. Agregar bodega_id a productos (cada lote pertenece a una bodega)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'productos' AND column_name = 'bodega_id'
    ) THEN
        ALTER TABLE public.productos ADD COLUMN bodega_id UUID REFERENCES public.bodegas(id);
        -- Por defecto, todos los productos existentes van a Bodega General
        UPDATE public.productos SET bodega_id = (SELECT id FROM public.bodegas WHERE tipo = 'general' LIMIT 1);
    END IF;
END $$;

-- 3. Tabla de Traslados (movimientos entre bodegas)
CREATE TABLE IF NOT EXISTS public.traslados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bodega_origen_id UUID NOT NULL REFERENCES public.bodegas(id),
    bodega_destino_id UUID NOT NULL REFERENCES public.bodegas(id),
    usuario_id UUID REFERENCES auth.users(id),
    estado TEXT DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'COMPLETADO', 'CANCELADO')),
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    completado_at TIMESTAMPTZ,
    CONSTRAINT chk_bodegas_diferentes CHECK (bodega_origen_id <> bodega_destino_id)
);

-- 4. Tabla de Items de Traslado
CREATE TABLE IF NOT EXISTS public.traslado_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    traslado_id UUID NOT NULL REFERENCES public.traslados(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES public.productos(id),
    cantidad NUMERIC(10,3) NOT NULL CHECK (cantidad > 0),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Índices
CREATE INDEX IF NOT EXISTS idx_productos_bodega ON public.productos(bodega_id);
CREATE INDEX IF NOT EXISTS idx_traslados_origen ON public.traslados(bodega_origen_id);
CREATE INDEX IF NOT EXISTS idx_traslados_destino ON public.traslados(bodega_destino_id);
CREATE INDEX IF NOT EXISTS idx_traslado_items_traslado ON public.traslado_items(traslado_id);
