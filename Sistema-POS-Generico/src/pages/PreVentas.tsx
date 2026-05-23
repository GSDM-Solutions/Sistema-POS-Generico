import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { PreVenta, EstadoPreVenta, PreVentaItem } from '../types/preventas';
import { Button } from '../components/ui/Button';
import { Plus, Eye, Send, X, FileText, User, Package, Printer, Receipt, ShoppingCart } from 'lucide-react';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';
import toast from 'react-hot-toast';
import { useNavigate } from 'react-router-dom';
import { PreVentaVoucher } from '../components/pos/PreVentaVoucher';
import { CopyCodeButton } from '../components/ui/CopyCodeButton';
import { QRCodeDisplay } from '../components/ui/QRCodeDisplay';

export function PreVentas() {
    const { user } = useAuth();
    const navigate = useNavigate();
    const [preventas, setPreventas] = useState<PreVenta[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedPreVenta, setSelectedPreVenta] = useState<PreVenta | null>(null);
    const [showDetailModal, setShowDetailModal] = useState(false);
    const [showVoucher, setShowVoucher] = useState(false);
    const [filterEstado, setFilterEstado] = useState<EstadoPreVenta | 'TODAS'>('TODAS');

    const fetchPreVentas = useCallback(async () => {
        setLoading(true);
        try {
            const { data, error } = await supabase.rpc('listar_preventas', {
                p_usuario_id: user?.id,
                p_estado: filterEstado === 'TODAS' ? null : filterEstado,
                p_solo_propias: true
            });

            if (error) throw error;
            setPreventas(data || []);
        } catch (error: unknown) {
            toast.error('Error al cargar pre-ventas: ' + (error instanceof Error ? error.message : 'Error desconocido'));
        } finally {
            setLoading(false);
        }
    }, [user?.id, filterEstado]);

    useEffect(() => {
        fetchPreVentas();
    }, [fetchPreVentas]);

    const handleEnviarPreVenta = async (preVentaId: string) => {
        if (!confirm('¿Enviar esta pre-venta al cajero para confirmación?')) return;

        try {
            const { error } = await supabase.rpc('enviar_preventa', {
                p_preventa_id: preVentaId,
                p_vendedor_id: user?.id
            });

            if (error) throw error;
            toast.success('Pre-venta enviada al cajero');
            fetchPreVentas();
        } catch (error: unknown) {
            toast.error('Error: ' + (error instanceof Error ? error.message : 'Error desconocido'));
        }
    };

    const handleCancelarPreVenta = async (preVentaId: string) => {
        if (!confirm('¿Cancelar esta pre-venta?')) return;

        try {
            const { error } = await supabase.rpc('cancelar_preventa', {
                p_preventa_id: preVentaId,
                p_vendedor_id: user?.id
            });

            if (error) throw error;
            toast.success('Pre-venta cancelada');
            fetchPreVentas();
        } catch (error: unknown) {
            toast.error('Error: ' + (error instanceof Error ? error.message : 'Error desconocido'));
        }
    };

    const getEstadoBadge = (estado: EstadoPreVenta) => {
        const config = {
            BORRADOR: { color: 'bg-gray-100 text-gray-700', label: 'Borrador' },
            PENDIENTE: { color: 'bg-yellow-100 text-yellow-700', label: 'Pendiente' },
            CONFIRMADA: { color: 'bg-green-100 text-green-700', label: 'Confirmada' },
            RECHAZADA: { color: 'bg-red-100 text-red-700', label: 'Rechazada' },
            CANCELADA: { color: 'bg-gray-100 text-gray-500', label: 'Cancelada' }
        };
        return config[estado];
    };

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
                        <FileText className="text-blue-600" size={32} />
                        Mis Pre-Ventas
                    </h1>
                    <p className="text-gray-600 mt-2">
                        Gestiona tus pre-ventas y envíalas al cajero
                    </p>
                </div>
                <Button onClick={() => navigate('/preventas/nueva')} className="shadow-lg">
                    <Plus className="w-4 h-4 mr-2" />
                    Nueva Pre-Venta
                </Button>
            </div>

            {/* Filtros */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
                <div className="flex gap-2 flex-wrap">
                    {(['TODAS', 'BORRADOR', 'PENDIENTE', 'CONFIRMADA', 'RECHAZADA'] as const).map((estado) => (
                        <button
                            key={estado}
                            onClick={() => setFilterEstado(estado)}
                            className={`px-4 py-2 rounded-lg font-medium transition-all ${filterEstado === estado
                                ? 'bg-blue-600 text-white shadow-md'
                                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                                }`}
                        >
                            {estado === 'TODAS' ? 'Todas' : getEstadoBadge(estado).label}
                            <span className="ml-2 text-xs opacity-75">
                                ({estado === 'TODAS' ? preventas.length : preventas.filter(pv => pv.estado === estado).length})
                            </span>
                        </button>
                    ))}
                </div>
            </div>

            {/* Lista Compacta */}
            {preventas.length === 0 ? (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 text-center">
                    <FileText className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                    <h3 className="text-lg font-semibold text-gray-600 mb-2">No hay pre-ventas</h3>
                    <p className="text-gray-500 mb-4">
                        {filterEstado === 'TODAS'
                            ? 'Crea tu primera pre-venta para comenzar'
                            : `No tienes pre-ventas en estado ${getEstadoBadge(filterEstado as EstadoPreVenta).label}`}
                    </p>
                    <Button onClick={() => navigate('/preventas/nueva')}>
                        <Plus className="w-4 h-4 mr-2" />
                        Crear Pre-Venta
                    </Button>
                </div>
            ) : (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <table className="w-full">
                        <thead className="bg-gray-50 border-b border-gray-200">
                            <tr>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Código</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Cliente</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Items</th>
                                <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase">Total</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Estado</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Fecha</th>
                                <th className="px-6 py-3 text-center text-xs font-semibold text-gray-600 uppercase">Acciones</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                            {preventas.map((pv) => {
                                const estadoBadge = getEstadoBadge(pv.estado);
                                return (
                                    <tr
                                        key={pv.id}
                                        className="hover:bg-blue-50 transition-colors"
                                    >
                                        <td className="px-6 py-4">
                                            <div className="flex items-center gap-2">
                                                <span className="font-mono font-bold text-blue-600">
                                                    {pv.codigo_preventa}
                                                </span>
                                                <CopyCodeButton code={pv.codigo_preventa} />
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="flex items-center gap-2">
                                                <User size={16} className="text-gray-400" />
                                                <span className="font-medium text-gray-900">
                                                    {pv.cliente_nombre || 'General'}
                                                </span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="flex items-center gap-1 text-sm text-gray-600">
                                                <Package size={14} />
                                                <span>{pv.items.length}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <span className="font-bold text-lg text-gray-900">
                                                ${pv.total.toLocaleString()}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className={`px-3 py-1 rounded-full text-xs font-bold ${estadoBadge.color}`}>
                                                {estadoBadge.label}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-sm text-gray-500">
                                            {format(new Date(pv.created_at), "dd/MM HH:mm", { locale: es })}
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="flex gap-2 justify-center">
                                                <button
                                                    onClick={() => {
                                                        setSelectedPreVenta(pv);
                                                        setShowDetailModal(true);
                                                    }}
                                                    className="px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm font-medium transition-colors flex items-center gap-1"
                                                    title="Ver Detalle"
                                                >
                                                    <Eye size={14} />
                                                </button>

                                                {pv.estado === 'PENDIENTE' && (
                                                    <button
                                                        onClick={() => {
                                                            setSelectedPreVenta(pv);
                                                            setShowVoucher(true);
                                                        }}
                                                        className="px-3 py-1.5 bg-purple-100 hover:bg-purple-200 text-purple-600 rounded-lg text-sm font-medium transition-colors flex items-center gap-1"
                                                        title="Reimprimir Voucher"
                                                    >
                                                        <Printer size={14} />
                                                    </button>
                                                )}

                                                {pv.estado === 'BORRADOR' && (
                                                    <>
                                                        <button
                                                            onClick={() => handleEnviarPreVenta(pv.id)}
                                                            className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-medium transition-colors flex items-center gap-1"
                                                            title="Enviar al Cajero"
                                                        >
                                                            <Send size={14} />
                                                        </button>
                                                        <button
                                                            onClick={() => handleCancelarPreVenta(pv.id)}
                                                            className="px-3 py-1.5 bg-red-100 hover:bg-red-200 text-red-600 rounded-lg text-sm font-medium transition-colors"
                                                            title="Cancelar"
                                                        >
                                                            <X size={14} />
                                                        </button>
                                                    </>
                                                )}

                                                {pv.estado === 'PENDIENTE' && (
                                                    <button
                                                        onClick={() => handleCancelarPreVenta(pv.id)}
                                                        className="px-3 py-1.5 bg-red-100 hover:bg-red-200 text-red-600 rounded-lg text-sm font-medium transition-colors flex items-center gap-1"
                                                        title="Cancelar"
                                                    >
                                                        <X size={14} />
                                                    </button>
                                                )}
                                            </div>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            )}

            {/* Modal de Detalle */}
            {showDetailModal && selectedPreVenta && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-3xl shadow-2xl w-full max-w-4xl overflow-hidden flex flex-col md:flex-row h-[80vh]">
                        {/* Sidebar del Modal con QR */}
                        <div className="bg-gray-50 border-r border-gray-200 p-6 flex flex-col items-center justify-center md:w-1/3">
                            <QRCodeDisplay
                                value={selectedPreVenta.codigo_preventa || ''}
                                size={180}
                                title="Escanear en Caja"
                                showDownload={false}
                                showPrint={false}
                            />
                            <div className="mt-6 text-center">
                                <p className="text-sm text-gray-500 uppercase tracking-wider font-bold">Código de Pre-Venta</p>
                                <div className="flex items-center justify-center gap-2 mt-2">
                                    <p className="text-2xl font-mono font-bold text-blue-600 tracking-wider">
                                        {selectedPreVenta.codigo_preventa}
                                    </p>
                                    <CopyCodeButton code={selectedPreVenta.codigo_preventa || ''} />
                                </div>
                            </div>
                        </div>

                        {/* Contenido Principal */}
                        <div className="flex-1 flex flex-col h-full bg-white">
                            <div className="p-6 border-b border-gray-100 bg-white">
                                <div className="flex justify-between items-start">
                                    <div>
                                        <h3 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
                                            <Receipt className="text-blue-600" size={28} />
                                            Detalle de Pre-Venta
                                        </h3>
                                        <p className="text-gray-500 mt-1">
                                            Creada el {format(new Date(selectedPreVenta.created_at), "dd/MM/yyyy HH:mm", { locale: es })}
                                        </p>
                                    </div>
                                    <span className={`px-4 py-2 rounded-full text-sm font-bold ${getEstadoBadge(selectedPreVenta.estado).color}`}>
                                        {getEstadoBadge(selectedPreVenta.estado).label}
                                    </span>
                                </div>
                            </div>

                            <div className="p-6 space-y-6 flex-1 overflow-y-auto">
                                {/* Cliente */}
                                <div className="bg-gray-50 p-4 rounded-xl">
                                    <p className="text-xs text-gray-500 mb-1">Cliente</p>
                                    <p className="font-bold text-gray-900">{selectedPreVenta.cliente_nombre || 'General'}</p>
                                </div>

                                {/* Items */}
                                <div>
                                    <h4 className="font-bold text-gray-700 mb-3 flex items-center gap-2">
                                        <ShoppingCart size={18} />
                                        Productos ({selectedPreVenta.items.length})
                                    </h4>
                                    <div className="max-h-60 overflow-y-auto space-y-2 bg-gray-50 p-4 rounded-xl">
                                        {selectedPreVenta.items.map((item: PreVentaItem, idx: number) => (
                                            <div key={idx} className="flex justify-between items-center py-2 border-b border-gray-200 last:border-0">
                                                <div>
                                                    <p className="font-semibold text-gray-800">{item.nombre}</p>
                                                    <p className="text-xs text-gray-500">Cantidad: {item.cantidad} {item.unidad_medida || 'UN'}</p>
                                                </div>
                                                <p className="font-bold text-gray-900">${(item.cantidad * item.precio).toLocaleString()}</p>
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                {/* Total */}
                                <div className="bg-white border-2 border-blue-200 p-6 rounded-xl">
                                    <p className="text-sm text-gray-600 mb-1 font-medium">Total</p>
                                    <p className="text-4xl font-black text-blue-700">${selectedPreVenta.total.toLocaleString()}</p>
                                </div>

                                {/* Notas */}
                                {selectedPreVenta.notas_vendedor && (
                                    <div className="bg-yellow-50 p-4 rounded-xl border border-yellow-200">
                                        <p className="text-xs text-yellow-700 font-semibold mb-1">Nota del Vendedor:</p>
                                        <p className="text-sm text-yellow-900">{selectedPreVenta.notas_vendedor}</p>
                                    </div>
                                )}

                                {selectedPreVenta.motivo_rechazo && (
                                    <div className="bg-red-50 p-4 rounded-xl border border-red-200">
                                        <p className="text-xs text-red-700 font-semibold mb-1">Motivo de Rechazo:</p>
                                        <p className="text-sm text-red-900">{selectedPreVenta.motivo_rechazo}</p>
                                    </div>
                                )}

                                {/* Fechas */}
                                <div className="text-xs text-gray-500 space-y-1">
                                    <p><span className="font-semibold">Creada:</span> {format(new Date(selectedPreVenta.created_at), 'dd/MM/yyyy HH:mm')}</p>
                                    {selectedPreVenta.enviada_at && (
                                        <p><span className="font-semibold">Enviada:</span> {format(new Date(selectedPreVenta.enviada_at), 'dd/MM/yyyy HH:mm')}</p>
                                    )}
                                    {selectedPreVenta.confirmada_at && (
                                        <p><span className="font-semibold">Confirmada:</span> {format(new Date(selectedPreVenta.confirmada_at), 'dd/MM/yyyy HH:mm')}</p>
                                    )}
                                </div>
                            </div>

                            {/* Botones */}
                            <div className="p-6 bg-gray-50 border-t border-gray-200 flex gap-3">
                                <button
                                    onClick={() => {
                                        setShowDetailModal(false);
                                        setSelectedPreVenta(null);
                                    }}
                                    className="flex-1 py-3 px-6 bg-white border-2 border-gray-300 text-gray-700 rounded-xl font-bold hover:bg-gray-50 transition-colors"
                                >
                                    Cerrar
                                </button>
                                {selectedPreVenta.estado === 'PENDIENTE' && (
                                    <button
                                        onClick={() => {
                                            setShowDetailModal(false);
                                            setShowVoucher(true);
                                        }}
                                        className="flex-1 py-3 px-6 bg-white border-2 border-purple-200 text-purple-700 rounded-xl font-bold hover:bg-purple-50 transition-all flex items-center justify-center gap-2"
                                    >
                                        <Printer size={20} />
                                        Imprimir Voucher
                                    </button>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Modal de Voucher */}
            {selectedPreVenta && (
                <PreVentaVoucher
                    preVenta={selectedPreVenta}
                    isOpen={showVoucher}
                    onClose={() => setShowVoucher(false)}
                />
            )}
        </div>
    );
}
