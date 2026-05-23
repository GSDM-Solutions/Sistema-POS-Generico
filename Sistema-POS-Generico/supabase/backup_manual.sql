-- ============================================
-- BACKUP COMPLETO - Copia todo y pega en un .sql
-- Ejecutar en SQL Editor de Supabase
-- ============================================

-- ESQUEMA: genera los CREATE TABLE
SELECT 
  'CREATE TABLE IF NOT EXISTS ' || table_name || ' (' ||
  string_agg(column_name || ' ' || 
    CASE 
      WHEN data_type = 'character varying' THEN 'TEXT'
      WHEN data_type = 'timestamp with time zone' THEN 'TIMESTAMPTZ'
      WHEN data_type = 'numeric' AND numeric_precision IS NOT NULL THEN 'NUMERIC(' || numeric_precision || ',' || COALESCE(numeric_scale,0) || ')'
      ELSE UPPER(data_type)
    END ||
    CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
    CASE WHEN column_default IS NOT NULL THEN ' DEFAULT ' || column_default ELSE '' END,
    ', ' ORDER BY ordinal_position
  ) || ');' AS create_table
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY table_name
ORDER BY table_name;

-- DATOS: exporta cada tabla como INSERT
-- Reemplaza 'nombre_tabla' por cada tabla y ejecuta uno por uno
SELECT 'INSERT INTO ' || 'empresas' || ' (' || 
  string_agg(column_name, ', ') || ') VALUES ' ||
  string_agg(
    '(' || 
    string_agg(
      CASE 
        WHEN data_type IN ('character varying','text','uuid','date','timestamp with time zone','timestamp without time zone') 
        THEN '''' || COALESCE(column_name, 'NULL') || ''''
        ELSE COALESCE(column_name::text, 'NULL')
      END, ', '
    ) || ')', ', '
  ) || ';'
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'empresas';

-- O más simple: usa la opción "Download CSV" en cada tabla desde el Table Editor
