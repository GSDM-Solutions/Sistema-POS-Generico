-- =====================================================
-- SOLUCIÓN TEMPORAL: Desactivar TODOS los triggers
-- =====================================================
-- El error "Database error querying schema" sugiere que
-- hay un trigger o función que está fallando durante el login
-- =====================================================

-- Ver TODOS los triggers en auth.users
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
  AND event_object_table = 'users';


-- Desactivar TODOS los triggers en auth.users
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_schema = 'auth'
          AND event_object_table = 'users'
    LOOP
        EXECUTE format('ALTER TABLE auth.users DISABLE TRIGGER %I', r.trigger_name);
        RAISE NOTICE 'Desactivado trigger: %', r.trigger_name;
    END LOOP;
END $$;


-- Verificar que se desactivaron
SELECT 
    trigger_name,
    tgenabled as status
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'auth'
  AND c.relname = 'users';


-- =====================================================
-- AHORA INTENTA HACER LOGIN
-- =====================================================
-- Si funciona, el problema es uno de los triggers
-- Luego podemos reactivarlos uno por uno para identificar cuál falla
-- =====================================================


-- =====================================================
-- PARA REACTIVAR LOS TRIGGERS (si el login funciona):
-- =====================================================

/*
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_schema = 'auth'
          AND event_object_table = 'users'
    LOOP
        EXECUTE format('ALTER TABLE auth.users ENABLE TRIGGER %I', r.trigger_name);
        RAISE NOTICE 'Reactivado trigger: %', r.trigger_name;
    END LOOP;
END $$;
*/


-- =====================================================
-- ALTERNATIVA: Verificar los logs de Supabase
-- =====================================================
-- 
-- Ve a Supabase Dashboard:
-- 1. Logs → Postgres Logs
-- 2. Busca errores recientes
-- 3. Copia el mensaje de error completo
-- 
-- Esto nos dirá exactamente qué está fallando
-- =====================================================
