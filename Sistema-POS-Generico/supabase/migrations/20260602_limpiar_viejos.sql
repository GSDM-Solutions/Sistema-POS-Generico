UPDATE public.maestro_productos
SET activo = false
WHERE empresa_id IN (SELECT id FROM public.empresas ORDER BY created_at ASC LIMIT 1)
  AND (codigo_barra IS NULL OR codigo_barra = '' OR char_length(codigo_barra) < 5);
