-- =====================================================
-- FUNCIÓN RPC PARA CREAR USUARIOS (SUPERADMIN)
-- =====================================================

CREATE OR REPLACE FUNCTION public.create_user_as_superadmin(
    p_email text,
    p_password text,
    p_name text,
    p_role text,
    p_empresa_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Verificar que el usuario actual es superadmin
    IF NOT is_superadmin() THEN
        RAISE EXCEPTION 'Solo Super Administradores pueden crear usuarios';
    END IF;

    -- Crear usuario en auth.users usando extensión
    -- NOTA: Esto requiere que tengas habilitada la extensión supabase_auth_admin
    -- Si no está disponible, los usuarios deben crearse manualmente en Supabase Dashboard
    
    -- Por ahora, retornamos un mensaje para crear manualmente
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Crear usuario manualmente en Supabase Dashboard > Authentication > Users',
        'email', p_email,
        'name', p_name,
        'role', p_role,
        'empresa_id', p_empresa_id
    );
END;
$$;

-- =====================================================
-- FUNCIÓN ALTERNATIVA: INVITAR USUARIO
-- =====================================================
-- Esta función genera un link de invitación que puedes enviar por email

CREATE OR REPLACE FUNCTION public.invite_user_as_superadmin(
    p_email text,
    p_name text,
    p_role text,
    p_empresa_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verificar que el usuario actual es superadmin
    IF NOT is_superadmin() THEN
        RAISE EXCEPTION 'Solo Super Administradores pueden invitar usuarios';
    END IF;

    -- Insertar registro pendiente en users
    INSERT INTO public.users (id, email, name, role, empresa_id)
    VALUES (
        gen_random_uuid(),
        p_email,
        p_name,
        p_role,
        p_empresa_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Usuario pre-registrado. Crear cuenta en Supabase Dashboard',
        'email', p_email
    );
END;
$$;
