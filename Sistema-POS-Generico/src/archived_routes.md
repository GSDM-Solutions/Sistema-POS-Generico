# Rutas y Funcionalidades Archivadas (Módulo Clínica)

Este archivo contiene las rutas y componentes que fueron ocultados del sistema principal para enfocarlo en Retail/Supermercado. Pueden ser restaurados copiando estas configuraciones de vuelta en `App.tsx` y `Sidebar.tsx`.

## Rutas (App.tsx)

```tsx
import PatientMedications from './pages/PatientMedications';
import DeliveryHistory from './pages/DeliveryHistory';
import ChecklistAlmacenamiento from './pages/ChecklistAlmacenamiento';
import ChecklistProtocolo from './pages/ChecklistProtocolo';
import ChecklistHistory from './pages/ChecklistHistory';

// Dentro de <Route element={<ProtectedRoute />}>
<Route path="/patient-medications" element={<PatientMedications />} />
<Route path="/delivery-history" element={<DeliveryHistory />} />
<Route path="/checklist-storage" element={<ChecklistAlmacenamiento />} />
<Route path="/checklist-protocol" element={<ChecklistProtocolo />} />
<Route path="/checklist-history" element={<ChecklistHistory />} />
```

## Navegación (Sidebar.tsx)

```tsx
import { Syringe, Archive, CheckSquare, History } from 'lucide-react';

const navigation = [
  // ...
  { name: 'Checklist Almacenamiento', href: '/checklist-storage', icon: CheckSquare, permission: 'checklists' },
  { name: 'Checklist Protocolo', href: '/checklist-protocol', icon: CheckSquare, permission: 'checklists' },
  { name: 'Medicamentos Pacientes', href: '/patient-medications', icon: Syringe, permission: 'patient_medications' },
  { name: 'Historial de Entregas', href: '/delivery-history', icon: Archive, permission: 'patient_medications' },
  { name: 'Historial de Checklists', href: '/checklist-history', icon: History, permission: 'checklists' },
  // ...
];
```
