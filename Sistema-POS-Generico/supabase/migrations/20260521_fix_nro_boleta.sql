ALTER TABLE public.ventas ADD COLUMN IF NOT EXISTS nro_boleta TEXT;

CREATE OR REPLACE FUNCTION public.actualizar_nro_boleta(
    p_venta_id UUID,
    p_nro_boleta TEXT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.ventas
    SET nro_boleta = p_nro_boleta
    WHERE id = p_venta_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.actualizar_nro_boleta TO authenticated;
