-- =====================================================
-- MIGRACIÓN MULTI-EMPRESA - PASO 1: CREAR TABLA EMPRESAS
-- =====================================================
-- Fecha: 2026-02-02
-- Descripción: Crea la tabla empresas (tenants) y empresa default
-- =====================================================

-- 1. Crear tabla empresas
CREATE TABLE IF NOT EXISTS public.empresas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre_comercial TEXT NOT NULL,
    rut TEXT UNIQUE,
    razon_social TEXT,
    direccion TEXT,
    telefono TEXT,
    email TEXT,
    logo_url TEXT,
    plan TEXT DEFAULT 'basico' CHECK (plan IN ('basico', 'premium', 'enterprise')),
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Crear índices
CREATE INDEX idx_empresas_activo ON public.empresas(activo);
CREATE INDEX idx_empresas_rut ON public.empresas(rut);

-- 3. Crear empresa DEFAULT para datos existentes
INSERT INTO public.empresas (
    id,
    nombre_comercial,
    rut,
    razon_social,
    plan,
    activo
) VALUES (
    '00000000-0000-0000-0000-000000000001'::uuid,
    'Empresa Principal',
    '00000000-0',
    'Empresa Principal',
    'premium',
    true
) ON CONFLICT (id) DO NOTHING;

-- 4. Verificar
SELECT * FROM public.empresas;

-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- Tabla empresas creada con 1 registro (Empresa Principal)
-- ID: 00000000-0000-0000-0000-000000000001
-- =====================================================
