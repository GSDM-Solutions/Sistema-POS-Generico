-- =====================================================
-- IMPLEMENTAR SUPER ADMIN
-- =====================================================

-- 1. Agregar rol 'superadmin' a la tabla users
ALTER TABLE public.users 
  DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users 
  ADD CONSTRAINT users_role_check 
  CHECK (role IN ('admin', 'empleado', 'superadmin'));

-- 2. Crear función helper para verificar si es superadmin
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() 
        AND role = 'superadmin'
    );
END;
$$;

-- 3. Actualizar políticas de EMPRESAS para que superadmin pueda ver todas
DROP POLICY IF EXISTS "Superadmin can see all companies" ON public.empresas;
DROP POLICY IF EXISTS "Users can only see their company" ON public.empresas;
DROP POLICY IF EXISTS "Superadmin can manage all companies" ON public.empresas;

CREATE POLICY "Superadmin can see all companies"
ON public.empresas
FOR SELECT
USING (is_superadmin());

CREATE POLICY "Superadmin can manage all companies"
ON public.empresas
FOR ALL
USING (is_superadmin());

-- 4. Actualizar políticas de USERS para que superadmin pueda gestionar todos
DROP POLICY IF EXISTS "Superadmin can manage all users" ON public.users;

CREATE POLICY "Superadmin can see all users"
ON public.users
FOR SELECT
USING (
    is_superadmin() OR empresa_id = get_user_empresa_id()
);

CREATE POLICY "Superadmin can manage all users"
ON public.users
FOR ALL
USING (is_superadmin());

-- 5. Crear tu usuario como superadmin
-- REEMPLAZA 'tu-email@ejemplo.com' con tu email real
UPDATE public.users 
SET role = 'superadmin'
WHERE email = 'gsdm2025.bkp@gmail.com';

-- Verificar
SELECT email, role, empresa_id 
FROM public.users 
WHERE role = 'superadmin';

-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- Tu usuario ahora tiene rol 'superadmin'
-- Puede ver y gestionar todas las empresas
-- Puede ver y gestionar todos los usuarios
-- =====================================================
