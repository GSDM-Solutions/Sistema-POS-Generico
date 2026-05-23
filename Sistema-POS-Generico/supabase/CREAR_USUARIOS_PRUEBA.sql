-- =====================================================
-- CREAR USUARIOS DE PRUEBA
-- =====================================================
-- Este script crea 2 usuarios de prueba:
-- 1. Admin de prueba
-- 2. Empleado de prueba
-- =====================================================

-- IMPORTANTE: Cambia las contraseñas después de crear los usuarios

-- ========== USUARIO 1: ADMIN DE PRUEBA ==========
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Crear usuario en auth.users
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        'admin.prueba@pos.com',
        crypt('Admin123!', gen_salt('bf')), -- Contraseña: Admin123!
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"name":"Admin Prueba"}',
        now(),
        now(),
        '',
        ''
    )
    RETURNING id INTO v_user_id;

    -- Crear registro en public.users
    INSERT INTO public.users (id, email, name, role, created_at, updated_at)
    VALUES (
        v_user_id,
        'admin.prueba@pos.com',
        'Admin Prueba',
        'admin',
        now(),
        now()
    );

    RAISE NOTICE 'Usuario Admin creado: admin.prueba@pos.com / Admin123!';
END $$;


-- ========== USUARIO 2: EMPLEADO DE PRUEBA ==========
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Crear usuario en auth.users
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        'empleado.prueba@pos.com',
        crypt('Empleado123!', gen_salt('bf')), -- Contraseña: Empleado123!
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"name":"Empleado Prueba"}',
        now(),
        now(),
        '',
        ''
    )
    RETURNING id INTO v_user_id;

    -- Crear registro en public.users
    INSERT INTO public.users (id, email, name, role, created_at, updated_at)
    VALUES (
        v_user_id,
        'empleado.prueba@pos.com',
        'Empleado Prueba',
        'empleado',
        now(),
        now()
    );

    RAISE NOTICE 'Usuario Empleado creado: empleado.prueba@pos.com / Empleado123!';
END $$;


-- ========== VERIFICACIÓN ==========
SELECT 
    u.name,
    u.email,
    u.role,
    u.created_at
FROM public.users u
WHERE u.email IN ('admin.prueba@pos.com', 'empleado.prueba@pos.com')
ORDER BY u.role DESC;


-- =====================================================
-- CREDENCIALES DE ACCESO:
-- =====================================================
-- 
-- ADMIN:
-- Email: admin.prueba@pos.com
-- Password: Admin123!
-- 
-- EMPLEADO:
-- Email: empleado.prueba@pos.com
-- Password: Empleado123!
-- 
-- ⚠️ IMPORTANTE: Cambia estas contraseñas en producción
-- =====================================================
