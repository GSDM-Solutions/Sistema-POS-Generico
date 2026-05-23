# 🚀 Hoja de Ruta: Evolución a Sistema POS Comercial (Librería & Ferretería)

Este documento actúa como la guía oficial para la transformación del sistema, asegurando una transición limpia desde un modelo de gestión médica hacia uno comercial de alta eficiencia.

---

## 🏢 0. Arquitectura Genérica (Multi-Negocio)
*La base para escalar el sistema a muchos clientes.*

- [ ] **Segregación por Negocio (`business_id`):** Preparar la base de datos para que cada registro pertenezca a un cliente específico.
- [ ] **Perfiles de Máscara:** Permitir que el sistema cambie su nombre y colores según el tipo de negocio (Ferretería, Librería, Market).
- [ ] **Módulos bajo demanda:** Activar/Desactivar funciones (como fechas de vencimiento o venta por peso) con un simple interruptor en configuración.
- [ ] **Módulo de Auditoría de Salud:** Eliminar los checklists de limpieza e inspección clínica que no aplican a una ferretería/librería.
- [ ] **Roles Médicos:** Desactivar definitivamente los roles de 'Enfermero', 'Auditor' y 'Visualizador'. Consolidar en 'Admin' y 'Vendedor/Cajero'.
- [ ] **Términos Clínicos:** Cambiar "Paciente" por "Cliente" y "Insumo" por "Producto" en toda la interfaz.
- [ ] **Flujo de "Entrega":** El sistema tiene un flujo de entrega de insumos gratuito. Debe simplificarse para que todo pase por el flujo de **Venta**.

---

## 🛠️ 2. Lo que FALTA (Nuevas Funcionalidades POS)
Funcionalidades críticas para competir con sistemas como Loyverse o Bsale.

### A. Gestión de Inventario Flexible
- [ ] **Unidades de Medida Variables:** Poder vender por metro (cables/mangueras), kilo (clavos sueltos) o unidad.
- [ ] **Gestión de Packs:** Crear un producto "Pack 12 Lápices" que al venderse descuente 12 unidades del stock del lápiz individual.
- [ ] **Imágenes de Productos:** Galería rápida para identificar herramientas o útiles específicos visualmente en el POS.

### B. Ventas y Operaciones
- [ ] **Módulo de Cotizaciones (Proformas):** Permitir generar un presupuesto que no descuente stock y que pueda convertirse en una venta después.
- [ ] **Botón Rápido de "Fiado":** Agilizar el proceso de venta a crédito desde el POS con un solo clic.
- [ ] **Ticket de Venta Simplificado:** Diseño de boleta optimizado para impresoras térmicas de 58mm/80mm.

### C. Fidelización y Cobranza
- [ ] **Integración con WhatsApp:** Envío automático de recordatorios de pago a clientes con saldo pendiente (Fiados).
- [ ] **Límite de Crédito Dinámico:** Bloqueo automático de "Fiado" si el cliente supera su deuda máxima permitida.

---

## 📅 3. Plan de Iteraciones (Próximos Pasos)

### Fase 1: Limpieza e Identidad (COMPLETADA)
- ✅ Clonación de Base de Datos.
- ✅ Actualización de nombre a "GESTIÓN PRO".
- ✅ Limpieza de tipos de datos y roles (admin/vendedor).
- ✅ Hacer la fecha de vencimiento y lote **opcionales** en el ingreso de productos e inventario.
- ✅ Eliminación de terminología clínica en toda la interfaz.
- ✅ Simplificación operativa: Eliminación del módulo de Tesorería y Arqueo de Caja obligatorio para agilizar ventas.

### Fase 2: Potencia en el POS (EN CURSO)
- ✅ Implementar el selector de Unidades de Medida (KG, MT, UN) y soporte para stock decimal.
- ✅ Crear el generador de Cotizaciones (sin descuento de stock).
- ✅ Implementar visor de precios rápido (Scan-only mode).
- ✅ Bloqueo automático de "Fiado" por exceso de cupo (Límite dinámico).
- ✅ Soporte para Packs/Combos de venta (Descuento proporcional de stock).

### Fase 3: Automatización
- [ ] Configurar las alertas de WhatsApp para cobranza.
- ✅ Implementar el panel de estadísticas comercial mejorado.

---
*Ultima actualización: 19 de Enero, 2026*
