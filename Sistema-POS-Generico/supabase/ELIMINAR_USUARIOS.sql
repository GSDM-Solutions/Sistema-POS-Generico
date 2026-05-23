-- =====================================================
-- ELIMINAR USUARIOS
-- =====================================================
-- IMPORTANTE: Ten cuidado al eliminar usuarios
-- Siempre verifica antes de ejecutar
-- =====================================================

-- ========== PASO 1: VER TODOS LOS USUARIOS ==========
-- Ejecuta esto primero para ver qué usuarios tienes
SELECT 
    u.id,
    u.name,
    u.email,
    u.role,
    u.created_at
FROM public.users u
ORDER BY u.created_at DESC;


-- ========== PASO 2: ELIMINAR USUARIOS ESPECÍFICOS ==========
-- Opción A: Eliminar por EMAIL (RECOMENDADO)

-- Ejemplo: Eliminar usuario específico
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Obtener ID del usuario
    SELECT id INTO v_user_id 
    FROM auth.users 
    WHERE email = 'PEGA_AQUI_EL_EMAIL@ejemplo.com';
    
    IF v_user_id IS NOT NULL THEN
        -- Eliminar de public.users
        DELETE FROM public.users WHERE id = v_user_id;
        
        -- Eliminar de auth.users
        DELETE FROM auth.users WHERE id = v_user_id;
        
        RAISE NOTICE 'Usuario eliminado correctamente';
    ELSE
        RAISE NOTICE 'Usuario no encontrado';
    END IF;
END $$;


-- ========== PASO 3: ELIMINAR MÚLTIPLES USUARIOS ==========
-- Opción B: Eliminar varios usuarios a la vez

DO $$
DECLARE
    v_email text;
    v_user_id uuid;
    emails_to_delete text[] := ARRAY[
        'auditor@hospital.cl',
        'bodega@hospital.cl',
        'enfermero@hospital.cl',
        'viewer@hospital.cl'
        -- Agrega más emails aquí si necesitas
    ];
BEGIN
    FOREACH v_email IN ARRAY emails_to_delete
    LOOP
        SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
        
        IF v_user_id IS NOT NULL THEN
            DELETE FROM public.users WHERE id = v_user_id;
            DELETE FROM auth.users WHERE id = v_user_id;
            RAISE NOTICE 'Eliminado: %', v_email;
        ELSE
            RAISE NOTICE 'No encontrado: %', v_email;
        END IF;
    END LOOP;
END $$;


-- ========== PASO 4: ELIMINAR TODOS EXCEPTO ADMINS ==========
-- ⚠️ PELIGROSO: Elimina todos los usuarios que NO sean admin

-- DESCOMENTAR SOLO SI ESTÁS SEGURO:
/*
DO $$
DECLARE
    v_user record;
BEGIN
    FOR v_user IN 
        SELECT id, email FROM public.users WHERE role != 'admin'
    LOOP
        DELETE FROM public.users WHERE id = v_user.id;
        DELETE FROM auth.users WHERE id = v_user.id;
        RAISE NOTICE 'Eliminado: %', v_user.email;
    END LOOP;
END $$;
*/


-- ========== PASO 5: ELIMINAR USUARIOS DE PRUEBA DEL SISTEMA MÉDICO ==========
-- Elimina los usuarios del sistema médico antiguo

DO $$
DECLARE
    v_user_id uuid;
    emails_medicos text[] := ARRAY[
        'auditor@hospital.cl',
        'bodega@hospital.cl',
        'enfermero@hospital.cl',
        'viewer@hospital.cl',
        'admin@hospital.cl'  -- ⚠️ Quita esta línea si quieres mantener este admin
    ];
    v_email text;
BEGIN
    FOREACH v_email IN ARRAY emails_medicos
    LOOP
        SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
        
        IF v_user_id IS NOT NULL THEN
            DELETE FROM public.users WHERE id = v_user_id;
            DELETE FROM auth.users WHERE id = v_user_id;
            RAISE NOTICE 'Eliminado: %', v_email;
        END IF;
    END LOOP;
END $$;


-- ========== PASO 6: VERIFICACIÓN FINAL ==========
-- Ver usuarios que quedaron
SELECT 
    u.name,
    u.email,
    u.role,
    u.created_at
FROM public.users u
ORDER BY u.role DESC, u.created_at DESC;


-- =====================================================
-- NOTAS IMPORTANTES:
-- =====================================================
-- 
-- 1. SIEMPRE ejecuta el PASO 1 primero para ver qué usuarios tienes
-- 
-- 2. Para eliminar un usuario específico:
--    - Usa el PASO 2 y reemplaza el email
-- 
-- 3. Para eliminar varios usuarios:
--    - Usa el PASO 3 y lista los emails en el array
-- 
-- 4. NUNCA elimines el último usuario admin
-- 
-- 5. Los usuarios eliminados NO se pueden recuperar
-- 
-- 6. Si un usuario tiene datos relacionados (ventas, movimientos, etc.),
--    puede dar error. En ese caso, mejor desactivar el usuario
--    en lugar de eliminarlo.
-- 
-- =====================================================


-- ========== ALTERNATIVA: DESACTIVAR EN LUGAR DE ELIMINAR ==========
-- Si prefieres desactivar usuarios en lugar de eliminarlos:

-- Primero, agrega columna 'activo' si no existe:
-- ALTER TABLE public.users ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT true;

-- Luego desactiva usuarios:
-- UPDATE public.users SET activo = false WHERE email = 'usuario@ejemplo.com';

-- Y modifica la función get_users para filtrar solo activos:
-- WHERE u.activo = true
