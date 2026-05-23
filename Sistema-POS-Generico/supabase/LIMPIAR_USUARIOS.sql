-- =====================================================
-- LIMPIAR USUARIOS - Reasignar datos y eliminar
-- =====================================================
-- Reasigna todos los datos al nuevo admin antes de eliminar
-- =====================================================

DO $$
DECLARE
    v_nuevo_admin_id uuid;
    v_user_id uuid;
    emails_to_delete text[] := ARRAY[
        'admin@gmail.com',
        'user@gsdm.cl',
        'prueba@gmail.com',
        'adminsuper@gmai.cl'
    ];
    v_email text;
BEGIN
    -- Obtener ID del nuevo admin
    SELECT id INTO v_nuevo_admin_id 
    FROM public.users 
    WHERE email = 'admin.prueba@pos.com';
    
    IF v_nuevo_admin_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró el usuario admin.prueba@pos.com';
    END IF;
    
    RAISE NOTICE 'Nuevo admin ID: %', v_nuevo_admin_id;
    
    -- Procesar cada usuario a eliminar
    FOREACH v_email IN ARRAY emails_to_delete
    LOOP
        SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
        
        IF v_user_id IS NOT NULL THEN
            RAISE NOTICE 'Procesando: %', v_email;
            
            -- Reasignar órdenes de compra (si existe la tabla)
            BEGIN
                UPDATE ordenes_compra 
                SET usuario_id = v_nuevo_admin_id 
                WHERE usuario_id = v_user_id;
            EXCEPTION WHEN undefined_table THEN
                RAISE NOTICE 'Tabla ordenes_compra no existe';
            END;
            
            -- Reasignar ventas
            BEGIN
                UPDATE ventas 
                SET usuario_id = v_nuevo_admin_id 
                WHERE usuario_id = v_user_id;
            EXCEPTION WHEN undefined_table THEN
                RAISE NOTICE 'Tabla ventas no existe';
            END;
            
            -- Reasignar movimientos
            BEGIN
                UPDATE movimientos 
                SET usuario_id = v_nuevo_admin_id 
                WHERE usuario_id = v_user_id;
            EXCEPTION WHEN undefined_table THEN
                RAISE NOTICE 'Tabla movimientos no existe';
            END;
            
            -- Reasignar recepciones
            BEGIN
                UPDATE recepciones 
                SET usuario_id = v_nuevo_admin_id 
                WHERE usuario_id = v_user_id;
            EXCEPTION WHEN undefined_table THEN
                RAISE NOTICE 'Tabla recepciones no existe';
            END;
            
            -- Reasignar pre_ventas (vendedor)
            BEGIN
                UPDATE pre_ventas 
                SET vendedor_id = v_nuevo_admin_id 
                WHERE vendedor_id = v_user_id;
            EXCEPTION WHEN undefined_table THEN
                RAISE NOTICE 'Tabla pre_ventas no existe';
            END;
            
            -- Reasignar pre_ventas (cajero)
            BEGIN
                UPDATE pre_ventas 
                SET cajero_id = v_nuevo_admin_id 
                WHERE cajero_id = v_user_id;
            EXCEPTION WHEN undefined_table THEN
                RAISE NOTICE 'Tabla pre_ventas no existe';
            END;
            
            -- Reasignar movimientos de cuenta corriente
            BEGIN
                UPDATE movimientos_cuenta_corriente 
                SET usuario_id = v_nuevo_admin_id 
                WHERE usuario_id = v_user_id;
            EXCEPTION WHEN undefined_table THEN
                RAISE NOTICE 'Tabla movimientos_cuenta_corriente no existe';
            END;
            
            -- Ahora sí eliminar el usuario
            DELETE FROM public.users WHERE id = v_user_id;
            DELETE FROM auth.users WHERE id = v_user_id;
            
            RAISE NOTICE '✅ Eliminado: %', v_email;
        ELSE
            RAISE NOTICE '❌ No encontrado: %', v_email;
        END IF;
    END LOOP;
    
    RAISE NOTICE '🎉 Limpieza completada';
END $$;


-- Verificar resultado
SELECT 
    name,
    email,
    role,
    created_at
FROM public.users
ORDER BY role DESC, created_at;


-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- Solo deberían quedar 2 usuarios:
-- 
-- name              | email                      | role
-- ------------------|----------------------------|----------
-- Admin Prueba      | admin.prueba@pos.com       | admin
-- Empleado Prueba   | empleado.prueba@pos.com    | empleado
-- =====================================================
