DO $$
DECLARE
    v_empresa UUID;
BEGIN
    SELECT id INTO v_empresa FROM public.empresas ORDER BY created_at ASC LIMIT 1;

    IF v_empresa IS NOT NULL THEN
        UPDATE public.bodegas SET empresa_id = v_empresa WHERE empresa_id IS NULL;
    END IF;
END;
$$;
