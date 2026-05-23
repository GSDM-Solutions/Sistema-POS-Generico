import React, { useState, useEffect, useRef } from 'react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { ConfirmModal } from '../../components/ui/ConfirmModal';
import { toast } from 'react-hot-toast';
import {
    AlertTriangle,
    Search,
    X,
    ArrowDown,
    ArrowUp,
    Package,
    ClipboardList
} from 'lucide-react';

const MOTIVOS_AJUSTE = [
    { value: 'Consumo Interno', label: 'Consumo Interno' },
    { value: 'Caida a Piso', label: 'Caida a Piso' },
    { value: 'Producto Roto/Danado', label: 'Producto Roto/Danado' },
    { value: 'Merma', label: 'Merma' },
    { value: 'Otro', label: 'Otro' },
];

interface ProductSearchResult {
    maestro_id: string;
    nombre_producto: string;
    codigo_barra: string;
    stock_actual: number;
    unidad_medida?: string;
}

export function DirectAdjustment() {
    const { user } = useAuth();
    const [searchTerm, setSearchTerm] = useState('');
    const [searchResults, setSearchResults] = useState<ProductSearchResult[]>([]);
    const [selectedProduct, setSelectedProduct] = useState<ProductSearchResult | null>(null);
    const [showDropdown, setShowDropdown] = useState(false);
    const [quantity, setQuantity] = useState<number>(1);
    const [direction, setDirection] = useState<'DESCONTAR' | 'AGREGAR'>('DESCONTAR');
    const [motivo, setMotivo] = useState('');
    const [motivoOtro, setMotivoOtro] = useState('');
    const [bodegas, setBodegas] = useState<{ id: string; nombre: string }[]>([]);
    const [bodegaId, setBodegaId] = useState('');
    const [productStock, setProductStock] = useState<number>(0);
    const [confirmSubmit, setConfirmSubmit] = useState(false);
    const [loading, setLoading] = useState(false);
    const [history, setHistory] = useState<any[]>([]);
    const searchTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

    useEffect(() => {
        fetchBodegas();
        fetchHistory();
    }, []);

    const fetchBodegas = async () => {
        const { data } = await supabase.from('bodegas').select('id, nombre').eq('empresa_id', user?.empresa_id).eq('activo', true);
        if (data && data.length > 0) {
            setBodegas(data);
            setBodegaId(data[0].id);
        }
    };

    const fetchHistory = async () => {
        const { data } = await supabase
            .from('inventory_sessions')
            .select('*, inventory_session_results(*)')
            .eq('empresa_id', user?.empresa_id)
            .eq('tipo', 'AJUSTE_DIRECTO')
            .order('fecha_inicio', { ascending: false })
            .limit(20);
        setHistory(data || []);
    };

    const searchProducts = (term: string) => {
        setSearchTerm(term);
        if (searchTimeoutRef.current) clearTimeout(searchTimeoutRef.current);

        if (term.length < 2) {
            setSearchResults([]);
            setShowDropdown(false);
            return;
        }

        searchTimeoutRef.current = setTimeout(async () => {
            const { data } = await supabase.rpc('search_products_pos', { p_query: term });
            if (data) {
                const unique: ProductSearchResult[] = [];
                const seen = new Set<string>();
                for (const p of data) {
                    if (!seen.has(p.maestro_id)) {
                        seen.add(p.maestro_id);
                        unique.push(p);
                    }
                }
                setSearchResults(unique);
                setShowDropdown(unique.length > 0);
            }
        }, 300);
    };

    const selectProduct = async (product: ProductSearchResult) => {
        setSelectedProduct(product);
        setSearchTerm(product.nombre_producto);
        setShowDropdown(false);

        const { data } = await supabase
            .from('productos')
            .select('stock_actual')
            .eq('maestro_producto_id', product.maestro_id)
            .eq('empresa_id', user?.empresa_id)
            .eq('bodega_id', bodegaId)
            .gt('stock_actual', 0);

        const totalStock = data?.reduce((sum, p) => sum + Number(p.stock_actual), 0) || 0;
        setProductStock(totalStock);
    };

    const clearProduct = () => {
        setSelectedProduct(null);
        setSearchTerm('');
        setSearchResults([]);
        setShowDropdown(false);
        setProductStock(0);
    };

    const handleSubmit = () => {
        if (!selectedProduct) { toast.error('Seleccione un producto'); return; }
        if (!quantity || quantity <= 0) { toast.error('Ingrese una cantidad valida'); return; }
        if (!bodegaId) { toast.error('Seleccione una bodega'); return; }

        const motivoFinal = motivo === 'Otro' ? motivoOtro.trim() : motivo;
        if (!motivoFinal) { toast.error('Seleccione o escriba un motivo'); return; }

        if (direction === 'DESCONTAR' && quantity > productStock) {
            toast.error(`Stock insuficiente. Disponible: ${productStock}`);
            return;
        }

        setConfirmSubmit(true);
    };

    const doSubmit = async () => {
        setConfirmSubmit(false);
        if (!user || !selectedProduct) return;
        setLoading(true);

        const cantidadAjuste = direction === 'DESCONTAR' ? -quantity : quantity;
        const motivoFinal = motivo === 'Otro' ? motivoOtro.trim() : motivo;

        const { error } = await supabase.rpc('registrar_ajuste_directo', {
            p_maestro_producto_id: selectedProduct.maestro_id,
            p_bodega_id: bodegaId,
            p_cantidad_diferencia: cantidadAjuste,
            p_motivo: motivoFinal,
            p_usuario_id: user.id,
            p_empresa_id: user.empresa_id
        });

        if (error) {
            toast.error('Error: ' + ((error as any).message || 'Error desconocido'));
        } else {
            const dir = direction === 'DESCONTAR' ? 'descontados' : 'agregados';
            toast.success(`Ajuste aplicado: ${quantity} unidades ${dir} por "${motivoFinal}"`);
            setSelectedProduct(null);
            setSearchTerm('');
            setQuantity(1);
            setMotivo('');
            setMotivoOtro('');
            setProductStock(0);
            setDirection('DESCONTAR');
            fetchHistory();
        }
        setLoading(false);
    };

    return (
        <div className="max-w-4xl mx-auto space-y-8">
            <div>
                <h2 className="text-2xl font-bold text-gray-800">Ajuste Directo de Inventario</h2>
                <p className="text-gray-500 mt-1">Registre consumos, roturas, mermas u otros ajustes manuales de stock.</p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <Card className="p-6">
                    <h3 className="font-bold text-gray-700 mb-4 flex items-center gap-2">
                        <Package size={20} /> Nuevo Ajuste
                    </h3>

                    {/* Product Search */}
                    <div className="mb-4">
                        <label className="block text-sm font-medium text-gray-700 mb-1">Producto</label>
                        <div className="relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                            <input
                                value={searchTerm}
                                onChange={e => searchProducts(e.target.value)}
                                onFocus={() => { if (searchResults.length > 0) setShowDropdown(true); }}
                                onBlur={() => setTimeout(() => setShowDropdown(false), 200)}
                                className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                placeholder="Buscar producto por nombre o codigo..."
                            />
                            {selectedProduct && (
                                <button onClick={clearProduct} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-red-500">
                                    <X size={16} />
                                </button>
                            )}
                            {showDropdown && (
                                <div className="absolute z-20 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                                    {searchResults.map(p => (
                                        <button
                                            key={p.maestro_id}
                                            onMouseDown={() => selectProduct(p)}
                                            className="w-full text-left px-4 py-2.5 hover:bg-blue-50 text-sm border-b border-gray-50 last:border-0"
                                        >
                                            <span className="font-medium">{p.nombre_producto}</span>
                                            {p.codigo_barra && <span className="text-gray-400 ml-2">({p.codigo_barra})</span>}
                                        </button>
                                    ))}
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Stock Info */}
                    {selectedProduct && (
                        <div className="mb-4 p-3 bg-blue-50 rounded-lg border border-blue-100">
                            <p className="text-sm text-blue-700">
                                Stock actual en bodega: <span className="font-bold text-lg">{productStock}</span>
                            </p>
                        </div>
                    )}

                    {/* Bodega */}
                    <div className="mb-4">
                        <label className="block text-sm font-medium text-gray-700 mb-1">Bodega</label>
                        <select
                            value={bodegaId}
                            onChange={e => setBodegaId(e.target.value)}
                            className="w-full py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        >
                            {bodegas.map(b => (
                                <option key={b.id} value={b.id}>{b.nombre}</option>
                            ))}
                        </select>
                    </div>

                    {/* Direction */}
                    <div className="mb-4">
                        <label className="block text-sm font-medium text-gray-700 mb-1">Tipo de Ajuste</label>
                        <div className="flex gap-2">
                            <button
                                type="button"
                                onClick={() => setDirection('DESCONTAR')}
                                className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg border text-sm font-medium transition-colors ${
                                    direction === 'DESCONTAR'
                                        ? 'bg-red-50 border-red-300 text-red-700'
                                        : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'
                                }`}
                            >
                                <ArrowDown size={16} /> Reducir Stock
                            </button>
                            <button
                                type="button"
                                onClick={() => setDirection('AGREGAR')}
                                className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg border text-sm font-medium transition-colors ${
                                    direction === 'AGREGAR'
                                        ? 'bg-green-50 border-green-300 text-green-700'
                                        : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'
                                }`}
                            >
                                <ArrowUp size={16} /> Aumentar Stock
                            </button>
                        </div>
                    </div>

                    {/* Quantity */}
                    <div className="mb-4">
                        <label className="block text-sm font-medium text-gray-700 mb-1">Cantidad</label>
                        <input
                            type="number"
                            min={1}
                            value={quantity}
                            onChange={e => setQuantity(Math.max(1, Number(e.target.value)))}
                            className="w-full py-2.5 text-center text-lg border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        />
                    </div>

                    {/* Motivo */}
                    <div className="mb-6">
                        <label className="block text-sm font-medium text-gray-700 mb-1">Motivo del Ajuste</label>
                        <select
                            value={motivo}
                            onChange={e => setMotivo(e.target.value)}
                            className="w-full py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        >
                            <option value="">Seleccione un motivo...</option>
                            {MOTIVOS_AJUSTE.map(m => (
                                <option key={m.value} value={m.value}>{m.label}</option>
                            ))}
                        </select>
                        {motivo === 'Otro' && (
                            <input
                                value={motivoOtro}
                                onChange={e => setMotivoOtro(e.target.value)}
                                className="w-full mt-2 py-2.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                placeholder="Especifique el motivo..."
                            />
                        )}
                    </div>

                    <Button
                        onClick={handleSubmit}
                        disabled={loading || !selectedProduct}
                        className="w-full bg-slate-800 text-white hover:bg-slate-900"
                    >
                        <AlertTriangle className="mr-2" size={18} />
                        Aplicar Ajuste
                    </Button>
                </Card>

                {/* History */}
                <Card className="p-6">
                    <h3 className="font-bold text-gray-700 mb-4 flex items-center gap-2">
                        <ClipboardList size={20} /> Ultimos Ajustes Directos
                    </h3>
                    <div className="overflow-y-auto max-h-[500px]">
                        {history.length === 0 ? (
                            <p className="text-gray-400 text-sm italic text-center py-8">Sin ajustes directos registrados</p>
                        ) : (
                            <div className="space-y-2">
                                {history.map((s: any) => (
                                    <div key={s.id} className="p-3 bg-gray-50 rounded-lg border border-gray-100 text-sm">
                                        <div className="flex justify-between items-start">
                                            <div>
                                                <p className="font-medium text-gray-700">{s.motivo_ajuste || 'Ajuste'}</p>
                                                <p className="text-xs text-gray-400">
                                                    {new Date(s.fecha_inicio).toLocaleDateString('es-CL', {
                                                        day: '2-digit', month: '2-digit', year: 'numeric',
                                                        hour: '2-digit', minute: '2-digit'
                                                    })}
                                                </p>
                                            </div>
                                            <span className="px-2 py-0.5 bg-green-100 text-green-700 rounded-full text-xs font-bold">
                                                APLICADO
                                            </span>
                                        </div>
                                        {s.inventory_session_results?.map((r: any) => (
                                            <div key={r.id} className="mt-2 flex justify-between items-center text-xs">
                                                <span className="text-gray-600">{r.nombre_producto}</span>
                                                <span className={`font-bold ${Number(r.diferencia) < 0 ? 'text-red-600' : 'text-green-600'}`}>
                                                    {Number(r.diferencia) > 0 ? '+' : ''}{r.diferencia}
                                                </span>
                                            </div>
                                        ))}
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </Card>
            </div>

            <ConfirmModal
                isOpen={confirmSubmit}
                onClose={() => setConfirmSubmit(false)}
                onConfirm={doSubmit}
                title="Confirmar Ajuste Directo"
                message={`${direction === 'DESCONTAR' ? 'Reducir' : 'Aumentar'} el stock de "${selectedProduct?.nombre_producto}" en ${quantity} unidades por motivo: "${motivo === 'Otro' ? motivoOtro : motivo}"? Esta accion es irreversible.`}
                confirmText="Confirmar Ajuste"
                variant="danger"
            />
        </div>
    );
}
