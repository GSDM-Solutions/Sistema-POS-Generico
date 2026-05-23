-- =====================================================
-- AUDITORÍA EXHAUSTIVA - RESULTADO FINAL
-- =====================================================
-- Análisis completo del código fuente vs base de datos
-- =====================================================

-- ========== TABLAS QUE SE USAN (MANTENER) ==========

-- ✅ categorias - SE USA
--    Usado en: ProductMaster.tsx, Entries.tsx
--    Función: Gestión de categorías de productos
--    Registros: 12
--    MANTENER ✅

-- ✅ inventory_sessions - SE USA
--    Usado en: InventoryAudit.tsx
--    Función: Sesiones de auditoría física de inventario
--    Registros: 4
--    MANTENER ✅

-- ✅ inventory_counts - SE USA
--    Usado en: InventoryAudit.tsx
--    Función: Conteos físicos de inventario
--    Registros: 19
--    MANTENER ✅


-- ========== TABLAS QUE NO SE USAN (ELIMINAR) ==========

-- ❌ pacientes - NO SE USA
--    Solo aparece en archived_routes.md (archivado)
--    Registros: 0
--    ELIMINAR ❌

-- ❌ entregas - NO SE USA
--    Solo aparece en archived_routes.md (archivado)
--    Registros: 0
--    ELIMINAR ❌

-- ❌ entregas_items - NO SE USA
--    Relacionada con entregas (archivado)
--    Registros: 0
--    ELIMINAR ❌

-- ❌ auditoria_preguntas - NO SE USA
--    No aparece en ningún archivo del código
--    Registros: 0
--    ELIMINAR ❌

-- ❌ auditorias_checklist - NO SE USA
--    No aparece en ningún archivo del código
--    Registros: 0
--    ELIMINAR ❌

-- ❌ items_venta - NO SE USA
--    No aparece en ningún archivo del código
--    Registros: 0
--    ELIMINAR ❌

-- ❌ movimientos_stock - NO SE USA
--    No aparece en ningún archivo del código
--    Registros: 1
--    ELIMINAR ❌

-- ❌ inventory_session_results - NO SE USA
--    No aparece en ningún archivo del código
--    Registros: 0
--    ELIMINAR ❌


-- =====================================================
-- RESUMEN FINAL:
-- =====================================================
-- MANTENER:
-- ✅ categorias (12 registros) - SE USA en ProductMaster
-- ✅ inventory_sessions (4 registros) - SE USA en InventoryAudit
-- ✅ inventory_counts (19 registros) - SE USA en InventoryAudit
--
-- ELIMINAR:
-- ❌ pacientes (0 registros)
-- ❌ entregas (0 registros)
-- ❌ entregas_items (0 registros)
-- ❌ auditoria_preguntas (0 registros)
-- ❌ auditorias_checklist (0 registros)
-- ❌ items_venta (0 registros)
-- ❌ movimientos_stock (1 registro)
-- ❌ inventory_session_results (0 registros)
-- =====================================================
