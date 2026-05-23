DO $$
DECLARE
    v_general UUID;
    v_venta UUID;
    v_dup RECORD;
BEGIN
    SELECT id INTO v_general FROM public.bodegas WHERE tipo = 'general' ORDER BY created_at ASC LIMIT 1;
    SELECT id INTO v_venta FROM public.bodegas WHERE tipo = 'venta' ORDER BY created_at ASC LIMIT 1;

    IF v_general IS NULL THEN
        INSERT INTO public.bodegas (nombre, tipo) VALUES ('Bodega General', 'general') RETURNING id INTO v_general;
    END IF;

    IF v_venta IS NULL THEN
        INSERT INTO public.bodegas (nombre, tipo) VALUES ('Bodega de Venta', 'venta') RETURNING id INTO v_venta;
    END IF;

    UPDATE public.bodegas SET nombre = 'Bodega General' WHERE id = v_general;
    UPDATE public.bodegas SET nombre = 'Bodega de Venta' WHERE id = v_venta;

    FOR v_dup IN SELECT id FROM public.bodegas WHERE tipo = 'general' AND id != v_general
    LOOP
        UPDATE public.productos SET bodega_id = v_general WHERE bodega_id = v_dup.id;
        UPDATE public.traslados SET bodega_origen_id = v_general WHERE bodega_origen_id = v_dup.id;
        UPDATE public.traslados SET bodega_destino_id = v_general WHERE bodega_destino_id = v_dup.id;
        UPDATE public.inventory_sessions SET bodega_id = v_general WHERE bodega_id = v_dup.id;
        DELETE FROM public.bodegas WHERE id = v_dup.id;
    END LOOP;

    FOR v_dup IN SELECT id FROM public.bodegas WHERE tipo = 'venta' AND id != v_venta
    LOOP
        UPDATE public.productos SET bodega_id = v_venta WHERE bodega_id = v_dup.id;
        UPDATE public.traslados SET bodega_origen_id = v_venta WHERE bodega_origen_id = v_dup.id;
        UPDATE public.traslados SET bodega_destino_id = v_venta WHERE bodega_destino_id = v_dup.id;
        UPDATE public.inventory_sessions SET bodega_id = v_venta WHERE bodega_id = v_dup.id;
        DELETE FROM public.bodegas WHERE id = v_dup.id;
    END LOOP;

    DELETE FROM public.bodegas WHERE tipo NOT IN ('general', 'venta');
END;
$$;
