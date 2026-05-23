import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { PreVenta, PreVentaItem } from '../types/preventas';
import { Button } from '../components/ui/Button';
import { CheckCircle, XCircle, Clock, User, Package, Receipt, ShoppingCart, AlertTriangle } from 'lucide-react';
import { format, isValid } from 'date-fns';
import { es } from 'date-fns/locale';
import toast from 'react-hot-toast';
import { CopyCodeButton } from '../components/ui/CopyCodeButton';
import { SmartSearch } from '../components/ui/SmartSearch';

export function CajeroPreVentas() {
    const { user } = useAuth();
    const [preventas, setPreventas] = useState<PreVenta[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedPreVenta, setSelectedPreVenta] = useState<PreVenta | null>(null);
    const [showDetailModal, setShowDetailModal] = useState(false);
    const [showRejectModal, setShowRejectModal] = useState(false);
    const [motivoRechazo, setMotivoRechazo] = useState('');
    const [processing, setProcessing] = useState(false);
    const [filteredPreVentas, setFilteredPreVentas] = useState<PreVenta[]>([]);

    useEffect(() => {
        setFilteredPreVentas(preventas);
    }, [preventas]);

    const handleSearch = (query: string) => {
        if (!query) {
            setFilteredPreVentas(preventas);
            return;
        }

        const lowerQuery = query.toLowerCase();
        const filtered = preventas.filter(pv =>
            pv.codigo_preventa?.toLowerCase().includes(lowerQuery) ||
            pv.cliente_nombre?.toLowerCase().includes(lowerQuery) ||
            pv.vendedor_nombre?.toLowerCase().includes(lowerQuery)
        );
        setFilteredPreVentas(filtered);
    };

    const fetchPreVentasPendientes = useCallback(async () => {
        try {
            // Auto-cancelar pre-ventas con mas de 15 dias
            await supabase.rpc('auto_cancelar_preventas_antiguas');

            const { data, error } = await supabase.rpc('listar_preventas', {
                p_usuario_id: user?.id,
                p_estado: 'PENDIENTE',
                p_solo_propias: false
            });

            if (error) throw error;
            setPreventas(data || []);
        } catch {
            toast.error('Error al cargar pre-ventas');
        } finally {
            setLoading(false);
        }
    }, [user?.id]);

    useEffect(() => {
        fetchPreVentasPendientes();
        const interval = setInterval(fetchPreVentasPendientes, 30000);
        return () => clearInterval(interval);
    }, [fetchPreVentasPendientes]);

    const handleCancelar = async () => {
        if (!selectedPreVenta) return;

        if (!motivoRechazo.trim()) {
            toast.error('Debes indicar el motivo de cancelación');
            return;
        }

        setProcessing(true);
        try {
            const { error } = await supabase.rpc('rechazar_preventa', {
                p_preventa_id: selectedPreVenta.id,
                p_cajero_id: user?.id,
                p_motivo: motivoRechazo.trim()
            });

            if (error) throw error;

            toast.success('Pre-venta cancelada correctamente');
            setShowRejectModal(false);
            setShowDetailModal(false);
            setSelectedPreVenta(null);
            setMotivoRechazo('');
            fetchPreVentasPendientes();
        } catch (error: unknown) {
            toast.error('Error al cancelar: ' + (error instanceof Error ? error.message : 'Error desconocido'));
        } finally {
            setProcessing(false);
        }
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
                        <Clock className="text-orange-600" size={32} />
                        Pre-Ventas Pendientes
                    </h1>
                    <p className="text-gray-600 mt-2">
                        Para procesar el pago, ingresa el código en el POS
                    </p>
                </div>
                <div className="flex items-center gap-3">
                    <div className="bg-orange-100 text-orange-700 px-4 py-2 rounded-lg font-bold">
                        {preventas.length} Pendiente{preventas.length !== 1 ? 's' : ''}
                    </div>
                    <Button variant="secondary" onClick={fetchPreVentasPendientes}>
                        Actualizar
                    </Button>
                </div>
            </div>

            {/* Smart Search */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
                <SmartSearch
                    onSearch={handleSearch}
                    placeholder="Buscar por código, cliente o vendedor..."
                />
            </div>

            {/* Lista Compacta */}
            {filteredPreVentas.length === 0 ? (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 text-center">
                    <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
                    <h3 className="text-lg font-semibold text-gray-600 mb-2">
                        {preventas.length === 0 ? '¡Todo al día!' : 'Sin resultados'}
                    </h3>
                    <p className="text-gray-500">
                        {preventas.length === 0
                            ? 'No hay pre-ventas pendientes de confirmación'
                            : 'No se encontraron pre-ventas con los filtros aplicados'}
                    </p>
                </div>
            ) : (
                <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                    <table className="w-full">
                        <thead className="bg-gray-50 border-b border-gray-200">
                            <tr>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Código</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Cliente</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Vendedor</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Items</th>
                                <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase">Total</th>
                                <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Fecha</th>
                                <th className="px-6 py-3 text-center text-xs font-semibold text-gray-600 uppercase">Acción</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                            {filteredPreVentas.map((pv) => (
                                <tr
                                    key={pv.id}
                                    className="hover:bg-blue-50 transition-colors cursor-pointer"
                                    onClick={() => {
                                        setSelectedPreVenta(pv);
                                        setShowDetailModal(true);
                                    }}
                                >
                                    <td className="px-6 py-4">
                                        <div className="flex items-center gap-2">
                                            <span className="font-mono font-bold text-blue-600">
                                                {pv.codigo_preventa}
                                            </span>
                                            <CopyCodeButton code={pv.codigo_preventa || ''} />
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
                                    <td className="px-6 py-4 text-sm text-gray-600">
                                        {pv.vendedor_nombre}
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
                                    <td className="px-6 py-4 text-sm text-gray-500">
                                        {pv.enviada_at && isValid(new Date(pv.enviada_at)) 
                                            ? format(new Date(pv.enviada_at), "dd/MM HH:mm", { locale: es })
                                            : 'Fecha no disponible'}
                                    </td>
                                    <td className="px-6 py-4 text-center">
                                        <button
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                setSelectedPreVenta(pv);
                                                setShowDetailModal(true);
                                            }}
                                            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold text-sm transition-colors"
                                        >
                                            Ver Detalle
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            {/* Modal de Detalle */}
            {showDetailModal && selectedPreVenta && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-3xl shadow-2xl w-full max-w-2xl overflow-hidden">
                        <div className="p-6 border-b border-gray-100 bg-white">
                            <h3 className="text-2xl font-bold flex items-center gap-2 text-gray-900">
                                <Receipt size={28} className="text-blue-600" />
                                Detalle de Pre-Venta
                            </h3>
                            <div className="flex items-center gap-2 mt-2">
                                <p className="text-gray-500">Código:</p>
                                <span className="font-mono font-bold text-blue-600 text-lg">{selectedPreVenta.codigo_preventa}</span>
                                <CopyCodeButton code={selectedPreVenta.codigo_preventa || ''} />
                            </div>
                        </div>

                        <div className="p-6 space-y-6 max-h-[60vh] overflow-y-auto">
                            {/* Info General */}
                            <div className="grid grid-cols-2 gap-4">
                                <div className="bg-gray-50 p-4 rounded-xl">
                                    <p className="text-xs text-gray-500 mb-1">Vendedor</p>
                                    <p className="font-bold text-gray-900">{selectedPreVenta.vendedor_nombre}</p>
                                </div>
                                <div className="bg-gray-50 p-4 rounded-xl">
                                    <p className="text-xs text-gray-500 mb-1">Cliente</p>
                                    <p className="font-bold text-gray-900">{selectedPreVenta.cliente_nombre || 'Sin cliente'}</p>
                                </div>
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
                            <div className="bg-white border-2 border-green-200 p-6 rounded-xl">
                                <p className="text-sm text-green-700 mb-1 font-medium">Total a Cobrar</p>
                                <p className="text-4xl font-black text-green-700">${selectedPreVenta.total.toLocaleString()}</p>
                            </div>

                            {/* Notas del Vendedor */}
                            {selectedPreVenta.notas_vendedor && (
                                <div className="bg-yellow-50 p-4 rounded-xl border border-yellow-200">
                                    <p className="text-xs text-yellow-700 font-semibold mb-1">Nota del Vendedor:</p>
                                    <p className="text-sm text-yellow-900">{selectedPreVenta.notas_vendedor}</p>
                                </div>
                            )}

                            {/* Instrucciones */}
                            <div className="bg-blue-50 p-4 rounded-xl border border-blue-200">
                                <p className="text-sm font-semibold text-blue-900 mb-2">📋 Para procesar esta venta:</p>
                                <ol className="text-sm text-blue-800 space-y-1 list-decimal list-inside">
                                    <li>Ve al POS principal</li>
                                    <li>Ingresa el código: <span className="font-mono font-bold">{selectedPreVenta.codigo_preventa}</span></li>
                                    <li>Confirma la carga de productos</li>
                                    <li>Procesa el pago normalmente</li>
                                </ol>
                                <p className="text-xs text-blue-600 mt-3 italic">
                                    💡 Las pre-ventas se cancelan automáticamente después de 15 días
                                </p>
                            </div>
                        </div>

                        {/* Botones */}
                        <div className="p-6 bg-gray-50 border-t border-gray-200 flex gap-3">
                            <button
                                onClick={() => {
                                    setShowDetailModal(false);
                                    setSelectedPreVenta(null);
                                }}
                                disabled={processing}
                                className="flex-1 py-3 px-6 bg-white border-2 border-gray-300 text-gray-700 rounded-xl font-bold hover:bg-gray-50 transition-colors disabled:opacity-50"
                            >
                                Cerrar
                            </button>
                            <button
                                onClick={() => {
                                    setShowDetailModal(false);
                                    setShowRejectModal(true);
                                }}
                                disabled={processing}
                                className="flex-1 py-3 px-6 bg-red-600 text-white rounded-xl font-bold hover:bg-red-700 transition-all flex items-center justify-center gap-2 disabled:opacity-50"
                            >
                                <XCircle size={20} />
                                Cancelar Pre-Venta
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Modal de Rechazo */}
            {showRejectModal && selectedPreVenta && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
                    <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md overflow-hidden">
                        <div className="p-6 border-b border-gray-100 bg-red-600 text-white">
                            <h3 className="text-2xl font-bold flex items-center gap-2">
                                <XCircle size={28} />
                                Cancelar Pre-Venta
                            </h3>
                        </div>

                        <div className="p-6 space-y-4">
                            <div className="bg-red-50 p-4 rounded-xl border border-red-200">
                                <div className="flex items-start gap-3">
                                    <AlertTriangle className="text-red-600 flex-shrink-0 mt-1" size={20} />
                                    <div>
                                        <p className="font-semibold text-red-900 mb-1">
                                            ¿Cancelar esta pre-venta?
                                        </p>
                                        <p className="text-sm text-red-700">
                                            Esta acción no se puede deshacer. El vendedor será notificado.
                                        </p>
                                    </div>
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-semibold text-gray-700 mb-2">
                                    Motivo de Cancelación: <span className="text-red-500">*</span>
                                </label>
                                <textarea
                                    className="w-full p-3 border rounded-lg resize-none focus:ring-2 focus:ring-red-500 outline-none"
                                    rows={4}
                                    placeholder="Ej: Stock insuficiente, precio incorrecto, cliente no disponible..."
                                    value={motivoRechazo}
                                    onChange={(e) => setMotivoRechazo(e.target.value)}
                                    disabled={processing}
                                    required
                                />
                            </div>
                        </div>

                        <div className="p-6 bg-gray-50 border-t border-gray-200 flex gap-3">
                            <button
                                onClick={() => {
                                    setShowRejectModal(false);
                                    setMotivoRechazo('');
                                }}
                                disabled={processing}
                                className="flex-1 py-3 px-6 bg-white border-2 border-gray-300 text-gray-700 rounded-xl font-bold hover:bg-gray-50 transition-colors disabled:opacity-50"
                            >
                                Cancelar
                            </button>
                            <button
                                onClick={handleCancelar}
                                disabled={processing || !motivoRechazo.trim()}
                                className="flex-1 py-3 px-6 bg-red-600 text-white rounded-xl font-bold hover:bg-red-700 transition-all flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                                {processing ? (
                                    <>Procesando...</>
                                ) : (
                                    <>
                                        <XCircle size={20} />
                                        Rechazar
                                    </>
                                )}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
