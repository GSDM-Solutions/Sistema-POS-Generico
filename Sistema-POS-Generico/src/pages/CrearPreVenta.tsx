import { useState, useRef, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { toast } from 'react-hot-toast';
import {
    Search, ShoppingCart, Plus, X, Save, Send, ArrowLeft, Minus, ScanLine
} from 'lucide-react';
import { Button } from '../components/ui/Button';
import { PreVentaVoucher } from '../components/pos/PreVentaVoucher';
import { PreVenta } from '../types/preventas';

interface Product {
    id: string;
    maestro_producto: { nombre: string; codigo_barra: string | null; precio_venta: number };
    stock_actual: number; factor_conversion: number;
    es_presentacion: boolean; nombre_presentacion: string | null;
    unidad_medida: string; controla_stock: boolean;
}
interface CartItem extends Product { quantity: number; cartItemId: string; }
interface Customer { id: string; nombre: string; rut: string; }

export function CrearPreVenta() {
    const { user } = useAuth();
    const navigate = useNavigate();
    const [scanCode, setScanCode] = useState('');
    const [scanQty, setScanQty] = useState(1);
    const [cart, setCart] = useState<CartItem[]>([]);
    const [loading, setLoading] = useState(false);
    const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
    const [customerSearch, setCustomerSearch] = useState('');
    const [customers, setCustomers] = useState<Customer[]>([]);
    const [notas, setNotas] = useState('');
    const scanInputRef = useRef<HTMLInputElement>(null);
    const [showVoucher, setShowVoucher] = useState(false);
    const [preVentaCreada, setPreVentaCreada] = useState<PreVenta | null>(null);
    const [lastAdded, setLastAdded] = useState<string | null>(null);

    useEffect(() => {
        if (customerSearch) {
            const t = setTimeout(async () => {
                const { data } = await supabase.from('clientes').select('id, nombre, rut')
                    .ilike('nombre', `%${customerSearch}%`).limit(5);
                setCustomers(data || []);
            }, 300);
            return () => clearTimeout(t);
        }
    }, [customerSearch]);

    const handleScan = async (code: string) => {
        if (!code.trim()) return;
        const { data, error } = await supabase.rpc('search_products_pos_bodega', { p_query: code });
        if (error || !data || data.length === 0) {
            toast.error('Producto no encontrado');
            setScanCode('');
            return;
        }
        const p = data[0];
        if (p.controla_stock && Number(p.stock_actual) <= 0) {
            toast.error(`Sin stock: ${p.nombre_producto}`);
            setScanCode('');
            return;
        }
        const product: Product = {
            id: p.id, stock_actual: Number(p.stock_actual),
            factor_conversion: Number(p.factor_conversion) || 1,
            es_presentacion: p.es_presentacion || false, nombre_presentacion: p.nombre_presentacion,
            unidad_medida: p.unidad_medida || 'UN', controla_stock: p.controla_stock ?? true,
            maestro_producto: { nombre: p.nombre_producto || '', codigo_barra: p.codigo_barra, precio_venta: Number(p.precio_venta || 0) }
        };
        const cartItemId = `${product.id}-${product.factor_conversion}`;
        const factor = product.factor_conversion || 1;
        if (product.controla_stock) {
            const current = cart.filter(i => i.id === product.id).reduce((s, i) => s + (i.quantity * i.factor_conversion), 0);
            if ((current + (scanQty * factor)) > product.stock_actual) {
                toast.error(`Stock insuficiente. Max: ${product.stock_actual / factor}`);
                setScanCode('');
                return;
            }
        }
        setCart(prev => {
            const existing = prev.find(i => i.cartItemId === cartItemId);
            if (existing) return prev.map(i => i.cartItemId === cartItemId ? { ...i, quantity: i.quantity + scanQty } : i);
            return [...prev, { ...product, quantity: scanQty, cartItemId }];
        });
        setLastAdded(cartItemId);
        setTimeout(() => setLastAdded(null), 1200);
        setScanCode('');
        setScanQty(1);
        scanInputRef.current?.focus();
    };

    const removeFromCart = (id: string) => setCart(prev => prev.filter(i => i.cartItemId !== id));
    const changeQty = (id: string, qty: number) => setCart(prev => prev.map(i => i.cartItemId === id ? { ...i, quantity: Math.max(1, qty) } : i));
    const total = cart.reduce((s, i) => s + (i.maestro_producto.precio_venta * i.quantity), 0);

    const handleGuardar = async () => {
        if (!cart.length) { toast.error('Carrito vacio'); return; }
        setLoading(true);
        try {
            const items = cart.map(i => ({ producto_id: i.id, cantidad: i.quantity, precio: i.maestro_producto.precio_venta, nombre: i.maestro_producto.nombre, factor: i.factor_conversion, unidad_medida: i.unidad_medida }));
            const { error } = await supabase.rpc('crear_preventa', { p_vendedor_id: user?.id, p_cliente_id: selectedCustomer?.id || null, p_items: items, p_tipo_venta: 'BOLETA', p_notas: notas || null });
            if (error) throw error;
            toast.success('Pre-venta guardada');
            navigate('/preventas');
        } catch (e: unknown) { toast.error('Error: ' + (e instanceof Error ? e.message : '')); }
        finally { setLoading(false); }
    };

    const handleEnviar = async () => {
        if (!cart.length) { toast.error('Carrito vacio'); return; }
        if (!confirm('Enviar al cajero?')) return;
        setLoading(true);
        try {
            const items = cart.map(i => ({ producto_id: i.id, cantidad: i.quantity, precio: i.maestro_producto.precio_venta, nombre: i.maestro_producto.nombre, factor: i.factor_conversion, unidad_medida: i.unidad_medida }));
            const { data: pvId, error: e1 } = await supabase.rpc('crear_preventa', { p_vendedor_id: user?.id, p_cliente_id: selectedCustomer?.id || null, p_items: items, p_tipo_venta: 'BOLETA', p_notas: notas || null });
            if (e1) throw e1;
            const { error: e2 } = await supabase.rpc('enviar_preventa', { p_preventa_id: pvId, p_vendedor_id: user?.id });
            if (e2) throw e2;
            const { data: list } = await supabase.rpc('listar_preventas', { p_usuario_id: user?.id, p_estado: null, p_solo_propias: true });
            const full = list?.find((pv: PreVenta) => pv.id === pvId);
            if (full) { setPreVentaCreada(full); setShowVoucher(true); toast.success('Voucher listo'); }
            else { toast.success('Enviada al cajero'); navigate('/preventas'); }
        } catch (e: unknown) { toast.error('Error: ' + (e instanceof Error ? e.message : '')); }
        finally { setLoading(false); }
    };

    return (
        <div className="max-w-2xl mx-auto h-[calc(100vh-64px)] flex flex-col overflow-hidden p-4 gap-3">
            {/* Header */}
            <div className="flex items-center gap-3 flex-shrink-0">
                <button onClick={() => navigate('/preventas')} className="p-2 hover:bg-gray-100 rounded-lg">
                    <ArrowLeft size={20} />
                </button>
                <h1 className="text-lg font-bold text-gray-800">Nueva Pre-Venta</h1>
            </div>

            {/* Scanner */}
            <div className="bg-white rounded-2xl border p-4 flex-shrink-0">
                <div className="flex items-center gap-3">
                    <div className="relative flex-1">
                        <ScanLine className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
                        <input
                            ref={scanInputRef} autoFocus
                            value={scanCode}
                            onChange={e => setScanCode(e.target.value)}
                            onKeyDown={e => {
                                if (e.key === 'Enter' && scanCode.trim()) { e.preventDefault(); handleScan(scanCode.trim()); }
                            }}
                            className="w-full pl-11 pr-4 py-3 text-lg rounded-xl border-2 border-gray-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10 outline-none font-mono"
                            placeholder="Escanear codigo o buscar producto..."
                        />
                    </div>
                    <div className="flex items-center gap-2 flex-shrink-0">
                        <input type="number" min={1} value={scanQty}
                            onChange={e => setScanQty(Math.max(1, parseInt(e.target.value) || 1))}
                            className="w-16 px-2 py-3 text-center font-bold rounded-xl border-2 border-gray-200 text-sm" />
                        <Button onClick={() => handleScan(scanCode.trim())} className="py-3 px-5">
                            <Plus size={18} className="mr-1" /> Agregar
                        </Button>
                    </div>
                </div>
            </div>

            {/* Cart */}
            <div className="flex-1 bg-white rounded-2xl border overflow-hidden flex flex-col min-h-0">
                {cart.length === 0 ? (
                    <div className="flex-1 flex flex-col items-center justify-center text-gray-300">
                        <ShoppingCart size={48} className="mb-3 opacity-15" />
                        <p className="text-sm text-gray-400">Escanea un producto para comenzar</p>
                    </div>
                ) : (
                    <div className="flex-1 overflow-y-auto">
                        <table className="w-full text-sm">
                            <thead className="text-xs text-gray-400 uppercase bg-gray-50 sticky top-0">
                                <tr>
                                    <th className="text-left py-2.5 pl-4 font-medium">Producto</th>
                                    <th className="text-center py-2.5 font-medium w-24">Cant</th>
                                    <th className="text-right py-2.5 font-medium w-24">Subtotal</th>
                                    <th className="w-10 pr-2"></th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-50">
                                {cart.map(item => (
                                    <tr key={item.cartItemId} className={`transition-colors ${lastAdded === item.cartItemId ? 'bg-blue-50' : 'hover:bg-gray-50'}`}>
                                        <td className="py-2.5 pl-4">
                                            <p className="font-semibold text-gray-800">{item.maestro_producto?.nombre}</p>
                                            <p className="text-xs text-gray-400">
                                                ${item.maestro_producto.precio_venta.toLocaleString()} x {item.unidad_medida}
                                                {item.es_presentacion && <span className="text-purple-500 ml-1">({item.nombre_presentacion})</span>}
                                            </p>
                                        </td>
                                        <td className="py-2.5">
                                            <div className="flex items-center justify-center gap-1">
                                                <button onClick={() => changeQty(item.cartItemId, item.quantity - 1)}
                                                    className="w-6 h-6 flex items-center justify-center text-gray-400 hover:bg-gray-200 rounded">
                                                    <Minus size={12} />
                                                </button>
                                                <span className="w-8 text-center font-bold">{item.quantity}</span>
                                                <button onClick={() => changeQty(item.cartItemId, item.quantity + 1)}
                                                    className="w-6 h-6 flex items-center justify-center text-gray-400 hover:bg-blue-50 hover:text-blue-600 rounded">
                                                    <Plus size={12} />
                                                </button>
                                            </div>
                                        </td>
                                        <td className="text-right py-2.5 font-bold text-gray-900">
                                            ${(item.maestro_producto.precio_venta * item.quantity).toLocaleString()}
                                        </td>
                                        <td className="py-2.5 pr-2">
                                            <button onClick={() => removeFromCart(item.cartItemId)}
                                                className="text-gray-300 hover:text-red-500 p-1">
                                                <X size={14} />
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
                {cart.length > 0 && (
                    <div className="border-t px-4 py-3 flex items-center justify-between bg-gray-50 flex-shrink-0">
                        <span className="text-xs text-gray-500">{cart.length} items</span>
                        <div className="text-right">
                            <span className="text-2xl font-black text-gray-900">${total.toLocaleString()}</span>
                        </div>
                    </div>
                )}
            </div>

            {/* Cliente + Notas */}
            <div className="bg-white rounded-2xl border p-4 flex-shrink-0 space-y-3">
                <div className="flex gap-3">
                    <div className="flex-1">
                        <label className="text-xs font-semibold text-gray-400 uppercase mb-1 block">Cliente</label>
                        {!selectedCustomer ? (
                            <div className="relative">
                                <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400" size={14} />
                                <input type="text" placeholder="Buscar cliente..."
                                    className="w-full pl-8 pr-3 py-2 text-sm rounded-lg border border-gray-200 focus:ring-1 focus:ring-blue-500 outline-none"
                                    value={customerSearch} onChange={e => setCustomerSearch(e.target.value)} />
                                {customers.length > 0 && (
                                    <div className="absolute top-full left-0 right-0 bg-white border rounded-lg mt-1 shadow-lg max-h-32 overflow-y-auto z-10">
                                        {customers.map(c => (
                                            <button key={c.id} onClick={() => { setSelectedCustomer(c); setCustomerSearch(''); }}
                                                className="w-full p-2 text-left hover:bg-gray-50 text-sm">
                                                <span className="font-medium">{c.nombre}</span>
                                                <span className="text-xs text-gray-400 ml-2">{c.rut}</span>
                                            </button>
                                        ))}
                                    </div>
                                )}
                            </div>
                        ) : (
                            <div className="flex items-center justify-between bg-blue-50 p-2 rounded-lg text-sm">
                                <span className="font-medium text-blue-800">{selectedCustomer.nombre} <span className="text-blue-500 text-xs ml-1">{selectedCustomer.rut}</span></span>
                                <button onClick={() => setSelectedCustomer(null)} className="text-blue-400 hover:text-red-500"><X size={14} /></button>
                            </div>
                        )}
                    </div>
                    <div className="flex-1">
                        <label className="text-xs font-semibold text-gray-400 uppercase mb-1 block">Notas</label>
                        <input type="text" placeholder="Opcional..."
                            className="w-full px-3 py-2 text-sm rounded-lg border border-gray-200 focus:ring-1 focus:ring-blue-500 outline-none"
                            value={notas} onChange={e => setNotas(e.target.value)} />
                    </div>
                </div>
            </div>

            {/* Botones */}
            <div className="flex gap-3 flex-shrink-0">
                <Button onClick={handleGuardar} variant="secondary" isLoading={loading}
                    disabled={cart.length === 0} className="flex-1 py-3">
                    <Save size={18} className="mr-2" /> Guardar Borrador
                </Button>
                <Button onClick={handleEnviar} isLoading={loading}
                    disabled={cart.length === 0} className="flex-1 py-3 bg-emerald-600 hover:bg-emerald-700">
                    <Send size={18} className="mr-2" /> Enviar al Cajero
                </Button>
            </div>

            {preVentaCreada && (
                <PreVentaVoucher preVenta={preVentaCreada} isOpen={showVoucher}
                    onClose={() => { setShowVoucher(false); navigate('/preventas'); }} />
            )}
        </div>
    );
}
