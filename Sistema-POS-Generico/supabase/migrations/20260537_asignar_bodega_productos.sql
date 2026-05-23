DO $$
DECLARE
    emp RECORD;
    v_bodega UUID;
BEGIN
    FOR emp IN SELECT id FROM public.empresas
    LOOP
        SELECT id INTO v_bodega FROM public.bodegas
        WHERE tipo = 'general' AND empresa_id = emp.id
        ORDER BY created_at ASC LIMIT 1;

        IF v_bodega IS NOT NULL THEN
            UPDATE public.productos SET bodega_id = v_bodega
            WHERE empresa_id = emp.id AND bodega_id IS NULL;
        END IF;
    END LOOP;
END;
$$;
