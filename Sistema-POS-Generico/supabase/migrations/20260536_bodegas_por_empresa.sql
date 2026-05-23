DO $$
DECLARE
    emp RECORD;
    v_gral UUID;
    v_vta UUID;
BEGIN
    FOR emp IN SELECT id FROM public.empresas
    LOOP
        SELECT id INTO v_gral FROM public.bodegas
        WHERE tipo = 'general' AND empresa_id = emp.id
        ORDER BY created_at ASC LIMIT 1;

        IF v_gral IS NULL THEN
            INSERT INTO public.bodegas (nombre, tipo, empresa_id)
            VALUES ('Bodega General', 'general', emp.id);
        END IF;

        SELECT id INTO v_vta FROM public.bodegas
        WHERE tipo = 'venta' AND empresa_id = emp.id
        ORDER BY created_at ASC LIMIT 1;

        IF v_vta IS NULL THEN
            INSERT INTO public.bodegas (nombre, tipo, empresa_id)
            VALUES ('Bodega de Venta', 'venta', emp.id);
        END IF;
    END LOOP;

    DELETE FROM public.bodegas WHERE empresa_id IS NULL;
END;
$$;
