# 🧪 Plan de Pruebas QA - Proyecto Market (Nuevas Funcionalidades)

Este documento sirve como guía para validar las funcionalidades críticas implementadas recientemente: **Dashboard Inteligente, Multi-Códigos y Auditoría de Inventario.**

---

## 🟢 Prueba 1: Dashboard Inteligente
**Objetivo:** Verificar que el tablero principal cargue correctamente y muestre datos coherentes sin errores técnicos.

*   [ ] **Carga Inicial:** Al entrar a `/`, no deben aparecer errores rojos (Toast errors) ni errores en consola (F12).
*   [ ] **Métricas KPI:** Los contadores (Total Productos, Críticos, Vencidos) deben tener números razonables (no ceros si hay datos).
*   [ ] **Top Ventas:** Debe aparecer el widget "Top Ventas (Mes Actual)". Si hay ventas este mes, deben listarse los productos.
*   [ ] **Gráfico de Tendencia:** El gráfico de área verde debe mostrarse.
*   [ ] **Movimientos Recientes:** La tabla debe mostrar las últimas entradas/salidas con fechas correctas.

---

## 🟢 Prueba 2: Maestro de Productos (Multi-Códigos)
**Objetivo:** Validar la configuración de Packs/Cajas en el sistema.

1.  **Crear Producto Base:**
    *   Ir a `Inventario` -> `Maestro de Productos`.
    *   Nuevo Producto: "Bebida Cola 3L".
    *   Unidad de Medida: Seleccionar **UN**.
    *   Código Barra: `780001` (ejemplo).
    *   Precio: `$1.000`.
2.  **Agregar Presentación (Pack):**
    *   Editar el producto recién creado.
    *   Sección "Presentaciones / Packs": Agregar nueva presentación.
    *   Nombre: "Pack x6".
    *   Código Barra: `780002` (Diferente al base).
    *   Factor Conversión: `6`.
    *   Precio: `$5.000` (Opcional, si es más barato por mayor).
    *   Guardar.
3.  **Verificación:** El producto debe aparecer en la lista y al editarlo, debe mostrar el pack configurado.

---

## 🟢 Prueba 3: Punto de Venta (POS) con Multi-Códigos
**Objetivo:** Verificar que el sistema descuente el stock correctamente al vender packs.

*Pre-requisito: Tener stock del producto creado en Prueba 2.*

1.  **Venta Unitaria:**
    *   Ir a `Punto de Venta`.
    *   Buscar/Escanear `780001` (Unidad).
    *   Debe agregar "Bebida Cola 3L" al carrito (Precio $1.000).
2.  **Venta Pack:**
    *   Buscar/Escanear `780002` (Pack).
    *   Debe agregar "Bebida Cola 3L - Pack x6" al carrito (Precio $5.000).
3.  **Finalizar Venta:**
    *   Pagar con Efectivo.
4.  **Validación de Stock (Crucial):**
    *   Ir a `Inventario`.
    *   Buscar el producto.
    *   El stock debió bajar en **7 unidades** (1 de la unidad suelta + 6 del pack).

---

## 🟢 Prueba 4: Auditoría de Inventario (Inventario Ciego)
**Objetivo:** Probar el flujo completo de toma de inventario físico.

1.  **Crear Sesión:**
    *   Ir a `Inventario` -> `Auditoría`.
    *   "Nueva Sesión de Inventario" -> Nombre: "Test QA 1".
2.  **Conteo (Modo Ciego):**
    *   Entrar a la sesión (Estado: Abierta -> Comenzar Conteo).
    *   El sistema muestra pantalla de escaneo.
    *   Escanear `780001` (Unidad). Ingresar cantidad física: 10.
    *   Escanear `780002` (Pack). Ingresar cantidad física: 1 (El sistema internamente sumará 6 unidades base).
3.  **Finalizar y Reporte:**
    *   Click en "Finalizar Conteo".
    *   El sistema cambia a estado "Revisión".
    *   Revisar la tabla de discrepancias.
    *   Debe mostrar:
        *   Stock Sistema: X (lo que quedó de la venta anterior).
        *   Conteo Físico Total: 16 (10 unidades + 1 pack*6).
        *   Diferencia: (16 - X).
4.  **Aplicar Ajuste:**
    *   Si el botón "Aplicar Ajuste" está disponible (funcionalidad avanzada), probarlo. Si no, verificar que el reporte sea correcto.

---

## 🐞 Reporte de Errores
Si encuentras algún fallo, por favor indica:
1.  En qué paso ocurrió.
2.  Mensaje de error (si hay).
3.  Captura de pantalla o descripción de lo que sucedió vs lo esperado.
