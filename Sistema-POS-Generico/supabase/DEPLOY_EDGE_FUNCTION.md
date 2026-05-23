# =====================================================
# GUÍA: DESPLEGAR EDGE FUNCTION PARA CREAR USUARIOS
# =====================================================

## PASO 1: Instalar Supabase CLI (si no lo tienes)
npm install -g supabase

## PASO 2: Login en Supabase
supabase login

## PASO 3: Vincular tu proyecto
supabase link --project-ref ftpygefvqahrxrzplbro

## PASO 4: Desplegar la función
supabase functions deploy create-user

## PASO 5: Verificar que se desplegó
# La función estará disponible en:
# https://ftpygefvqahrxrzplbro.supabase.co/functions/v1/create-user

# =====================================================
# ALTERNATIVA: Desplegar desde Dashboard
# =====================================================

Si prefieres no usar CLI:

1. Ve a Supabase Dashboard
2. Edge Functions → Create a new function
3. Nombre: create-user
4. Copia el contenido de supabase/functions/create-user/index.ts
5. Deploy

# =====================================================
# TESTING
# =====================================================

# Probar la función con curl:
curl -X POST \
  https://ftpygefvqahrxrzplbro.supabase.co/functions/v1/create-user \
  -H "Authorization: Bearer TU_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User",
    "role": "empleado",
    "empresa_id": "uuid-de-empresa"
  }'
