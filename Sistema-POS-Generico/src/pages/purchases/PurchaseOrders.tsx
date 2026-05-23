import React, { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Plus, Eye, Search, Truck, Box } from 'lucide-react';
import { Link } from 'react-router-dom';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

interface PurchaseOrder {
    id: string;
    folio: number;
    proveedor: { nombre: string } | null;
    usuario: { name: string; email: string } | null;
    estado: string;
    fecha_creacion: string;
    total_estimado: number;
}

export function PurchaseOrders() {
    const [orders, setOrders] = useState<PurchaseOrder[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');

    useEffect(() => {
        fetchOrders();
    }, []);

    const fetchOrders = async () => {
        try {
            const { data, error } = await supabase
                .from('ordenes_compra')
                .select(`
                    *,
                    proveedor:proveedores(nombre),
                    usuario:users(name, email)
                `)
                .order('fecha_creacion', { ascending: false });

            if (error) throw error;
            setOrders(data || []);
        } catch {
            setLoading(false);
            return;
        } finally {
            setLoading(false);
        }
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'BORRADOR': return 'bg-gray-100 text-gray-800';
            case 'EMITIDA': return 'bg-blue-100 text-blue-800';
            case 'RECEPCION_PARCIAL': return 'bg-yellow-100 text-yellow-800';
            case 'COMPLETADA': return 'bg-green-100 text-green-800';
            case 'CANCELADA': return 'bg-red-100 text-red-800';
            default: return 'bg-gray-100 text-gray-800';
        }
    };

    const filteredOrders = orders.filter(order =>
        order.proveedor?.nombre?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        order.folio.toString().includes(searchTerm)
    );

    return (
        <div className="p-6">
            <div className="flex justify-between items-center mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
                        <Truck className="text-blue-600" />
                        Órdenes de Compra
                    </h1>
                    <p className="text-gray-500">Gestión de abastecimiento y proveedores</p>
                </div>
                <Link
                    to="/purchases/new"
                    className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg flex items-center gap-2 font-medium transition-colors"
                >
                    <Plus size={20} />
                    Nueva Orden
                </Link>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-4 border-b border-gray-100">
                    <div className="relative max-w-md">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                        <input
                            type="text"
                            placeholder="Buscar por proveedor o folio..."
                            className="w-full pl-10 pr-4 py-2 rounded-lg border border-gray-200 focus:ring-2 focus:ring-blue-500 outline-none"
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                        />
                    </div>
                </div>

                <div className="overflow-x-auto">
                    <table className="w-full text-left text-sm">
                        <thead className="bg-gray-50 text-gray-500 font-medium">
                            <tr>
                                <th className="px-6 py-4">Folio</th>
                                <th className="px-6 py-4">Proveedor</th>
                                <th className="px-6 py-4">Estado</th>
                                <th className="px-6 py-4">Fecha</th>
                                <th className="px-6 py-4 text-right">Total Est.</th>
                                <th className="px-6 py-4 text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                            {loading ? (
                                <tr>
                                    <td colSpan={6} className="px-6 py-8 text-center text-gray-500">Cargando órdenes...</td>
                                </tr>
                            ) : filteredOrders.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="px-6 py-8 text-center text-gray-500">No se encontraron órdenes de compra</td>
                                </tr>
                            ) : (
                                filteredOrders.map((order) => (
                                    <tr key={order.id} className="hover:bg-gray-50 transition-colors">
                                        <td className="px-6 py-4 font-bold text-gray-900">#{order.folio}</td>
                                        <td className="px-6 py-4">{order.proveedor?.nombre || 'Proveedor Eliminado'}</td>
                                        <td className="px-6 py-4">
                                            <span className={`px-2 py-1 rounded-full text-xs font-bold ${getStatusColor(order.estado)}`}>
                                                {order.estado.replace('_', ' ')}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-gray-500">
                                            {format(new Date(order.fecha_creacion), 'dd MMM yyyy', { locale: es })}
                                        </td>
                                        <td className="px-6 py-4 text-right font-medium">
                                            ${order.total_estimado.toLocaleString()}
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <div className="flex justify-end gap-2">
                                                {(order.estado === 'EMITIDA' || order.estado === 'RECEPCION_PARCIAL') && (
                                                    <Link to={`/purchases/${order.id}/receive`} className="text-blue-600 hover:text-blue-800" title="Recepcionar Mercadería">
                                                        <Box size={18} />
                                                    </Link>
                                                )}
                                                <button className="text-gray-400 hover:text-blue-600 transition-colors">
                                                    <Eye size={18} />
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}
