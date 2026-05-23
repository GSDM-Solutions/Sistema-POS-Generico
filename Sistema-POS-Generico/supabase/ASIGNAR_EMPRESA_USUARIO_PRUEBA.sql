-- =====================================================
-- VERIFICAR Y ASIGNAR empresa_id AL USUARIO DE PRUEBA
-- =====================================================

-- 1. Ver usuarios y sus empresas
SELECT 
    id,
    email,
    name,
    role,
    empresa_id,
    created_at
FROM public.users
ORDER BY created_at DESC;

-- 2. Asignar empresa_id al usuario prueba@empresa.com
UPDATE public.users
SET empresa_id = '17b1cf9d-d91b-4e96-a553-ab9441cd342d'::uuid
WHERE email = 'prueba@empresa.com'
  AND (empresa_id IS NULL OR empresa_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- 3. Verificar
SELECT 
    u.email,
    u.name,
    u.role,
    e.nombre_comercial as empresa,
    u.empresa_id
FROM public.users u
LEFT JOIN public.empresas e ON u.empresa_id = e.id
ORDER BY u.created_at DESC;
