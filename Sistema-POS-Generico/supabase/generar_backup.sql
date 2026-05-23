-- ============================================
-- GENERAR BACKUP RÁPIDO DESDE SQL EDITOR
-- ============================================
-- Ejecuta cada bloque por separado y copia el resultado

-- 1. Esquema de todas las tablas
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- 2. Datos de cada tabla (uno por uno)
SELECT * FROM public.empresas;
SELECT * FROM public.users;
SELECT * FROM public.maestro_productos;
SELECT * FROM public.productos;
SELECT * FROM public.clientes;
SELECT * FROM public.ventas;
SELECT * FROM public.detalle_ventas;
SELECT * FROM public.preventas;
SELECT * FROM public.preventa_items;
SELECT * FROM public.movimientos;
SELECT * FROM public.proveedores;
SELECT * FROM public.categorias;
SELECT * FROM public.ordenes_compra;
SELECT * FROM public.orden_compra_items;
SELECT * FROM public.bodegas;
SELECT * FROM public.traslados;
SELECT * FROM public.traslado_items;

-- 3. Funciones RPC existentes
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
ORDER BY routine_name;
