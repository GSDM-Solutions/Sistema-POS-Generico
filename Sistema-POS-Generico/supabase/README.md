# Migraciones Supabase

## Orden de ejecución

Ejecutar en el SQL Editor de Supabase en este orden:

| # | Archivo | Descripción |
|---|---------|-------------|
| 1 | `20260117000000_init_schema.sql` | Esquema inicial (tablas base, RPCs) |
| 2 | `20260119000000_commercial_update.sql` | Adaptación a sistema comercial |
| 3 | `20260120000000_inventory_core.sql` | Core de inventario |
| 4 | `20260125000000_preventas_v1.sql` | Pre-ventas |
| 5 | `20260125000001_preventas_cajero.sql` | Cajero pre-ventas |
| 6 | `20260125_PREVENTAS_COMPLETO.sql` | Pre-ventas completo |
| 7 | `20260126_sistema_roles_simple.sql` | Roles y permisos |
| 8 | `20260202_multi_empresa_paso_1_al_5.sql` | Multi-empresa (5 archivos) |
| 9 | `20260202_fix_audit_module.sql` | Fix módulo auditoría |
| 10 | `20260203000000_consolidated_fixes.sql` | Fixes consolidados |
| 11 | **`20260518_bodegas_consolidado.sql`** | 🆕 Sistema de bodegas + traslados |

## Migración de bodegas (20260518)

La número 11 implementa la segregación en 2 bodegas:

```
[Recepción] → [Bodega General] → [Traslado] → [Bodega Venta] → [POS]
```

### Tablas nuevas
- `bodegas` — catálogo de bodegas (General, Venta)
- `traslados` — movimientos entre bodegas
- `traslado_items` — detalle de productos trasladados

### RPCs nuevas/actualizadas
- `get_inventory_por_bodega(bodega_id)` — inventario filtrado
- `search_products_pos_bodega(query)` — búsqueda solo en bodega venta
- `crear_traslado(destino, items, usuario)` — mueve stock entre bodegas
- `listar_traslados()` — historial de traslados
- `procesar_recepcion_mercaderia(...)` — actualizada con `p_bodega_id`

### Archivos legacy (reemplazados por el consolidado)
- `20260514_bodegas_traslados.sql`
- `20260514_bodegas_rpc.sql`
- `20260514_bodegas_entries.sql`
- `20260514_bodegas_rls_fix.sql`
