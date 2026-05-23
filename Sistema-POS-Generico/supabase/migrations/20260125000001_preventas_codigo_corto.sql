-- =====================================================
-- MEJORA: CÓDIGO CORTO PARA PRE-VENTAS
-- Fecha: 25 Enero 2026
-- =====================================================

-- 1. Agregar columna para código corto único
ALTER TABLE public.pre_ventas 
ADD COLUMN IF NOT EXISTS codigo_preventa VARCHAR(20) UNIQUE;

-- 2. Crear secuencia para generar códigos incrementales
CREATE SEQUENCE IF NOT EXISTS preventa_codigo_seq START 1000;

-- 3. Función para generar código único (PV-XXXX)
CREATE OR REPLACE FUNCTION generar_codigo_preventa()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo TEXT;
    v_numero INT;
BEGIN
    v_numero := nextval('preventa_codigo_seq');
    v_codigo := 'PV-' || LPAD(v_numero::TEXT, 4, '0');
    RETURN v_codigo;
END;
$$;

-- 4. Trigger para asignar código automáticamente al crear
CREATE OR REPLACE FUNCTION asignar_codigo_preventa()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.codigo_preventa IS NULL THEN
        NEW.codigo_preventa := generar_codigo_preventa();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_asignar_codigo_preventa ON public.pre_ventas;
CREATE TRIGGER trg_asignar_codigo_preventa
    BEFORE INSERT ON public.pre_ventas
    FOR EACH ROW
    EXECUTE FUNCTION asignar_codigo_preventa();

-- 5. Función RPC para buscar pre-venta por código (para el POS)
CREATE OR REPLACE FUNCTION public.buscar_preventa_por_codigo(
    p_codigo TEXT
) RETURNS TABLE (
    id UUID,
    codigo_preventa TEXT,
    vendedor_nombre TEXT,
    cliente_id UUID,
    cliente_nombre TEXT,
    estado estado_preventa,
    items JSONB,
    total NUMERIC,
    tipo_venta tipo_venta,
    notas_vendedor TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pv.id,
        pv.codigo_preventa,
        u.email AS vendedor_nombre,
        pv.cliente_id,
        c.nombre AS cliente_nombre,
        pv.estado,
        pv.items,
        pv.total,
        pv.tipo_venta,
        pv.notas_vendedor,
        pv.created_at
    FROM public.pre_ventas pv
    LEFT JOIN public.users u ON pv.vendedor_id = u.id
    LEFT JOIN public.clientes c ON pv.cliente_id = c.id
    WHERE pv.codigo_preventa = UPPER(p_codigo)
    AND pv.estado = 'PENDIENTE'; -- Solo pendientes
END;
$$;

GRANT EXECUTE ON FUNCTION public.buscar_preventa_por_codigo TO authenticated;

-- 6. Actualizar función listar_preventas para incluir código
DROP FUNCTION IF EXISTS public.listar_preventas(UUID, estado_preventa, BOOLEAN);

CREATE OR REPLACE FUNCTION public.listar_preventas(
    p_usuario_id UUID,
    p_estado estado_preventa DEFAULT NULL,
    p_solo_propias BOOLEAN DEFAULT FALSE
) RETURNS TABLE (
    id UUID,
    codigo_preventa TEXT,
    vendedor_nombre TEXT,
    vendedor_id UUID,
    cajero_nombre TEXT,
    cliente_nombre TEXT,
    estado estado_preventa,
    total NUMERIC,
    tipo_venta tipo_venta,
    items JSONB,
    notas_vendedor TEXT,
    notas_cajero TEXT,
    created_at TIMESTAMPTZ,
    enviada_at TIMESTAMPTZ,
    confirmada_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pv.id,
        pv.codigo_preventa,
        u_vendedor.email AS vendedor_nombre,
        pv.vendedor_id,
        u_cajero.email AS cajero_nombre,
        c.nombre AS cliente_nombre,
        pv.estado,
        pv.total,
        pv.tipo_venta,
        pv.items,
        pv.notas_vendedor,
        pv.notas_cajero,
        pv.created_at,
        pv.enviada_at,
        pv.confirmada_at
    FROM public.pre_ventas pv
    LEFT JOIN public.users u_vendedor ON pv.vendedor_id = u_vendedor.id
    LEFT JOIN public.users u_cajero ON pv.cajero_id = u_cajero.id
    LEFT JOIN public.clientes c ON pv.cliente_id = c.id
    WHERE 
        (p_estado IS NULL OR pv.estado = p_estado)
        AND (
            NOT p_solo_propias 
            OR pv.vendedor_id = p_usuario_id
        )
    ORDER BY 
        CASE 
            WHEN pv.estado = 'PENDIENTE' THEN 1
            WHEN pv.estado = 'BORRADOR' THEN 2
            ELSE 3
        END,
        pv.created_at DESC;
END;
$$;

-- 7. Actualizar códigos existentes (si hay pre-ventas sin código)
UPDATE public.pre_ventas
SET codigo_preventa = generar_codigo_preventa()
WHERE codigo_preventa IS NULL;

-- =====================================================
-- FIN DE MIGRACIÓN
-- =====================================================
