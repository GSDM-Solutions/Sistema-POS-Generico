-- =====================================================
-- HABILITAR CREACIÓN DE USUARIOS DESDE EL FRONTEND
-- =====================================================

-- Para crear usuarios desde el frontend, necesitas usar Edge Functions
-- porque supabase.auth.admin requiere la Service Role Key

-- PASO 1: Crear una Edge Function en Supabase
-- Ve a: Dashboard > Edge Functions > Create a new function
-- Nombre: create-user

-- PASO 2: Código de la Edge Function (TypeScript):
/*
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { email, password, name, role, empresa_id } = await req.json()

    // Crear cliente con Service Role Key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Crear usuario en Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    })

    if (authError) throw authError

    // Actualizar datos en tabla users
    const { error: updateError } = await supabaseAdmin
      .from('users')
      .update({ name, role, empresa_id })
      .eq('id', authData.user.id)

    if (updateError) throw updateError

    return new Response(
      JSON.stringify({ success: true, user: authData.user }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
*/

-- PASO 3: Desplegar la función
-- En terminal local:
-- supabase functions deploy create-user

-- PASO 4: La función estará disponible en:
-- https://[TU-PROJECT-ID].supabase.co/functions/v1/create-user

-- =====================================================
-- ALTERNATIVA RÁPIDA: Usar signUp con auto-confirmación
-- =====================================================

-- Habilitar auto-confirmación de emails en Supabase:
-- Dashboard > Authentication > Settings > Email Auth
-- Desactiva "Enable email confirmations"

-- Luego puedes usar signUp directamente desde el frontend
