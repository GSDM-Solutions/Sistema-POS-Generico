# Plan de Trabajo Maestro: Proyecto Market (Refinado)

Este documento detalla la hoja de ruta técnica para transformar el sistema actual en una solución superior a la competencia (GlobalPOS), enfocándose en las mecánicas de supermercado real solicitadas.

## 1. Nuevos Módulos Estructurales (Lo que falta)

### A. Módulo de Inventario Masivo y Cuadratura
**El Problema:** Actualmente el ajuste es unitario. Se requiere un proceso de auditoría profesional.
**La Solución: "Sesiones de Inventario"**
1.  **Crear Sesión:** El administrador inicia un conteo (ej. "Pasillo Licores"). El sistema toma una "foto" del stock teórico en ese momento.
2.  **Conteo Físico (Blind Count):** El bodeguero escanea y cuenta lo que ve físicamente (usando pistola/handheld). No ve lo que el sistema "espera" para evitar sesgos.
3.  **Comparación y Cruce:** El sistema muestra una tabla de diferencias:
    *   *Sistema: 10 | Físico: 8 | Diferencia: -2 (Pérdida/Ajuste Negativo)*
    *   *Sistema: 5 | Físico: 6 | Diferencia: +1 (Sobrante/Ajuste Positivo)*
4.  **Consolidación:** Al "Cerrar Inventario", el sistema:
    *   Actualiza el stock real para que coincida con el físico.
    *   Genera automáticamente registros de ajuste justificados por "Diferencia de Inventario".
    *   Genera un reporte de pérdidas valorizado.

### B. Embalajes, Unidades y Códigos Enlazados (Multi-Barcode)
**El Problema:** Un producto puede venderse por unidad o por caja/pack, y tienen códigos de barra distintos.
**La Solución: Tabla de "Presentaciones de Producto"**
*   **Unidad Base:** Configurable (UN, KG, LT, MT).
*   **Códigos Hijos (Enlazados):**
    *   *Código A (Botella Aceite)* -> Multiplicador: 1. Precio Unitario: $1.000.
    *   *Código B (Caja 12 Aceites)* -> Multiplicador: 12. Precio Pack: $11.000 (Oferta).
*   **Lógica en POS:** Al escanear el Código B (Caja), el sistema carga una línea de venta que descuenta **12 unidades** del inventario base, pero cobra el precio del pack.
*   **Lógica en Recepción:** Al escanear la caja madre, permite ingresar stock en unidades masivamente (ej. Ingreso 5 cajas -> Suma 60 unidades al stock).

### C. Mantenedor de Productos Avanzado
**Mejoras Requeridas:**
*   Gestión de Unidades de Medida.
*   Gestión de Códigos alternativos (embalajes).
*   Categorización profunda para reportes.

---

## 2. Hoja de Ruta de Implementación

### Fase 1: Base de Datos y Mantenedor (Los Cimientos)
*Esta fase habilita la capacidad de soportar cajas, unidades y códigos múltiples.*
1.  **Modificar BD:** Agregar columna `unidad_medida` a `maestro_productos`.
2.  **Nueva Tabla:** Crear `producto_codigos` (id_producto, codigo_barra, cantidad_unidades, descripcion).
3.  **Actualizar UI:** Rediseñar la página `ProductMaster` para permitir agregar estos "sub-códigos" o presentaciones.

### Fase 2: Recepción y "Explosión" de Stock
*Esta fase permite que al recibir una caja, el sistema entienda que llegaron unidades.*
1.  **Actualizar `ReceiveOrder`:** Integrar la lectura de códigos de caja.
2.  **Lógica:** Si escaneo código de caja -> Preguntar "¿Cuántas cajas?" -> Multiplicar por factor (x12) -> Sumar al stock unitario.

### Fase 3: Punto de Venta (POS) Inteligente
*Esta fase permite vender la caja completa o la unidad.*
1.  **Actualizar Búsqueda POS:** Que reconozca tanto el código unitario como el de la caja.
2.  **Manejo de Stock:** Si vendo la caja, descontar la cantidad correcta (12) del stock de lotes.

### Fase 4: Auditoría y Cuadratura (El Diferenciador)
*Esta es la funcionalidad "Enterprise" que GlobalPOS cobra caro o hace mal.*
1.  **Nueva Página `InventorySession`:**
    *   Estado "Borrador" (Contando).
    *   Estado "Revisión" (Cuadrando diferencias).
    *   Estado "Aplicado" (Stock corregido).
2.  **Reporte de Mermas:** Historial de cuánto dinero se perdió en ajustes de inventario.

### Fase 5: Seguridad y Roles (Transversal)
1.  **Refinar Roles:** Cajero, Bodeguero, Admin.
2.  **Seguridad:** Pines de autorización para discrepancias grandes en inventario o anulaciones en caja.

---

## ¿Por dónde empezamos?
Recomiendo encarecidamente comenzar por la **Fase 1 (Base de Datos y Códigos)**. Sin la estructura para manejar "Caja vs Unidad", no podemos avanzar ni en la recepción ni en la venta correcta.

**¿Autorizas comenzar con la modificación de la Base de Datos para soportar multi-códigos y unidades?**
