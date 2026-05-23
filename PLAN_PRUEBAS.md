# Plan de Pruebas — GESTIÓN PRO

## Entorno
| Componente | URL |
|------------|-----|
| Admin App | http://localhost:5173 |
| POS App | http://localhost:5175/pos |
| Base de datos | Supabase (ftpygefvqahrxrzplbro) |

## Roles de prueba
| Rol | Usuario | App |
|-----|---------|-----|
| Admin | admin@test.com | Admin |
| Supervisor | supervisor@test.com | Admin |
| Cajero | cajero@test.com | POS |

---

## 1. AUTENTICACIÓN

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 1.1 | Login admin | Entrar con admin en 5173 | Dashboard con sidebar, todas las secciones |
| 1.2 | Login cajero en 5173 | Entrar con cajero en admin | Redirige a POS o sidebar limitado |
| 1.3 | Login cajero en POS | Entrar con cajero en 5175/pos | Pantalla completa, sin sidebar, solo POS |
| 1.4 | Login inválido | Credenciales incorrectas | Toast de error |
| 1.5 | Cerrar sesión POS | Botón 🚪 en esquina superior | Vuelve a login |

---

## 2. POS — OPERACIONES DE VENTA

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 2.1 | Escanear producto | Pasar código de barra | Producto se agrega al carro automáticamente |
| 2.2 | Agregar manual | Escribir nombre y Enter | Producto se agrega al carro |
| 2.3 | Producto agotado | Producto con stock=0 | Botón deshabilitado, no se agrega |
| 2.4 | Aumentar cantidad | + en carrito | Cantidad sube, stock se descuenta |
| 2.5 | Disminuir cantidad | - en carrito | Cantidad baja, mínimo 1 |
| 2.6 | Eliminar item | X en carrito → confirmar | Item removido |
| 2.7 | Vaciar carrito F2 | Botón F2 o tecla F2 | Carrito vacío, sonido |
| 2.8 | Consultar precio F3 | Botón F3 o tecla F3 | Modal price checker |
| 2.9 | Cobrar F4 | Botón F4 o tecla F4 | Modal de pago se abre |
| 2.10 | Venta efectivo | Seleccionar CASH, Cobrar | Venta registrada, recibo mostrado |
| 2.11 | Venta transferencia | Seleccionar TRANSFER | Venta registrada |
| 2.12 | Venta fiado | Seleccionar CREDIT, elegir cliente | Validación de cupo, venta registrada |
| 2.13 | Venta con boleta | Ingresar N° boleta | Boleta asociada a la venta |
| 2.14 | Cotización | Seleccionar QUOTE | Cotización generada, no descuenta stock |
| 2.15 | Sonidos | Agregar, quitar, cobrar | Suena beep correspondiente |

---

## 3. POS — INVENTARIO Y STOCK

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 3.1 | Stock visible | Buscar producto | Muestra solo productos de bodega venta |
| 3.2 | Stock se descuenta | Vender producto | Stock baja en DB tras venta |
| 3.3 | No vende sin stock | Intentar vender agotado | Error "Stock insuficiente" |
| 3.4 | Refresh automático | Esperar 5 min | Productos se refrescan |

---

## 4. POS — MODO OFFLINE

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 4.1 | Activar offline | Desconectar WiFi/Ethernet | Banner amarillo "SIN CONEXIÓN" |
| 4.2 | Venta offline | Vender sin internet | Toast "Venta guardada (sin conexión)" |
| 4.3 | Ventas pendientes | Ver banner | Muestra "Ventas pendientes: X" |
| 4.4 | Reconectar | Conectar internet | Banner desaparece |
| 4.5 | Sincronizar | Click "Sincronizar ahora" o esperar 30s | Ventas se envían a Supabase |
| 4.6 | Sincronización automática | Esperar 30s conectado | Ventas pendientes se sincronizan solas |
| 4.7 | Stock local offline | Vender offline → reconectar | Stock en DB refleja todas las ventas |

---

## 5. ADMIN — GESTIÓN DE PRODUCTOS

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 5.1 | Listar maestros | Ir a Maestros | Tabla con productos, crear, editar, eliminar |
| 5.2 | Crear producto | Nuevo producto con código de barra | Producto aparece en búsqueda POS |
| 5.3 | Editar producto | Cambiar precio | Precio se actualiza en POS |
| 5.4 | Eliminar producto | Desactivar/eliminar | Ya no aparece en búsquedas |
| 5.5 | Categorías | Crear/editar/eliminar categoría | Se refleja en maestro |

---

