// =====================================================
// TIPOS PARA SISTEMA DE PRE-VENTAS
// =====================================================

export type EstadoPreVenta =
    | 'BORRADOR'           // Vendedor está armando
    | 'PENDIENTE'          // Enviada al cajero
    | 'CONFIRMADA'         // Procesada por cajero
    | 'RECHAZADA'          // Rechazada por cajero
    | 'CANCELADA';         // Cancelada por vendedor

export interface PreVentaItem {
    producto_id: string;
    cantidad: number;
    precio: number;
    nombre: string;
    factor: number;
    unidad_medida?: string;
}

export interface PreVenta {
    id: string;
    codigo_preventa?: string; // Código corto tipo PV-1234
    vendedor_id: string;
    vendedor_nombre?: string;
    cajero_id?: string;
    cajero_nombre?: string;
    cliente_id?: string;
    cliente_nombre?: string;
    estado: EstadoPreVenta;
    items: PreVentaItem[];
    total: number;
    tipo_venta: 'BOLETA' | 'FACTURA' | 'TRANSFERENCIA' | 'FIADO';
    notas_vendedor?: string;
    notas_cajero?: string;
    motivo_rechazo?: string;
    created_at: string;
    updated_at: string;
    enviada_at?: string;
    confirmada_at?: string;
    venta_id?: string;
}

export interface CreatePreVentaParams {
    vendedor_id: string;
    cliente_id?: string;
    items: PreVentaItem[];
    tipo_venta: string;
    notas?: string;
}
