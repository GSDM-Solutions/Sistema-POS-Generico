export interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'empleado' | 'superadmin' | 'supervisor';
  empresa_id: string;
  created_at: string;
  updated_at: string;
}

// Catálogo central de productos
export interface MasterProduct {
  id: string;
  nombre: string;
  categoria: string;
  descripcion?: string;
  stock_critico: number;
  precio_venta?: number;
  codigo_barra?: string;
  unidad_medida?: string;
  creado_en: string;
  actualizado_en: string;
  controla_stock: boolean;
  activo: boolean;
  presentaciones?: ProductPresentation[];
}

export interface ProductPresentation {
  id: string;
  maestro_producto_id: string;
  codigo_barra: string;
  nombre_presentacion: string;
  factor_conversion: number;
  precio_venta?: number;
  creado_en: string;
}

// Lotes de inventario físico
export interface Product {
  id: string;
  maestro_producto_id: string;
  stock_actual: number;
  numero_lote?: string;
  fecha_vencimiento?: string;
  proveedor_id?: string;
  condicion: string;
  observaciones?: string;
  bloqueado: boolean;
  fecha_ingreso: string;
  creado_en: string;
  actualizado_en: string;
  maestro_productos?: {
    nombre: string;
    unidad_medida?: string;
  };
}

export interface Movement {
  id: string;
  producto_nombre: string;
  numero_lote?: string;
  tipo_movimiento: string;
  cantidad: number;
  condicion: string;
  usuario_nombre: string;
  motivo?: string;
  fecha: string;
  producto_id?: string;
  usuario_id?: string;
  creado_en?: string;
  producto?: Product;
  usuario?: User;
}

export interface DashboardStats {
  total_products: number;
  critical_stock_products: number;
  total_ventas_hoy: number;
  total_fiado_pendiente: number;
  expired_products?: number;
  quarantine_products?: number;
  recent_movements: Movement[];
  category_distribution: { name: string; value: number }[];
  top_products?: { nombre: string; total_vendido: number; total_ingreso: number }[];
  sales_trend?: { fecha: string; total: number }[];
}

export interface Provider {
  id: string;
  nombre: string;
  direccion?: string;
  clasificacion?: string;
  activo?: boolean;
  created_at: string;
}

export interface Client {
  id: string;
  rut: string;
  nombre: string;
  email?: string;
  telefono?: string;
  direccion?: string;
  cupo_credito: number;
  saldo_actual: number;
  activo: boolean;
  creado_en: string;
}