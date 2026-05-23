import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Plus, Trash2, Save, Send } from 'lucide-react';
import { toast } from 'react-hot-toast';
import { useAuth } from '../../contexts/AuthContext';
import { Button } from '../../components/ui/Button';

interface Provider {
    id: string;
    nombre: string;
}

interface MasterProduct {
    id: string;
    nombre: string;
    categoria: string;
}

interface OrderItem {
    tempId: string;
    maestro_producto_id: string;
    nombre_producto: string; // For display
    cantidad: number;
    costo_unitario: number;
}

export function CreatePurchaseOrder() {
    const navigate = useNavigate();
    const { user } = useAuth();
    const [providers, setProviders] = useState<Provider[]>([]);
    const [products, setProducts] = useState<MasterProduct[]>([]);

    // Form State
    const [selectedProvider, setSelectedProvider] = useState('');
    const [items, setItems] = useState<OrderItem[]>([]);
    const [observations, setObservations] = useState('');
    const [loading, setLoading] = useState(false);

    // Item Input State
    const [selectedProduct, setSelectedProduct] = useState('');
    const [quantity, setQuantity] = useState(1);
    const [cost, setCost] = useState(0);

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        const { data: provs } = await supabase.from('proveedores').select('id, nombre').order('nombre');
        const { data: prods } = await supabase.from('maestro_productos').select('id, nombre, categoria').order('nombre');

        setProviders(provs || []);
        setProducts(prods || []);
    };

    const addItem = () => {
        if (!selectedProduct || quantity <= 0) return;

        const product = products.find(p => p.id === selectedProduct);
        if (!product) return;

        setItems(prev => [...prev, {
            tempId: crypto.randomUUID(),
            maestro_producto_id: selectedProduct,
            nombre_producto: product.nombre,
            cantidad: quantity,
            costo_unitario: cost
        }]);

        // Reset inputs
        setSelectedProduct('');
        setQuantity(1);
        setCost(0);
    };

    const removeItem = (tempId: string) => {
        setItems(prev => prev.filter(i => i.tempId !== tempId));
    };

    const handleSubmit = async (status: 'BORRADOR' | 'EMITIDA') => {
        if (!selectedProvider) return toast.error('Seleccione un proveedor');
        if (items.length === 0) return toast.error('Agregue al menos un producto');

        setLoading(true);
        try {
            const total = items.reduce((sum, item) => sum + (item.cantidad * item.costo_unitario), 0);

            // 1. Create Header
            const { data: order, error: orderError } = await supabase
                .from('ordenes_compra')
                .insert({
                    proveedor_id: selectedProvider,
                    usuario_id: user?.id,
                    estado: status,
                    observaciones: observations,
                    total_estimado: total
                })
                .select()
                .single();

            if (orderError) throw orderError;

            // 2. Create Details
            const details = items.map(item => ({
                orden_id: order.id,
                maestro_producto_id: item.maestro_producto_id,
                cantidad_solicitada: item.cantidad,
                costo_unitario: item.costo_unitario
            }));

            const { error: detailsError } = await supabase
                .from('detalle_ordenes_compra')
                .insert(details);

            if (detailsError) throw detailsError;

            toast.success(`Orden ${status === 'BORRADOR' ? 'guardada' : 'emitida'} correctamente`);
            navigate('/purchases');

        } catch {
            toast.error('Error al crear orden');
        } finally {
            setLoading(false);
        }
    };

    const totalOrder = items.reduce((sum, item) => sum + (item.cantidad * item.costo_unitario), 0);

    return (
        <div className="p-6 max-w-5xl mx-auto">
            <div className="flex items-center gap-4 mb-6">
                <button onClick={() => navigate('/purchases')} className="p-2 hover:bg-gray-100 rounded-full text-gray-500">
                    <ArrowLeft size={20} />
                </button>
                <h1 className="text-2xl font-bold text-gray-900">Nueva Orden de Compra</h1>
            </div>

            <div className="grid grid-cols-3 gap-6">
                {/* Main Form */}
                <div className="col-span-2 space-y-6">
                    {/* Items Section */}
                    <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                        <h2 className="font-bold text-gray-800 mb-4">Items de la Orden</h2>

                        <div className="flex gap-3 mb-4 items-end bg-gray-50 p-4 rounded-lg">
                            <div className="flex-1">
                                <label className="block text-xs font-semibold text-gray-500 mb-1">Producto</label>
                                <select
                                    className="w-full p-2 border border-gray-200 rounded-lg text-sm"
                                    value={selectedProduct}
                                    onChange={e => setSelectedProduct(e.target.value)}
                                >
                                    <option value="">Seleccionar...</option>
                                    {products.map(p => (
                                        <option key={p.id} value={p.id}>{p.nombre}</option>
                                    ))}
                                </select>
                            </div>
                            <div className="w-24">
                                <label className="block text-xs font-semibold text-gray-500 mb-1">Cantidad</label>
                                <input
                                    type="number"
                                    min="1"
                                    className="w-full p-2 border border-gray-200 rounded-lg text-sm"
                                    value={quantity}
                                    onChange={e => setQuantity(Number(e.target.value))}
                                />
                            </div>
                            <div className="w-32">
                                <label className="block text-xs font-semibold text-gray-500 mb-1">Costo Unit.</label>
                                <input
                                    type="number"
                                    min="0"
                                    className="w-full p-2 border border-gray-200 rounded-lg text-sm"
                                    value={cost}
                                    onChange={e => setCost(Number(e.target.value))}
                                />
                            </div>
                            <button
                                onClick={addItem}
                                className="bg-blue-600 text-white p-2 rounded-lg hover:bg-blue-700"
                            >
                                <Plus size={20} />
                            </button>
                        </div>

                        <div className="overflow-hidden border border-gray-100 rounded-lg">
                            <table className="w-full text-sm">
                                <thead className="bg-gray-50 text-gray-500">
                                    <tr>
                                        <th className="px-4 py-3 text-left">Producto</th>
                                        <th className="px-4 py-3 text-right">Cant.</th>
                                        <th className="px-4 py-3 text-right">Costo U.</th>
                                        <th className="px-4 py-3 text-right">Total</th>
                                        <th className="px-4 py-3 w-10"></th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-gray-100">
                                    {items.map((item) => (
                                        <tr key={item.tempId}>
                                            <td className="px-4 py-2">{item.nombre_producto}</td>
                                            <td className="px-4 py-2 text-right">{item.cantidad}</td>
                                            <td className="px-4 py-2 text-right">${item.costo_unitario.toLocaleString()}</td>
                                            <td className="px-4 py-2 text-right font-medium">${(item.cantidad * item.costo_unitario).toLocaleString()}</td>
                                            <td className="px-4 py-2 text-center">
                                                <button onClick={() => removeItem(item.tempId)} className="text-red-400 hover:text-red-600">
                                                    <Trash2 size={16} />
                                                </button>
                                            </td>
                                        </tr>
                                    ))}
                                    {items.length === 0 && (
                                        <tr>
                                            <td colSpan={5} className="px-4 py-8 text-center text-gray-400 text-xs">
                                                Agrega productos a la orden
                                            </td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

                {/* Sidebar Details */}
                <div className="space-y-6">
                    <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                        <h2 className="font-bold text-gray-800 mb-4">Detalles Generales</h2>
                        <div className="space-y-4">
                            <div>
                                <label className="block text-xs font-semibold text-gray-500 mb-1">Proveedor</label>
                                <select
                                    className="w-full p-2 border border-gray-200 rounded-lg text-sm"
                                    value={selectedProvider}
                                    onChange={e => setSelectedProvider(e.target.value)}
                                >
                                    <option value="">Seleccionar Proveedor...</option>
                                    {providers.map(p => (
                                        <option key={p.id} value={p.id}>{p.nombre}</option>
                                    ))}
                                </select>
                            </div>
                            <div>
                                <label className="block text-xs font-semibold text-gray-500 mb-1">Observaciones</label>
                                <textarea
                                    className="w-full p-2 border border-gray-200 rounded-lg text-sm h-24 resize-none"
                                    value={observations}
                                    onChange={e => setObservations(e.target.value)}
                                    placeholder="Instrucciones o notas..."
                                />
                            </div>
                        </div>
                    </div>

                    <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                        <div className="flex justify-between items-center mb-4">
                            <span className="text-gray-500 font-medium">Total Estimado</span>
                            <span className="text-2xl font-bold text-gray-900">${totalOrder.toLocaleString()}</span>
                        </div>

                        <div className="space-y-3">
                            <Button
                                onClick={() => handleSubmit('BORRADOR')}
                                variant="secondary"
                                className="w-full flex justify-center gap-2"
                                disabled={loading || items.length === 0}
                            >
                                <Save size={18} />
                                Guardar Borrador
                            </Button>
                            <Button
                                onClick={() => handleSubmit('EMITIDA')}
                                className="w-full flex justify-center gap-2"
                                disabled={loading || items.length === 0}
                            >
                                <Send size={18} />
                                Emitir Orden
                            </Button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