## 6. ADMIN — INVENTARIO

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 6.1 | Ver inventario | Ir a Inventario | Lista productos con stock por bodega |
| 6.2 | Filtrar por bodega | Seleccionar "Bodega de Venta" | Solo muestra productos de esa bodega |
| 6.3 | Filtrar "Todas" | Seleccionar "Todas las bodegas" | Muestra todas |
| 6.4 | Productos críticos | Ir a Dashboard | Sección stock crítico visible |
| 6.5 | Próximos a vencer | Ir a sección vencimiento | Productos con fecha cercana |

---

## 7. ADMIN — TRASLADOS

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 7.1 | Listar traslados | Ir a Traslados | Tabla vacía o con traslados existentes |
| 7.2 | Crear traslado | Seleccionar productos, destino | Traslado creado, stock se mueve |
| 7.3 | Validar stock origen | Intentar trasladar más de lo disponible | Error "Stock insuficiente" |

---

## 8. ADMIN — ENTRADAS (RECEPCIÓN)

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 8.1 | Nueva recepción | Ingresar documento, proveedor, productos | Stock aumenta, movimiento registrado |
| 8.2 | Número de lote | Ingresar lote y vencimiento | Se crea con esos datos |
| 8.3 | Recepción en bodega | Seleccionar bodega destino | Stock va a bodega correcta |

---

## 9. ADMIN — PRE-VENTAS

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 9.1 | Crear pre-venta | Ir a Pre-Ventas → Nueva | Código PV-XXXX generado |
| 9.2 | Enviar pre-venta | Cambiar estado a PENDIENTE | Disponible para cajero |
| 9.3 | Cargar pre-venta en POS | Escanear PV-XXXX en POS | Productos se cargan al carro |
| 9.4 | Confirmar pre-venta | Cobrar en POS | Pre-venta marcada CONFIRMADA |
| 9.5 | Rechazar pre-venta | Cajero rechaza | Estado RECHAZADA con motivo |
| 9.6 | Cancelar pre-venta | Vendedor cancela | Estado CANCELADA |

---

## 10. ADMIN — VENTAS Y CLIENTES

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 10.1 | Historial ventas | Ir a Historial Ventas | Lista de ventas con filtros |
| 10.2 | Crear cliente | Ir a Clientes → Nuevo | Cliente creado con RUT único |
| 10.3 | Cupo de crédito | Cliente con cupo definido | Validación en venta fiado |
| 10.4 | Saldo actual | Venta fiado a cliente | Saldo se actualiza |

---

## 11. MULTI-EMPRESA

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 11.1 | Aislamiento productos | Login empresa A → buscar | Solo ve productos empresa A |
| 11.2 | Aislamiento clientes | Login empresa A → clientes | Solo ve clientes empresa A |
| 11.3 | Aislamiento ventas | Login empresa A → historial | Solo ve ventas empresa A |
| 11.4 | Aislamiento movimientos | Login empresa A → Kardex | Solo ve movimientos empresa A |
| 11.5 | Aislamiento bodegas | Login empresa A → inventario | Solo ve bodegas empresa A |

---

## 12. PWA

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 12.1 | Instalar POS | Chrome → ⊕ → Instalar | App en escritorio, standalone |
| 12.2 | Instalar Admin | Chrome → ⊕ → Instalar | App en escritorio, standalone |
| 12.3 | Abrir sin internet | Abrir app instalada offline | Carga interfaz (cacheada) |
| 12.4 | Navegar offline admin | Navegar secciones sin internet | Páginas cacheadas visibles |

---

## 13. RENDIMIENTO

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 13.1 | Carga inicial POS | Abrir POS | < 3 segundos |
| 13.2 | Carga inicial Admin | Abrir Admin | < 5 segundos |
| 13.3 | Búsqueda rápida | Escribir en buscador | Resultados en < 1 segundo |
| 13.4 | Venta rápida | Escanear 5 productos, cobrar | < 10 segundos total |

---

## 14. ERRORES Y BORDES

| # | Prueba | Pasos | Esperado |
|---|--------|-------|----------|
| 14.1 | Sin productos | POS sin stock en bodega venta | Mensaje "Escanea un producto" |
| 14.2 | Red lenta | Simular throttling | La app sigue funcionando, toast de error si timeout |
| 14.3 | Sesión expirada | Dejar abierto > 1 hora | Redirige a login automáticamente |
| 14.4 | Doble click cobrar | Clic rápido 2 veces en Cobrar | Solo se procesa una venta (lock) |
| 14.5 | Recargar página | F5 durante venta | Carrito se pierde (esperado) |

---

## Resultados

| Fecha | Tester | Pasaron | Fallaron | Observaciones |
|-------|--------|---------|----------|---------------|
|       |        |         |          |               |
