# Plan de Pruebas - Sistema POS Multi-Empresa

**Fecha de Creación:** 2026-02-03  
**Versión:** 1.0  
**Objetivo:** Validar el correcto funcionamiento del sistema POS con soporte multi-empresa

---

## 📋 Instrucciones Generales

- Marcar con ✅ las pruebas exitosas
- Marcar con ❌ las pruebas fallidas (agregar descripción del error)
- Marcar con ⏭️ las pruebas omitidas
- Anotar observaciones relevantes en cada sección

---

## 1. 🔐 Autenticación y Usuarios

### 1.1 Login
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 1.1.1 | Login con credenciales válidas | ⬜ | |
| 1.1.2 | Login con contraseña incorrecta (debe mostrar error) | ⬜ | |
| 1.1.3 | Login con usuario inexistente | ⬜ | |
| 1.1.4 | Logout correcto | ⬜ | |

### 1.2 Gestión de Usuarios (Solo Admin)
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 1.2.1 | Crear nuevo usuario (rol: vendedor) | ⬜ | |
| 1.2.2 | Crear nuevo usuario (rol: admin) | ⬜ | |
| 1.2.3 | Editar usuario existente | ⬜ | |
| 1.2.4 | Desactivar usuario | ⬜ | |
| 1.2.5 | Verificar que vendedor NO puede acceder a gestión de usuarios | ⬜ | |

---

## 2. 🛒 Punto de Venta (POS)

### 2.1 Búsqueda de Productos
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 2.1.1 | Buscar producto por nombre parcial | ⬜ | |
| 2.1.2 | Buscar producto por código de barras | ⬜ | |
| 2.1.3 | Verificar que muestra stock disponible | ⬜ | |
| 2.1.4 | Verificar que muestra fecha de vencimiento | ⬜ | |
| 2.1.5 | Verificar que muestra precio correcto | ⬜ | |

### 2.2 Carrito de Compras
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 2.2.1 | Agregar producto al carrito (click) | ⬜ | |
| 2.2.2 | Agregar producto con código de barras (Enter) | ⬜ | |
| 2.2.3 | Aumentar cantidad de producto | ⬜ | |
| 2.2.4 | Disminuir cantidad de producto | ⬜ | |
| 2.2.5 | Eliminar producto del carrito | ⬜ | |
| 2.2.6 | Verificar cálculo correcto del total | ⬜ | |
| 2.2.7 | No permitir agregar más stock del disponible | ⬜ | |

### 2.3 Procesamiento de Ventas
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 2.3.1 | Venta EFECTIVO sin cliente (anónima) | ⬜ | |
| 2.3.2 | Venta TRANSFERENCIA sin cliente | ⬜ | |
| 2.3.3 | Venta FIADO con cliente seleccionado | ⬜ | |
| 2.3.4 | Venta FACTURA con cliente empresa | ⬜ | |
| 2.3.5 | Verificar descuento de stock tras venta | ⬜ | |
| 2.3.6 | Verificar registro en movimientos | ⬜ | |
| 2.3.7 | Generar COTIZACIÓN (sin descontar stock) | ⬜ | |
| 2.3.8 | Venta fiado excediendo cupo (Admin puede forzar) | ⬜ | |
| 2.3.9 | Venta fiado excediendo cupo (Vendedor NO puede) | ⬜ | |

### 2.4 Consulta de Precios
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 2.4.1 | Abrir consultor de precios | ⬜ | |
| 2.4.2 | Buscar producto y ver precio | ⬜ | |

---

## 3. 📝 Pre-Ventas

### 3.1 Crear Pre-Venta (Vendedor)
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 3.1.1 | Crear nueva pre-venta como BORRADOR | ⬜ | |
| 3.1.2 | Agregar productos a la pre-venta | ⬜ | |
| 3.1.3 | Verificar generación de código (PV-XXXX) | ⬜ | |
| 3.1.4 | Enviar pre-venta a PENDIENTE | ⬜ | |
| 3.1.5 | Cancelar pre-venta propia | ⬜ | |
| 3.1.6 | Reimprimir voucher de pre-venta | ⬜ | |

### 3.2 Procesar Pre-Venta (Cajero/Admin en POS)
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 3.2.1 | Buscar pre-venta por código (PV-XXXX) en POS | ⬜ | |
| 3.2.2 | Cargar items de pre-venta al carrito | ⬜ | |
| 3.2.3 | Confirmar y procesar pre-venta como venta | ⬜ | |
| 3.2.4 | Verificar que pre-venta cambia a CONFIRMADA | ⬜ | |
| 3.2.5 | Rechazar pre-venta con motivo | ⬜ | |

### 3.3 Listado de Pre-Ventas
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 3.3.1 | Filtrar por estado (Borrador, Pendiente, etc.) | ⬜ | |
| 3.3.2 | Ver detalle de pre-venta | ⬜ | |
| 3.3.3 | Verificar aislamiento por empresa | ⬜ | |

---

## 4. 📦 Inventario

