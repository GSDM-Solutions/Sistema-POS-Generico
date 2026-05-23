-- =====================================================
-- RESETEAR CONTRASEÑA DE USUARIO EXISTENTE
-- =====================================================
-- Vamos a resetear la contraseña de user@gsdm.cl
-- para poder hacer login y probar el sistema
-- =====================================================

-- OPCIÓN 1: Cambiar contraseña directamente en SQL
-- Esto establece la contraseña a "Admin123!"

DO $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Obtener el ID del usuario
    SELECT id INTO v_user_id 
    FROM auth.users 
    WHERE email = 'user@gsdm.cl';
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Usuario no encontrado';
    END IF;
    
    -- Actualizar la contraseña
    UPDATE auth.users
    SET 
        encrypted_password = crypt('Admin123!', gen_salt('bf')),
        updated_at = now()
    WHERE id = v_user_id;
    
    RAISE NOTICE 'Contraseña actualizada para user@gsdm.cl';
    RAISE NOTICE 'Nueva contraseña: Admin123!';
END $$;


-- Verificar que el usuario existe
SELECT 
    au.email,
    u.name,
    u.role
FROM auth.users au
LEFT JOIN public.users u ON au.id = u.id
WHERE au.email = 'user@gsdm.cl';


-- =====================================================
-- CREDENCIALES ACTUALIZADAS:
-- =====================================================
-- Email: user@gsdm.cl
-- Password: Admin123!
-- =====================================================


-- =====================================================
-- ALTERNATIVA: Resetear contraseña de otro usuario
-- =====================================================

-- Para admin@gmail.com:
/*
DO $$
DECLARE v_user_id uuid;
BEGIN
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'admin@gmail.com';
    UPDATE auth.users
    SET encrypted_password = crypt('Admin123!', gen_salt('bf')), updated_at = now()
    WHERE id = v_user_id;
    RAISE NOTICE 'Contraseña actualizada para admin@gmail.com → Admin123!';
END $$;
*/

-- Para prueba@gmail.com:
/*
DO $$
DECLARE v_user_id uuid;
BEGIN
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'prueba@gmail.com';
    UPDATE auth.users
    SET encrypted_password = crypt('Admin123!', gen_salt('bf')), updated_at = now()
    WHERE id = v_user_id;
    RAISE NOTICE 'Contraseña actualizada para prueba@gmail.com → Admin123!';
END $$;
*/


-- =====================================================
-- DESPUÉS DE EJECUTAR:
-- =====================================================
-- 1. Ejecuta el script de arriba
-- 2. Ve a la aplicación
-- 3. Intenta login con:
--    Email: user@gsdm.cl
--    Password: Admin123!
-- 
-- Si funciona, el problema es específico con los usuarios nuevos
-- =====================================================
