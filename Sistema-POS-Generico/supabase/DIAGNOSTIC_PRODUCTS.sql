-- Diagnóstico de Productos y Búsqueda
-- 1. Ver si hay productos con stock para alguna empresa
SELECT 
    p.id, 
    p.stock_actual, 
    mp.nombre, 
    p.empresa_id 
FROM public.productos p
JOIN public.maestro_productos mp ON p.maestro_producto_id = mp.id
LIMIT 10;

-- 2. Ver si la función search_products_pos devuelve algo (simulando query vacía o 'a')
-- Nota: Esto puede fallar si se ejecuta como postgres en lugar de un usuario con empresa, 
-- pero nos dará pistas si la función depende de auth.uid()
