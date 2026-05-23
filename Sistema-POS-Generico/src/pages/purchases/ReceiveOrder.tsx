import React, { useCallback, useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabase';
import { ArrowLeft, Box, Check, Save } from 'lucide-react';
import { toast } from 'react-hot-toast';
import { useAuth } from '../../contexts/AuthContext';
import { Button } from '../../components/ui/Button';
import { LabelPrinter } from '../../components/purchases/LabelPrinter';

interface ReceptionItem {
    detalle_id: string;
    maestro_producto_nombre: string;
    pendiente: number;
    cantidad_a_recibir: number;
    lote: string;
    vencimiento: string;
}

interface OrderDetailRow {
    id: string;
    cantidad_solicitada: number;
    cantidad_recibida: number;
    maestro_producto: {
        nombre: string;
        codigo_barra: string;
    };
}

interface LabelItem {
    id: string;
    nombre: string;
    lote: string;
    vencimiento: string;
    cantidad: number;
}

export function ReceiveOrder() {
    const { id } = useParams();
    const navigate = useNavigate();
    const { user } = useAuth();
    const [loading, setLoading] = useState(true);
    const [items, setItems] = useState<ReceptionItem[]>([]);
    const [orderFolio, setOrderFolio] = useState<string>('');
    const [showLabels, setShowLabels] = useState(false);
    const [labelItems, setLabelItems] = useState<LabelItem[]>([]);

  const fetchOrderDetails = useCallback(async () => {
    try {
      // Get Header for Folio
      const { data: header } = await supabase.from('ordenes_compra').select('folio, estado').eq('id', id).single();
      if (header) setOrderFolio(header.folio);

      // Get Details
      const { data } = await supabase
        .from('detalle_ordenes_compra')
        .select(`
            id,
            cantidad_solicitada,
            cantidad_recibida,
            maestro_producto:maestro_productos(nombre, codigo_barra)
        `)
        .eq('orden_id', id);

      if (data) {
        // Initialize reception items
        const mapped: ReceptionItem[] = data.map((d: OrderDetailRow) => ({
            detalle_id: d.id,
            maestro_producto_nombre: d.maestro_producto.nombre,
            pendiente: d.cantidad_solicitada - (d.cantidad_recibida || 0),
            cantidad_a_recibir: d.cantidad_solicitada - (d.cantidad_recibida || 0),
            lote: '',
            vencimiento: ''
        })).filter(i => i.pendiente > 0); // Only show items pending reception

        setItems(mapped);
      }
    } catch {
      toast.error('Error al cargar orden');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    if (id) fetchOrderDetails();
  }, [id, fetchOrderDetails]);

    const handleInputChange = (index: number, field: keyof ReceptionItem, value: string | number) => {
        const newItems = [...items];
        newItems[index] = { ...newItems[index], [field]: value };
        setItems(newItems);
    };

    const handleSubmit = async () => {
        const validItems = items.filter(i => i.cantidad_a_recibir > 0);

        // Validation
        for (const item of validItems) {
            if (!item.lote) return toast.error(`Falta lote para ${item.maestro_producto_nombre}`);
            if (!item.vencimiento) return toast.error(`Falta vencimiento para ${item.maestro_producto_nombre}`);
        }

        if (validItems.length === 0) return toast.error('No hay items para recepcionar');

        if (!confirm('¿Confirmar recepción de mercadería? Esto actualizará el inventario.')) return;

        setLoading(true);
        try {
            const payload = validItems.map(i => ({
                detalle_id: i.detalle_id,
                cantidad: i.cantidad_a_recibir,
                lote: i.lote,
                vencimiento: i.vencimiento
            }));

            const { error } = await supabase.rpc('recepcionar_orden_compra', {
                p_orden_id: id,
                p_usuario_id: user?.id,
                p_items: payload
            });

            if (error) throw error;

            toast.success('Recepción completada exitosamente');

            // Prepare labels
            const labelsStr = validItems.map(i => ({
                id: i.detalle_id,
                nombre: i.maestro_producto_nombre,
                lote: i.lote,
                vencimiento: i.vencimiento,
                cantidad: i.cantidad_a_recibir
            }));
            setLabelItems(labelsStr);
            setShowLabels(true);

            // navigate('/purchases'); // Move navigation to modal close
        } catch {
            toast.error('Error al recibir orden');
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div className="p-6">Cargando...</div>;

    return (
        <div className="p-6 max-w-5xl mx-auto">
            <div className="flex items-center gap-4 mb-6">
                <button onClick={() => navigate('/purchases')} className="p-2 hover:bg-gray-100 rounded-full text-gray-500">
                    <ArrowLeft size={20} />
                </button>
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Recepción de Mercadería</h1>
                    <p className="text-gray-500">Orden #{orderFolio}</p>
                </div>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-6 border-b border-gray-100 bg-blue-50">
                    <p className="text-sm text-blue-800 flex items-center gap-2">
                        <Box size={16} />
                        Ingresa el Lote y Vencimiento físico de los productos que estás recibiendo.
                    </p>
                </div>

                <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead className="bg-gray-50 text-gray-500 font-medium">
                            <tr>
                                <th className="px-6 py-4 text-left">Producto</th>
                                <th className="px-6 py-4 text-center">Pendiente</th>
                                <th className="px-6 py-4 w-32">Recibir</th>
                                <th className="px-6 py-4 w-40">Lote</th>
                                <th className="px-6 py-4 w-40">Vencimiento</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                            {items.map((item, idx) => (
                                <tr key={item.detalle_id} className="hover:bg-gray-50">
                                    <td className="px-6 py-4 font-medium text-gray-900">{item.maestro_producto_nombre}</td>
                                    <td className="px-6 py-4 text-center text-gray-500">{item.pendiente}</td>
                                    <td className="px-6 py-4">
                                        <input
                                            type="number"
                                            className="w-full p-2 border border-gray-200 rounded-lg text-center font-bold"
                                            value={item.cantidad_a_recibir}
                                            max={item.pendiente}
                                            min={0}
                                            onChange={e => handleInputChange(idx, 'cantidad_a_recibir', Number(e.target.value))}
                                        />
                                    </td>
                                    <td className="px-6 py-4">
                                        <input
                                            type="text"
                                            placeholder="LOTE-001"
                                            className="w-full p-2 border border-gray-200 rounded-lg uppercase"
                                            value={item.lote}
                                            onChange={e => handleInputChange(idx, 'lote', e.target.value.toUpperCase())}
                                        />
                                    </td>
                                    <td className="px-6 py-4">
                                        <input
                                            type="date"
                                            className="w-full p-2 border border-gray-200 rounded-lg"
                                            value={item.vencimiento}
                                            onChange={e => handleInputChange(idx, 'vencimiento', e.target.value)}
                                        />
                                    </td>
                                </tr>
                            ))}
                            {items.length === 0 && (
                                <tr>
                                    <td colSpan={5} className="p-8 text-center text-green-600 font-bold">
                                        <Check size={32} className="mx-auto mb-2" />
                                        ¡Orden completada! No hay items pendientes.
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>

                <div className="p-6 bg-gray-50 border-t border-gray-200 flex justify-end">
                    <Button onClick={handleSubmit} disabled={items.length === 0}>
                        <Save className="mr-2 h-4 w-4" />
                        Confirmar Entrada a Bodega
                    </Button>
                </div>
            </div>


            <LabelPrinter
                isOpen={showLabels}
                onClose={() => {
                    setShowLabels(false);
                    navigate('/purchases');
                }}
                items={labelItems}
            />
        </div >
    );
}
