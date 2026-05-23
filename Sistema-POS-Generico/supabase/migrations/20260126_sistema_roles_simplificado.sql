-- =====================================================
-- MIGRACIÓN: Sistema de Roles Simplificado
-- Fecha: 2026-01-26
-- Descripción: Actualiza el sistema de roles a solo 2:
--   - admin: Acceso total
--   - empleado: Acceso operativo (sin módulos sensibles)
-- =====================================================

-- 1. Verificar roles actuales
SELECT DISTINCT role FROM users;

-- 2. Actualizar usuarios con rol 'vendedor' a 'empleado'
UPDATE users 
SET role = 'empleado' 
WHERE role = 'vendedor';

-- 3. Verificar que no existan otros roles
-- Si hay roles diferentes a 'admin' o 'empleado', actualízalos manualmente

-- 4. Agregar constraint para validar solo roles permitidos
ALTER TABLE users 
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE users 
ADD CONSTRAINT users_role_check 
CHECK (role IN ('admin', 'empleado'));

-- 5. Verificar resultado final
SELECT 
    role,
    COUNT(*) as cantidad_usuarios
FROM users
GROUP BY role
ORDER BY role;

-- =====================================================
-- NOTAS IMPORTANTES:
-- =====================================================
-- PERMISOS POR ROL:
--
-- ADMIN (Acceso Total):
--   - Dashboard
--   - POS (Caja)
--   - Pre-Ventas
--   - Cajero Pre-Ventas
--   - Historial Ventas ✓ (Solo Admin)
--   - Clientes
--   - Bodega (Inventario)
--   - Recepción
--   - Ajustes de Stock ✓ (Solo Admin)
--   - Movimientos ✓ (Solo Admin)
--   - Maestros de Productos
--   - Usuarios ✓ (Solo Admin)
--   - Tesorería
--
-- EMPLEADO (Acceso Operativo):
--   - Dashboard
--   - POS (Caja)
--   - Pre-Ventas
--   - Cajero Pre-Ventas
--   - Clientes
--   - Bodega (Inventario)
--   - Recepción
--   - Maestros de Productos
--   - Tesorería
--
-- MÓDULOS RESTRINGIDOS (Solo Admin):
--   ❌ Historial Ventas
--   ❌ Ajustes de Stock (Auditorías)
--   ❌ Movimientos (Kardex completo)
--   ❌ Usuarios (Gestión de usuarios)
-- =====================================================
