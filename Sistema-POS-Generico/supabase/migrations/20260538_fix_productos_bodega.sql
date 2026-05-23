DO $$
DECLARE
    emp RECORD;
    v_bodega_gral UUID;
    v_bodega_vta UUID;
BEGIN
    FOR emp IN SELECT id FROM public.empresas
    LOOP
        SELECT id INTO v_bodega_gral FROM public.bodegas
        WHERE tipo = 'general' AND empresa_id = emp.id
        ORDER BY created_at ASC LIMIT 1;

        SELECT id INTO v_bodega_vta FROM public.bodegas
        WHERE tipo = 'venta' AND empresa_id = emp.id
        ORDER BY created_at ASC LIMIT 1;

        IF v_bodega_gral IS NOT NULL THEN
            UPDATE public.productos SET bodega_id = v_bodega_gral
            WHERE empresa_id = emp.id;
        END IF;
    END LOOP;
END;
$$;