### 4.1 Gestión de Productos
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 4.1.1 | Crear nuevo producto maestro | ⬜ | |
| 4.1.2 | Editar producto existente | ⬜ | |
| 4.1.3 | Desactivar producto | ⬜ | |
| 4.1.4 | Buscar producto por nombre/código | ⬜ | |

### 4.2 Stock y Lotes
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 4.2.1 | Ver stock total por producto | ⬜ | |
| 4.2.2 | Ver detalle de lotes con vencimiento | ⬜ | |
| 4.2.3 | Agregar nuevo stock (entrada) | ⬜ | |
| 4.2.4 | Verificar registro de movimiento de entrada | ⬜ | |

### 4.3 Auditoría de Inventario
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 4.3.1 | Crear nueva sesión de auditoría | ⬜ | |
| 4.3.2 | Escanear/contar productos | ⬜ | |
| 4.3.3 | Ver diferencias (sistema vs físico) | ⬜ | |
| 4.3.4 | Aplicar ajuste de inventario | ⬜ | |
| 4.3.5 | Verificar movimientos de ajuste creados | ⬜ | |

---

## 5. 👥 Clientes

### 5.1 Gestión de Clientes
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 5.1.1 | Crear cliente persona natural | ⬜ | |
| 5.1.2 | Crear cliente empresa | ⬜ | |
| 5.1.3 | Editar datos de cliente | ⬜ | |
| 5.1.4 | Buscar cliente por nombre/RUT | ⬜ | |

### 5.2 Cuenta Corriente
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 5.2.1 | Ver saldo actual del cliente | ⬜ | |
| 5.2.2 | Registrar abono/pago | ⬜ | |
| 5.2.3 | Ver historial de movimientos | ⬜ | |
| 5.2.4 | Verificar actualización de saldo tras pago | ⬜ | |

---

## 6. 🏢 Aislamiento Multi-Empresa

### 6.1 Verificación de Datos Aislados
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 6.1.1 | Usuario de Empresa A NO ve productos de Empresa B | ⬜ | |
| 6.1.2 | Usuario de Empresa A NO ve clientes de Empresa B | ⬜ | |
| 6.1.3 | Usuario de Empresa A NO ve ventas de Empresa B | ⬜ | |
| 6.1.4 | Usuario de Empresa A NO ve pre-ventas de Empresa B | ⬜ | |
| 6.1.5 | Usuario de Empresa A NO ve usuarios de Empresa B | ⬜ | |

### 6.2 Operaciones Cruzadas (Deben Fallar)
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 6.2.1 | Intentar vender producto de otra empresa (debe fallar) | ⬜ | |
| 6.2.2 | Intentar asignar cliente de otra empresa (debe fallar) | ⬜ | |

---

## 7. 📊 Dashboard y Reportes

### 7.1 Dashboard
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 7.1.1 | Ver ventas del día | ⬜ | |
| 7.1.2 | Ver ventas del mes | ⬜ | |
| 7.1.3 | Ver productos con stock bajo | ⬜ | |
| 7.1.4 | Ver total de clientes | ⬜ | |

### 7.2 Reporte de Ventas
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 7.2.1 | Filtrar ventas por fecha | ⬜ | |
| 7.2.2 | Filtrar ventas por tipo | ⬜ | |
| 7.2.3 | Ver detalle de una venta | ⬜ | |

### 7.3 Historial de Movimientos
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 7.3.1 | Ver movimientos de entrada | ⬜ | |
| 7.3.2 | Ver movimientos de salida | ⬜ | |
| 7.3.3 | Filtrar por producto | ⬜ | |

---

## 8. 🖨️ Impresión

### 8.1 Comprobantes
| # | Caso de Prueba | Resultado | Observaciones |
|---|----------------|-----------|---------------|
| 8.1.1 | Imprimir ticket de venta | ⬜ | |
| 8.1.2 | Imprimir voucher de pre-venta | ⬜ | |
| 8.1.3 | Imprimir cotización | ⬜ | |

---

## 📝 Resumen de Resultados

| Módulo | Total | ✅ OK | ❌ Fallo | ⏭️ Omitido |
|--------|-------|-------|----------|------------|
| Autenticación | 9 | | | |
| POS | 20 | | | |
| Pre-Ventas | 11 | | | |
| Inventario | 9 | | | |
| Clientes | 8 | | | |
| Multi-Empresa | 7 | | | |
| Dashboard/Reportes | 10 | | | |
| Impresión | 3 | | | |
| **TOTAL** | **77** | | | |

---

## 🐛 Bugs Encontrados

| ID | Módulo | Descripción | Severidad | Estado |
|----|--------|-------------|-----------|--------|
| | | | | |

**Severidad:** 🔴 Crítico | 🟠 Alto | 🟡 Medio | 🟢 Bajo

---

## 📌 Notas Adicionales

_Espacio para observaciones generales durante las pruebas_

---

**Probado por:** _______________  
**Fecha de pruebas:** _______________  
**Ambiente:** Desarrollo / Producción
