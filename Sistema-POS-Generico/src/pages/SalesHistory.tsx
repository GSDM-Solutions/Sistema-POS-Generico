import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { ShoppingCart, User, Calendar, Eye, ChevronLeft, ChevronRight } from 'lucide-react';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';
import toast from 'react-hot-toast';
import { Modal } from '../components/ui/Modal';

interface VentaItem {
    nombre: string;
    cantidad: number;
    precio: number;
    subtotal: number;
}

interface Venta {
    id: string;
    folio: string;
    fecha: string;
    cliente_nombre: string | null;
    tipo_venta: string;
    total: number;
    usuario_nombre: string;
    items_count: number;
    items: VentaItem[];
}

const PAGE_SIZE = 20;

export function SalesHistory() {
    const [ventas, setVentas] = useState<Venta[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedVenta, setSelectedVenta] = useState<Venta | null>(null);
    const [showDetailModal, setShowDetailModal] = useState(false);
    const [dateFrom, setDateFrom] = useState(format(new Date(), 'yyyy-MM-dd'));
    const [dateTo, setDateTo] = useState(format(new Date(), 'yyyy-MM-dd'));
    const [page, setPage] = useState(0);
    const [totalCount, setTotalCount] = useState(0);

    useEffect(() => {
        setPage(0);
        fetchVentas(0);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [dateFrom, dateTo]);

    const fetchVentas = async (pageIndex: number) => {
        setLoading(true);
        try {
            const from = pageIndex * PAGE_SIZE;
            const to = from + PAGE_SIZE - 1;

            const { data, error, count } = await supabase
                .from('ventas')
                .select(`
                    id,
                    fecha_creacion,
                    tipo_venta,
                    total,
                    usuario_id,
                    clientes (nombre),
                    detalle_ventas (
                        cantidad,
                        precio_unitario,
                        subtotal,
                        factor_conversion,
                        productos (
                            maestro_productos (nombre)
                        )
                    )
                `, { count: 'exact' })
                .gte('fecha_creacion', `${dateFrom}T00:00:00`)
                .lte('fecha_creacion', `${dateTo}T23:59:59`)
                .order('fecha_creacion', { ascending: false })
                .range(from, to);

            if (error) throw error;

            if (count !== null) setTotalCount(count);

            const usuarioIds = [...new Set((data || []).map((v: Record<string, unknown>) => v.usuario_id).filter(Boolean))];
            const { data: usuarios } = await supabase
                .from('users')
                .select('id, name')
                .in('id', usuarioIds as string[]);

            const usuariosMap = new Map((usuarios || []).map(u => [u.id, u.name]));

            const ventasFormateadas = (data || []).map((v: Record<string, unknown>) => ({
                id: v.id as string,
                folio: (v.id as string).slice(0, 8).toUpperCase(),
                fecha: v.fecha_creacion as string,
                cliente_nombre: (v.clientes as { nombre?: string } | undefined)?.nombre || null,
                tipo_venta: v.tipo_venta as string,
                total: v.total as number,
                usuario_nombre: usuariosMap.get(v.usuario_id as string) || 'Sistema',
                items_count: (v.detalle_ventas as unknown[])?.length || 0,
                items: ((v.detalle_ventas as unknown[]) || []).map((d: unknown) => {
                    const det = d as Record<string, unknown>;
                    const prod = det.productos as Record<string, unknown> | undefined;
                    const maestro = prod?.maestro_productos as Record<string, unknown> | undefined;
                    return {
                        nombre: maestro?.nombre as string || 'Producto eliminado',
                        cantidad: det.cantidad as number,
                        precio: det.precio_unitario as number,
                        subtotal: det.subtotal as number
                    };
                })
            }));

            setVentas(ventasFormateadas);
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'Error desconocido';
            toast.error('Error al cargar ventas: ' + message);
        } finally {
            setLoading(false);
        }
    };

    const getTipoVentaBadge = (tipo: string) => {
        const config: Record<string, { color: string; label: string }> = {
            BOLETA: { color: 'bg-blue-100 text-blue-700', label: 'Boleta' },
            FACTURA: { color: 'bg-purple-100 text-purple-700', label: 'Factura' },
            TRANSFERENCIA: { color: 'bg-green-100 text-green-700', label: 'Transferencia' },
            FIADO: { color: 'bg-orange-100 text-orange-700', label: 'Fiado' },
            COTIZACION: { color: 'bg-gray-100 text-gray-700', label: 'Cotización' }
        };
        return config[tipo] || config.BOLETA;
    };

    const totalVentas = ventas.reduce((sum, v) => sum + v.total, 0);
    const totalTransacciones = ventas.length;

    if (loading) {
        return (
            <div className="flex items-center justify-center h-64">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            </div>
        );
    }

    return (
        <div className="max-w-7xl mx-auto p-6 space-y-6">
            {/* Header */}
            <div className="flex justify-between items-center">
                <div>
                    <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
                        <ShoppingCart className="text-blue-600" size={32} />
                        Historial de Ventas
                    </h1>
                    <p className="text-gray-600 mt-2">
                        Registro completo de transacciones comerciales
                    </p>
                </div>
            </div>

            {/* Filtros */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
                <div className="flex gap-4 items-end">
                    <div className="flex-1">
                        <label className="block text-sm font-semibold text-gray-700 mb-2">Desde</label>
                        <input
                            type="date"
                            value={dateFrom}
                            onChange={(e) => setDateFrom(e.target.value)}
                            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                        />
                    </div>
                    <div className="flex-1">
                        <label className="block text-sm font-semibold text-gray-700 mb-2">Hasta</label>
                        <input
                            type="date"
                            value={dateTo}
                            onChange={(e) => setDateTo(e.target.value)}
                            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                        />
                    </div>
                    <button
                        onClick={fetchVentas}
                        className="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
                    >
                        Buscar
                    </button>
                </div>
            </div>

            {/* Resumen */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="bg-white border-2 border-gray-200 rounded-xl p-6 shadow-sm">
                    <p className="text-gray-500 text-sm mb-1 font-medium">Total Transacciones</p>
                    <p className="text-4xl font-black text-gray-900">{totalTransacciones}</p>
                </div>
                <div className="bg-white border-2 border-blue-200 rounded-xl p-6 shadow-sm">
                    <p className="text-gray-500 text-sm mb-1 font-medium">Total Vendido</p>
                    <p className="text-4xl font-black text-blue-700">${totalVentas.toLocaleString()}</p>
                </div>
                <div className="bg-white border-2 border-gray-200 rounded-xl p-6 shadow-sm">
                    <p className="text-gray-500 text-sm mb-1 font-medium">Promedio por Venta</p>
                    <p className="text-4xl font-black text-gray-900">${totalTransacciones > 0 ? Math.round(totalVentas / totalTransacciones).toLocaleString() : 0}</p>
                </div>
            </div>

            {/* Lista de Ventas */}
            {ventas.length === 0 ? (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 text-center">
                    <ShoppingCart className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                    <h3 className="text-lg font-semibold text-gray-600 mb-2">No hay ventas</h3>
                    <p className="text-gray-500">No se encontraron ventas en el período seleccionado</p>
                </div>
            ) : (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <table className="w-full">
                        <thead className="bg-gray-50 border-b border-gray-200">
                            <tr>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Folio</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Fecha/Hora</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Cliente</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Tipo</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Items</th>
                                <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase">Total</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Vendedor</th>
                                <th className="px-6 py-3 text-center text-xs font-semibold text-gray-600 uppercase">Acciones</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                            {ventas.map((venta) => {
                                const tipoBadge = getTipoVentaBadge(venta.tipo_venta);
                                return (
                                    <tr key={venta.id} className="hover:bg-blue-50 transition-colors">
                                        <td className="px-6 py-4">
                                            <span className="font-mono font-bold text-blue-600">
                                                {venta.folio}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-sm text-gray-600">
                                            <div className="flex items-center gap-1">
                                                <Calendar size={14} />
                                                {format(new Date(venta.fecha), "dd/MM/yyyy HH:mm", { locale: es })}
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="flex items-center gap-2">
                                                <User size={16} className="text-gray-400" />
                                                <span className="font-medium text-gray-900">
                                                    {venta.cliente_nombre || 'General'}
                                                </span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className={`px-3 py-1 rounded-full text-xs font-bold ${tipoBadge.color}`}>
                                                {tipoBadge.label}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-sm text-gray-600">
                                            {venta.items_count} productos
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <span className="font-bold text-lg text-gray-900">
                                                ${venta.total.toLocaleString()}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-sm text-gray-600">
                                            {venta.usuario_nombre}
                                        </td>
                                        <td className="px-6 py-4 text-center">
                                            <button
                                                onClick={() => {
                                                    setSelectedVenta(venta);
                                                    setShowDetailModal(true);
                                                }}
                                                className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-medium transition-colors flex items-center gap-1 mx-auto"
                                            >
                                                <Eye size={14} />
                                                Ver
                                            </button>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            )}

            {/* Paginación */}
            {totalCount > PAGE_SIZE && (
                <div className="flex items-center justify-between bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
                    <p className="text-sm text-gray-600">
                        Mostrando {page * PAGE_SIZE + 1}-{Math.min((page + 1) * PAGE_SIZE, totalCount)} de {totalCount} ventas
                    </p>
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => {
                                const newPage = page - 1;
                                setPage(newPage);
                                fetchVentas(newPage);
                            }}
                            disabled={page === 0}
                            className="p-2 rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed"
                        >
                            <ChevronLeft size={20} />
                        </button>
                        {Array.from({ length: Math.ceil(totalCount / PAGE_SIZE) }).map((_, i) => (
                            <button
                                key={i}
                                onClick={() => {
                                    setPage(i);
                                    fetchVentas(i);
                                }}
                                className={`w-10 h-10 rounded-lg text-sm font-medium transition-colors ${page === i ? 'bg-blue-600 text-white' : 'hover:bg-gray-100 text-gray-700'}`}
                            >
                                {i + 1}
                            </button>
                        ))}
                        <button
                            onClick={() => {
                                const newPage = page + 1;
                                setPage(newPage);
                                fetchVentas(newPage);
                            }}
                            disabled={(page + 1) * PAGE_SIZE >= totalCount}
                            className="p-2 rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed"
                        >
                            <ChevronRight size={20} />
                        </button>
                    </div>
                </div>
            )}

            {/* Modal de Detalle */}
            <Modal
                isOpen={showDetailModal}
                onClose={() => { setShowDetailModal(false); setSelectedVenta(null); }}
                title="Detalle de Venta"
                size="lg"
            >
                {selectedVenta && (
                    <div className="space-y-6 max-h-[60vh] overflow-y-auto">
                        <p className="text-gray-500">Folio: {selectedVenta.folio}</p>

                        <div className="grid grid-cols-2 gap-4">
                            <div className="bg-gray-50 p-4 rounded-xl">
                                <p className="text-xs text-gray-500 mb-1">Cliente</p>
                                <p className="font-bold text-gray-900">{selectedVenta.cliente_nombre || 'General'}</p>
                            </div>
                            <div className="bg-gray-50 p-4 rounded-xl">
                                <p className="text-xs text-gray-500 mb-1">Tipo de Venta</p>
                                <p className="font-bold text-gray-900">{getTipoVentaBadge(selectedVenta.tipo_venta).label}</p>
                            </div>
                            <div className="bg-gray-50 p-4 rounded-xl">
                                <p className="text-xs text-gray-500 mb-1">Fecha</p>
                                <p className="font-bold text-gray-900">
                                    {format(new Date(selectedVenta.fecha), "dd/MM/yyyy HH:mm", { locale: es })}
                                </p>
                            </div>
                            <div className="bg-gray-50 p-4 rounded-xl">
                                <p className="text-xs text-gray-500 mb-1">Vendedor</p>
                                <p className="font-bold text-gray-900">{selectedVenta.usuario_nombre}</p>
                            </div>
                        </div>

                        <div>
                            <h4 className="font-bold text-gray-700 mb-3 flex items-center gap-2">
                                <ShoppingCart size={18} />
                                Productos ({selectedVenta.items_count})
                            </h4>
                            <div className="max-h-60 overflow-y-auto space-y-2 bg-gray-50 p-4 rounded-xl">
                                {selectedVenta.items.map((item, idx) => (
                                    <div key={idx} className="flex justify-between items-center py-2 border-b border-gray-200 last:border-0">
                                        <div>
                                            <p className="font-semibold text-gray-800">{item.nombre}</p>
                                            <p className="text-xs text-gray-500">Cantidad: {item.cantidad}</p>
                                        </div>
                                        <p className="font-bold text-gray-900">${item.subtotal.toLocaleString()}</p>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="bg-white border-2 border-blue-200 p-6 rounded-xl">
                            <p className="text-sm text-gray-600 mb-1 font-medium">Total</p>
                            <p className="text-4xl font-black text-blue-700">${selectedVenta.total.toLocaleString()}</p>
                        </div>
                    </div>
                )}
            </Modal>
        </div>
    );
}
