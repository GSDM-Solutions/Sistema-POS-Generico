import { useState, useEffect, useMemo } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';
import { ArrowRightLeft, Package, Truck, Search, AlertTriangle, Check, X } from 'lucide-react';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

interface Bodega {
    id: string;
    nombre: string;
    tipo: 'general' | 'venta';
}

interface ProductoTraslado {
    id: string;
    nombre_producto: string;
    codigo_barra: string | null;
    stock_actual: number;
    numero_lote: string | null;
    fecha_vencimiento: string | null;
    unidad_medida: string;
    bodega_nombre: string;
}

interface TrasladoItem {
    producto_id: string;
    cantidad: number;
    nombre_producto: string;
    unidad_medida: string;
}

interface Traslado {
    id: string;
    bodega_origen_nombre: string;
    bodega_destino_nombre: string;
    usuario_nombre: string;
    estado: string;
    items_count?: number;
    total_items?: number;
    notas: string | null;
    created_at: string;
}

export function Traslados() {
    const { user } = useAuth();
    const [bodegas, setBodegas] = useState<Bodega[]>([]);
    const [bodegaOrigen, setBodegaOrigen] = useState<Bodega | null>(null);
    const [bodegaDestino, setBodegaDestino] = useState<Bodega | null>(null);
    const [productos, setProductos] = useState<ProductoTraslado[]>([]);
    const [searchTerm, setSearchTerm] = useState('');
    const [cart, setCart] = useState<TrasladoItem[]>([]);
    const [loading, setLoading] = useState(false);
    const [traslados, setTraslados] = useState<Traslado[]>([]);
    const [showConfirm, setShowConfirm] = useState(false);
    const [processing, setProcessing] = useState(false);
    const [notas, setNotas] = useState('');

    useEffect(() => {
        if (user?.empresa_id) {
            fetchBodegas();
            fetchTraslados();
        }
    }, [user?.empresa_id]);

    useEffect(() => {
        if (bodegaOrigen) {
            fetchProductos(bodegaOrigen.id);
        }
    }, [bodegaOrigen]);

    const fetchBodegas = async () => {
        if (!user?.empresa_id) return;
        const { data, error } = await supabase.from('bodegas').select('*').eq('empresa_id', user.empresa_id).order('tipo');
        if (error) {
            toast.error('Error SQL: ' + error.message);
            return;
        }
        if (data && data.length > 0) {
            setBodegas(data);
            const general = data.find(b => b.tipo === 'general');
            const venta = data.find(b => b.tipo === 'venta');
            if (general) setBodegaOrigen(general);
            if (venta) setBodegaDestino(venta);
        } else {
            toast.error('No se encontraron bodegas. Verifica que existan en Supabase.');
        }
    };

    const fetchProductos = async (bodegaId: string) => {
        setLoading(true);
        try {
            const { data, error } = await supabase.rpc('get_inventory_por_bodega', {
                p_filtro_bodega: bodegaId
            });

            if (error) throw error;
            setProductos(data || []);
        } catch {
            toast.error('Error al cargar productos');
        } finally {
            setLoading(false);
        }
    };

    const fetchTraslados = async () => {
        try {
            const { data } = await supabase.rpc('listar_traslados');
            if (data) setTraslados(data);
        } catch {
            // Silencioso, no crítico
        }
    };

    const filteredProducts = useMemo(() => {
        if (!searchTerm) return productos;
        const q = searchTerm.toLowerCase();
        return productos.filter(p =>
            p.nombre_producto.toLowerCase().includes(q) ||
            (p.codigo_barra && p.codigo_barra.toLowerCase().includes(q)) ||
            (p.numero_lote && p.numero_lote.toLowerCase().includes(q))
        );
    }, [productos, searchTerm]);

    const addToCart = (producto: ProductoTraslado) => {
        const existing = cart.find(i => i.producto_id === producto.id);
        if (existing) {
            if (existing.cantidad >= producto.stock_actual) {
                toast.error('Stock maximo alcanzado');
                return;
            }
            setCart(prev => prev.map(i =>
                i.producto_id === producto.id
                    ? { ...i, cantidad: i.cantidad + 1 }
                    : i
            ));
            return;
        }
        setCart(prev => [...prev, {
            producto_id: producto.id,
            cantidad: 1,
            nombre_producto: producto.nombre_producto,
            unidad_medida: producto.unidad_medida
        }]);
    };

    const removeFromCart = (productoId: string) => {
        setCart(prev => prev.filter(i => i.producto_id !== productoId));
    };

    const updateCantidad = (productoId: string, delta: number) => {
        setCart(prev => prev.map(i => {
            if (i.producto_id !== productoId) return i;
            const nuevo = i.cantidad + delta;
            if (nuevo < 1) return i;
            return { ...i, cantidad: nuevo };
        }));
    };

    const handleTrasladar = async () => {
        if (!bodegaOrigen || !bodegaDestino || cart.length === 0) return;
        if (!user?.id) {
            toast.error('Usuario no identificado');
            return;
        }

        setProcessing(true);
        try {
            const items = cart.map(item => ({
                producto_id: item.producto_id,
                cantidad: item.cantidad
            }));

            const { error } = await supabase.rpc('crear_traslado', {
                p_bodega_destino_id: bodegaDestino.id,
                p_items: items,
                p_notas: notas || undefined,
                p_usuario_id: user.id
            });

            if (error) throw error;

            toast.success(`Traslado completado: ${cart.length} productos → ${bodegaDestino.nombre}`);
            setCart([]);
            setNotas('');
            setShowConfirm(false);
            fetchProductos(bodegaOrigen.id);
            fetchTraslados();
        } catch (err: unknown) {
            const message = err instanceof Error ? err.message : 'Error al trasladar';
            toast.error(message);
        } finally {
            setProcessing(false);
        }
    };

    const totalItems = cart.reduce((s, i) => s + i.cantidad, 0);

    return (
        <div className="max-w-7xl mx-auto p-6 space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
                        <ArrowRightLeft className="text-indigo-600" size={32} />
                        Traslados entre Bodegas
                    </h1>
                    <p className="text-gray-600 mt-2">Mover stock desde Bodega General a Bodega de Venta</p>
                </div>
            </div>

            {/* Selector de Bodegas */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="bg-white p-4 rounded-xl shadow-sm border">
                    <label className="text-xs font-semibold text-gray-500 uppercase mb-2 block">Origen</label>
                    <select
                        value={bodegaOrigen?.id || ''}
                        onChange={e => {
                            const b = bodegas.find(x => x.id === e.target.value);
                            if (b) setBodegaOrigen(b);
                            setCart([]);
                        }}
                        className="w-full p-3 border rounded-lg font-medium"
                    >
                        {bodegas.map(b => (
                            <option key={b.id} value={b.id}>{b.nombre} ({b.tipo})</option>
                        ))}
                    </select>
                </div>

                <div className="flex items-center justify-center">
                    <div className="bg-indigo-100 p-4 rounded-full">
                        <Truck size={32} className="text-indigo-600" />
                    </div>
                </div>

                <div className="bg-white p-4 rounded-xl shadow-sm border">
                    <label className="text-xs font-semibold text-gray-500 uppercase mb-2 block">Destino</label>
                    <select
                        value={bodegaDestino?.id || ''}
                        onChange={e => {
                            const b = bodegas.find(x => x.id === e.target.value);
                            if (b) setBodegaDestino(b);
                        }}
                        className="w-full p-3 border rounded-lg font-medium"
                    >
                        {bodegas.filter(b => b.id !== bodegaOrigen?.id).map(b => (
                            <option key={b.id} value={b.id}>{b.nombre} ({b.tipo})</option>
                        ))}
                    </select>
                </div>
            </div>

            {/* Búsqueda y Lista de Productos */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div className="lg:col-span-2 bg-white rounded-2xl shadow-sm border p-6">
                    <div className="relative mb-4">
                        <Search className="absolute left-3 top-3.5 text-gray-400" size={18} />
                        <input
                            type="text"
                            placeholder="Buscar producto en bodega origen..."
                            value={searchTerm}
                            onChange={e => setSearchTerm(e.target.value)}
                            className="w-full pl-10 pr-4 py-3 rounded-xl border focus:ring-2 focus:ring-indigo-500 outline-none"
                        />
                    </div>

                    <div className="max-h-96 overflow-y-auto custom-scrollbar">
                        {loading ? (
                            <div className="flex justify-center py-12">
                                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-500" />
                            </div>
                        ) : (
                            <table className="w-full">
                                <thead className="bg-gray-50 text-xs uppercase text-gray-500 sticky top-0">
                                    <tr>
                                        <th className="p-3 text-left">Producto</th>
                                        <th className="p-3 text-left">Vencimiento</th>
                                        <th className="p-3 text-right">Stock</th>
                                        <th className="p-3 text-center">Acción</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y">
                                    {filteredProducts.map(p => (
                                        <tr key={p.id} className="hover:bg-indigo-50">
                                            <td className="p-3">
                                                <div className="font-medium">{p.nombre_producto}</div>
                                                <div className="text-xs text-gray-400">{p.codigo_barra || 'S/C'} · {p.unidad_medida}</div>
                                            </td>
                                            <td className="p-3">
                                                <div className="text-sm text-gray-700 font-medium">
                                                    {p.fecha_vencimiento ? format(new Date(p.fecha_vencimiento), 'dd/MM/yyyy') : 'S/V'}
                                                </div>
                                            </td>
                                            <td className="p-3 text-right font-bold">{p.stock_actual}</td>
                                            <td className="p-3 text-center">
                                                <button
                                                    onClick={() => addToCart(p)}
                                                    disabled={p.stock_actual <= 0}
                                                    className="px-3 py-1.5 bg-indigo-100 text-indigo-700 rounded-lg text-sm font-medium hover:bg-indigo-200 disabled:opacity-30"
                                                >
                                                    + Agregar
                                                </button>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        )}
                    </div>
                </div>

                {/* Carrito de Traslado */}
                <div className="bg-white rounded-2xl shadow-sm border p-6 flex flex-col">
                    <h3 className="font-bold text-gray-800 mb-4 flex items-center gap-2">
                        <Package size={20} />
                        Productos a Trasladar ({totalItems})
                    </h3>

                    <div className="flex-1 space-y-3 max-h-80 overflow-y-auto custom-scrollbar">
                        {cart.map(item => (
                            <div key={item.producto_id} className="bg-gray-50 p-3 rounded-xl">
                                <div className="flex justify-between items-start mb-2">
                                    <p className="font-medium text-sm">{item.nombre_producto}</p>
                                    <button onClick={() => removeFromCart(item.producto_id)} className="text-red-400 hover:text-red-600">
                                        <X size={16} />
                                    </button>
                                </div>
                                <div className="flex items-center gap-2">
                                    <button onClick={() => updateCantidad(item.producto_id, -1)} className="w-7 h-7 rounded bg-gray-200 hover:bg-gray-300 font-bold">-</button>
                                    <span className="w-10 text-center font-bold">{item.cantidad}</span>
                                    <button onClick={() => updateCantidad(item.producto_id, 1)} className="w-7 h-7 rounded bg-gray-200 hover:bg-gray-300 font-bold">+</button>
                                    <span className="text-xs text-gray-500 ml-auto">{item.unidad_medida}</span>
                                </div>
                            </div>
                        ))}
                        {cart.length === 0 && (
                            <div className="text-center text-gray-400 py-8">
                                <Package size={40} className="mx-auto mb-2 opacity-30" />
                                <p className="text-sm">Agrega productos para trasladar</p>
                            </div>
                        )}
                    </div>

                    {cart.length > 0 && (
                        <div className="mt-4 space-y-3">
                            <input
                                type="text"
                                placeholder="Notas del traslado (opcional)"
                                value={notas}
                                onChange={e => setNotas(e.target.value)}
                                className="w-full p-2.5 border rounded-lg text-sm"
                            />
                            <Button onClick={() => setShowConfirm(true)} className="w-full">
                                <Truck size={18} className="mr-2" />
                                Trasladar a {bodegaDestino?.nombre || '...'}
                            </Button>
                        </div>
                    )}
                </div>
            </div>

            {/* Historial de Traslados */}
            <div className="bg-white rounded-2xl shadow-sm border p-6">
                <h2 className="text-lg font-bold text-gray-800 mb-4 flex items-center gap-2">
                    <ArrowRightLeft size={20} className="text-gray-500" />
                    Historial de Traslados
                </h2>
                {traslados.length === 0 ? (
                    <p className="text-gray-500 text-center py-4">No hay traslados registrados</p>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                            <thead className="bg-gray-50">
                                <tr>
                                    <th className="p-3 text-left">Fecha</th>
                                    <th className="p-3 text-left">Origen → Destino</th>
                                    <th className="p-3 text-center">Items</th>
                                    <th className="p-3 text-left">Usuario</th>
                                    <th className="p-3 text-left">Notas</th>
                                    <th className="p-3 text-center">Estado</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y">
                                {traslados.map(t => (
                                    <tr key={t.id}>
                                        <td className="p-3 text-gray-500">
                                            {format(new Date(t.created_at), 'dd/MM/yy HH:mm', { locale: es })}
                                        </td>
                                        <td className="p-3">
                                            <span className="font-medium">{t.bodega_origen_nombre}</span>
                                            <span className="mx-2 text-gray-400">→</span>
                                            <span className="font-medium">{t.bodega_destino_nombre}</span>
                                        </td>
                                        <td className="p-3 text-center font-bold">{t.items_count || t.total_items || 0}</td>
                                        <td className="p-3">{t.usuario_nombre}</td>
                                        <td className="p-3 text-gray-500 max-w-[200px] truncate">{t.notas || '-'}</td>
                                        <td className="p-3 text-center">
                                            <span className={`px-2 py-1 rounded-full text-xs font-bold ${
                                                t.estado === 'COMPLETADO' ? 'bg-green-100 text-green-700' :
                                                t.estado === 'PENDIENTE' ? 'bg-yellow-100 text-yellow-700' : 'bg-red-100 text-red-700'
                                            }`}>
                                                {t.estado}
                                            </span>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>

            {/* Modal de Confirmación */}
            <Modal
                isOpen={showConfirm}
                onClose={() => setShowConfirm(false)}
                title="Confirmar Traslado"
                size="sm"
            >
                <div className="space-y-4">
                    <div className="bg-amber-50 p-4 rounded-xl border border-amber-200">
                        <div className="flex items-start gap-3">
                            <AlertTriangle className="text-amber-600 flex-shrink-0" size={24} />
                            <div>
                                <p className="font-bold text-amber-800">¿Confirmar traslado?</p>
                                <p className="text-sm text-amber-700 mt-1">
                                    Se moverán {totalItems} productos desde{' '}
                                    <strong>{bodegaOrigen?.nombre}</strong> hacia{' '}
                                    <strong>{bodegaDestino?.nombre}</strong>.
                                </p>
                                <p className="text-xs text-amber-600 mt-2">
                                    Esta acción descuenta el stock del origen y lo suma al destino inmediatamente.
                                </p>
                            </div>
                        </div>
                    </div>

                    <div className="flex gap-3">
                        <Button variant="secondary" onClick={() => setShowConfirm(false)} className="flex-1">
                            Cancelar
                        </Button>
                        <Button onClick={handleTrasladar} isLoading={processing} className="flex-1">
                            <Check size={18} className="mr-2" />
                            Confirmar Traslado
                        </Button>
                    </div>
                </div>
            </Modal>
        </div>
    );
}
