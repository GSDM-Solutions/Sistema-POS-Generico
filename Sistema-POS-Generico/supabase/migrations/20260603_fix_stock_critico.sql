DO $$
DECLARE
    v_empresa UUID;
BEGIN
    SELECT id INTO v_empresa FROM public.empresas ORDER BY created_at ASC LIMIT 1;
    UPDATE public.maestro_productos SET stock_critico = 5 WHERE empresa_id = v_empresa AND stock_critico > 50;
END;
$$;
