-- =====================================================
-- MIGRACIÓN: FIX DASHBOARD STATS
-- =====================================================
-- Fecha: 2026-05-18
-- Descripción: Actualiza la función get_dashboard_stats para que retorne la estructura JSONB
-- exacta que el frontend (React) espera procesar para los gráficos y widgets.
-- =====================================================

DROP FUNCTION IF EXISTS public.get_dashboard_stats();
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_empresa_id UUID;
    v_stats jsonb;
BEGIN
    v_empresa_id := public.get_user_empresa_id();
    
    SELECT jsonb_build_object(
        'total_products', (
            SELECT COUNT(*)
            FROM public.maestro_productos
            WHERE empresa_id = v_empresa_id AND activo = true
        ),
        'critical_stock_products', (
            SELECT COUNT(*)
            FROM public.maestro_productos mp
            LEFT JOIN (
                SELECT maestro_producto_id, SUM(stock_actual) as total_stock
                FROM public.productos
                WHERE empresa_id = v_empresa_id
                GROUP BY maestro_producto_id
            ) p ON mp.id = p.maestro_producto_id
            WHERE mp.empresa_id = v_empresa_id
              AND mp.activo = true
              AND mp.controla_stock = true
              AND COALESCE(p.total_stock, 0) <= mp.stock_critico
        ),
        'total_ventas_hoy', (
            SELECT COALESCE(SUM(total), 0)
            FROM public.ventas
            WHERE empresa_id = v_empresa_id
              AND DATE(creado_en AT TIME ZONE 'America/Santiago') = DATE(NOW() AT TIME ZONE 'America/Santiago')
        ),
        'total_fiado_pendiente', (
            SELECT COALESCE(SUM(saldo_actual), 0)
            FROM public.clientes
            WHERE empresa_id = v_empresa_id
        ),
        'expired_products', (
            SELECT COUNT(*)
            FROM public.productos
            WHERE empresa_id = v_empresa_id
              AND stock_actual > 0
              AND fecha_vencimiento < (NOW() AT TIME ZONE 'America/Santiago')::date
        ),
        'quarantine_products', 0,
        'recent_movements', COALESCE((
            SELECT jsonb_agg(mov) FROM (
                SELECT 
                    m.id::text,
                    mp.nombre as producto_nombre,
                    p.numero_lote,
                    m.tipo_movimiento,
                    m.cantidad,
                    m.condicion,
                    COALESCE(u.email, 'Sistema') as usuario_nombre,
                    m.motivo,
                    m.creado_en as fecha
                FROM public.movimientos m
                JOIN public.productos p ON m.producto_id = p.id
                JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
                LEFT JOIN public.users u ON m.usuario_id = u.id
                WHERE m.empresa_id = v_empresa_id
                ORDER BY m.creado_en DESC
                LIMIT 10
            ) mov
        ), '[]'::jsonb),
        'category_distribution', COALESCE((
            SELECT jsonb_agg(cat) FROM (
                SELECT 
                    COALESCE(categoria, 'Sin Categoría') as name,
                    COUNT(*) as value
                FROM public.maestro_productos
                WHERE empresa_id = v_empresa_id AND activo = true
                GROUP BY categoria
                ORDER BY value DESC
            ) cat
        ), '[]'::jsonb),
        'top_products', COALESCE((
            SELECT jsonb_agg(top) FROM (
                SELECT 
                    mp.nombre,
                    SUM(dv.cantidad) as total_vendido,
                    SUM(dv.subtotal) as total_ingreso
                FROM public.detalle_ventas dv
                JOIN public.ventas v ON dv.venta_id = v.id
                JOIN public.productos p ON dv.producto_id = p.id
                JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
                WHERE v.empresa_id = v_empresa_id
                GROUP BY mp.id, mp.nombre
                ORDER BY total_vendido DESC
                LIMIT 5
            ) top
        ), '[]'::jsonb),
        'sales_trend', COALESCE((
            SELECT jsonb_agg(trend) FROM (
                SELECT 
                    TO_CHAR(DATE(creado_en AT TIME ZONE 'America/Santiago'), 'DD/MM') as fecha,
                    SUM(total) as total
                FROM public.ventas
                WHERE empresa_id = v_empresa_id
                  AND creado_en >= (NOW() AT TIME ZONE 'America/Santiago') - INTERVAL '7 days'
                GROUP BY DATE(creado_en AT TIME ZONE 'America/Santiago')
                ORDER BY DATE(creado_en AT TIME ZONE 'America/Santiago') ASC
            ) trend
        ), '[]'::jsonb)
    ) INTO v_stats;
    
    RETURN v_stats;
END;
$$;
