import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Verificar que el usuario es superadmin
        const authHeader = req.headers.get('Authorization')!
        const token = authHeader.replace('Bearer ', '')

        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        // Verificar que el usuario actual es superadmin
        const { data: { user } } = await supabaseClient.auth.getUser(token)
        if (!user) {
            throw new Error('No autenticado')
        }

        const { data: userData } = await supabaseClient
            .from('users')
            .select('role')
            .eq('id', user.id)
            .single()

        if (userData?.role !== 'superadmin') {
            throw new Error('Solo Super Administradores pueden crear usuarios')
        }

        // Obtener datos del request
        const { email, password, name, role, empresa_id } = await req.json()

        // Crear cliente con Service Role Key
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
            {
                auth: {
                    autoRefreshToken: false,
                    persistSession: false
                }
            }
        )

        // Crear usuario en Auth
        const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: {
                name,
                role,
                empresa_id
            }
        })

        if (authError) throw authError

        // Actualizar datos en tabla users (el trigger ya lo creó)
        const { error: updateError } = await supabaseAdmin
            .from('users')
            .update({
                name,
                role,
                empresa_id
            })
            .eq('id', authData.user.id)

        if (updateError) throw updateError

        return new Response(
            JSON.stringify({
                success: true,
                user: {
                    id: authData.user.id,
                    email: authData.user.email,
                    name,
                    role,
                    empresa_id
                }
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200
            }
        )
    } catch (error) {
        return new Response(
            JSON.stringify({
                success: false,
                error: error.message
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400
            }
        )
    }
})
