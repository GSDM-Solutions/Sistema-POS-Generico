-- Semilla de Datos Iniciales (Seed Data)
-- Ejecutar esto para tener datos básicos para pruebas.

-- 1. Proveedores
INSERT INTO public.proveedores (nombre, rut, contacto, telefono, email, direccion)
VALUES 
    ('Distribuidora Central', '76.123.456-7', 'Roberto Gomez', '+56911112222', 'contacto@distribuidora.cl', 'Av. Industrial 1000')
ON CONFLICT DO NOTHING;

-- 2. Categorías (Si usas una tabla separada, sino directo en producto)
-- Asumimos texto libre o tabla categorias. Verifiquemos si existe categorias...
-- En la migración inicial: maestro_productos tiene campo 'categoria' text.

-- 3. Maestro de Productos
INSERT INTO public.maestro_productos (nombre, descripcion, codigo_barra, categoria, stock_critico, precio_venta)
VALUES
    ('Arroz Grado 2 - 1kg', 'Arroz blanco grano largo', '780123456001', 'Abarrotes', 10, 1200),
    ('Aceite Vegetal 900ml', 'Aceite maravilla', '780123456002', 'Abarrotes', 5, 2500),
    ('Leche Entera 1L', 'Leche caja larga vida', '780123456003', 'Lacteos', 10, 1100),
    ('Bebida Cola 3L', 'Bebida gaseosa', '780123456004', 'Bebidas', 10, 3200)
ON CONFLICT DO NOTHING;

-- 4. Clientes
INSERT INTO public.clientes (rut, nombre, telefono, direccion, cupo_credito, saldo_actual)
VALUES
    ('11.111.111-1', 'Juan Perez', '+5699999999', 'Calle Falsa 123', 50000, 0),
    ('22.222.222-2', 'Maria Gonzalez', '+5698888888', 'Av. Siempreviva 742', 100000, 0)
ON CONFLICT DO NOTHING;

-- Nota: No insertamos STOCK (lotes) directamente. 
-- El stock se debe generar vía "Recepción de Orden de Compra" para probar el flujo correcto.
