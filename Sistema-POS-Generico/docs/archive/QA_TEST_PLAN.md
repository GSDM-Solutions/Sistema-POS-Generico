# Plan de Pruebas Integrales (QA) - Supermercado Market ERP

Este documento detalla los pasos para validar el flujo completo del sistema, asegurando que la Tesorería, el POS y el Inventario funcionen sincronizados.

## 1. Tesorería: Apertura de Caja
*Objetivo: Iniciar el turno y definir el fondo de cambio.*

1.  Navega a **Tesorería (Caja)** en el menú lateral.
2.  Deberías ver la pantalla de "Apertura de Caja".
3.  Ingresa un Monto Inicial (ej: `$50,000`) y haz clic en **Abrir Caja**.
4.  **Resultado Esperado**:
    *   La pantalla cambia a "Caja Abierta".
    *   Se muestra la hora de apertura y el fondo inicial.

## 2. POS: Ventas y Validaciones
*Objetivo: Procesar ventas y verificar que exigen caja abierta (para efectivo).*

1.  Navega a **Punto de Venta (Caja)**.
2.  Agrega un producto al carrito (ej: Leche, Precio $1,000).
3.  Haz clic en **Cobrar**.
4.  **Prueba A: Venta Efectivo Correcta**:
    *   Selecciona Medio de Pago: **EFECTIVO**.
    *   Tipo Documento: **BOLETA**.
    *   Confirma la venta.
    *   **Resultado**: Venta exitosa. Se descuenta stock y se suma dinero a la caja.
5.  *(Opcional)* **Prueba B: Venta Transferencia**:
    *   Realiza otra venta.
    *   Selecciona Medio de Pago: **TRANSFERENCIA**.
    *   **Resultado**: Venta exitosa. No afecta el arqueo de efectivo de caja.

## 3. Inventario y Auditoría
*Objetivo: Verificar que el stock se mueve correctamente.*

1.  Navega a **Control de Bodega** o **Dashboard**.
2.  Busca el producto vendido.
3.  **Resultado Esperado**: El stock debe haber disminuido en la cantidad vendida.

## 4. Tesorería: Cierre y Arqueo
*Objetivo: Cuadrar la caja y detectar diferencias.*

1.  Vuelve a **Tesorería (Caja)**.
2.  Verás el panel de "Cierre de Caja".
3.  **Cálculo Manual**:
    *   Monto Inicial: `$50,000`
    *   Ventas Efectivo: `$1,000` (de la Prueba A).
    *   Total Físico Esperado: `$51,000`.
4.  **Prueba de Cuadratura**:
    *   En "Total Contado", ingresa `$51,000`.
    *   Haz clic en **Cerrar Turno**.
5.  **Resultado Esperado**:
    *   Pantalla de Resumen: "Caja Cerrada".
    *   Diferencia: `$0` (Cuadrado Perfecto).
    *   Estado: Verde.

## 5. Pruebas de Borde (Opcional)
*   Intenta vender en Efectivo **SIN** abrir la caja (debería dar error).
*   Intenta cerrar la caja con un monto menor (ej: $50,000) para ver si marca "Faltante" (Rojo).
