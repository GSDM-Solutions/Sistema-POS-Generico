-- =====================================================
-- MIGRACIÓN CORREGIDA: Sistema de Roles Simplificado
-- Fecha: 2026-01-26
-- Descripción: Actualiza el sistema de roles a solo 2:
--   - admin: Acceso total
--   - empleado: Acceso operativo (sin módulos sensibles)
-- =====================================================

-- PASO 1: Verificar roles actuales
-- Ejecuta esto primero para ver qué roles existen
SELECT 
    role,
    COUNT(*) as cantidad,
    STRING_AGG(name, ', ') as usuarios
FROM users
GROUP BY role
ORDER BY role;

-- PASO 2: Actualizar TODOS los roles no válidos a 'empleado'
-- Esto incluye: vendedor, cajero, bodega, auditor, enfermero, visualizador, etc.
UPDATE users 
SET role = 'empleado' 
WHERE role NOT IN ('admin', 'empleado');

-- PASO 3: Verificar que todos los usuarios tengan roles válidos
-- Esta consulta debe retornar 0 filas
SELECT 
    id,
    name,
    email,
    role
FROM users
WHERE role NOT IN ('admin', 'empleado');

-- PASO 4: Solo si el paso 3 retorna 0 filas, ejecutar esto:
-- Eliminar constraint anterior si existe
ALTER TABLE users 
DROP CONSTRAINT IF EXISTS users_role_check;

-- Agregar nuevo constraint
ALTER TABLE users 
ADD CONSTRAINT users_role_check 
CHECK (role IN ('admin', 'empleado'));

-- PASO 5: Verificar resultado final
SELECT 
    role,
    COUNT(*) as cantidad_usuarios,
    STRING_AGG(name, ', ') as nombres
FROM users
GROUP BY role
ORDER BY role;

-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- role      | cantidad_usuarios | nombres
-- ----------|-------------------|------------------
-- admin     | 1 o más          | Admin, ...
-- empleado  | 0 o más          | Juan, María, ...
-- =====================================================
