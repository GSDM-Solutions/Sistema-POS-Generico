
import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';
import { Card } from '../components/ui/Card';
import { Input } from '../components/ui/Input';
import { Button } from '../components/ui/Button';
import { Select } from '../components/ui/Select';
import { Modal } from '../components/ui/Modal';
import { MasterProduct, Provider } from '../types';
import { PRODUCT_CATEGORIES } from '../lib/categories';
import { Plus, Trash2, Search, Truck, FileText, Barcode, Save, RefreshCw, PackagePlus, Warehouse, Package, Box } from 'lucide-react';

interface Bodega {
  id: string;
  nombre: string;
  tipo: string;
}

// Definimos los modos de entrada
type EntryMode = 'bulk' | 'existing';

interface ReceptionItem {
  id: string; // maestro_id
  nombre: string;
  codigo: string;
  cantidad: number;
  precio_costo: number;
  precio_venta: number; // Referencia del precio de venta del maestro
  lote: string;
  vencimiento: string;
}

export default function Entries() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(false);
  const [entryMode, setEntryMode] = useState<EntryMode>('bulk');

  const [products, setProducts] = useState<any[]>([]);
  const [selectedProductId, setSelectedProductId] = useState('');
  const [quantity, setQuantity] = useState(0);
  const [motivoExistente, setMotivoExistente] = useState('');

  const [providers, setProviders] = useState<Provider[]>([]);
  const [showProviderModal, setShowProviderModal] = useState(false);
  const [showNewProductModal, setShowNewProductModal] = useState(false);

  // BULK RECEPTION STATE
  const [docNumber, setDocNumber] = useState('');
  const [docType, setDocType] = useState('FACTURA');
  const [selectedProvider, setSelectedProvider] = useState('');
  const [items, setItems] = useState<ReceptionItem[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<MasterProduct[]>([]);
  const [bodegas, setBodegas] = useState<Bodega[]>([]);
  const [selectedBodega, setSelectedBodega] = useState('');

  useEffect(() => {
    fetchProviders();
    if (entryMode === 'existing') fetchProducts();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [entryMode]);

  useEffect(() => {
    if (user?.empresa_id) {
      fetchBodegas();
    }
  }, [user?.empresa_id]);

  const fetchBodegas = async () => {
    if (!user?.empresa_id) return;
    const { data } = await supabase.from('bodegas').select('*').eq('empresa_id', user.empresa_id).order('tipo');
    if (data) {
      setBodegas(data);
      if (data.length > 0 && !selectedBodega) {
        setSelectedBodega(data[0].id);
      }
    }
  };

  // Bulk Search Logic
  useEffect(() => {
    const delayDebounceFn = setTimeout(async () => {
      if (entryMode === 'bulk' && searchTerm.length > 2) {
        const { data } = await supabase
          .from('maestro_productos')
          .select('id, nombre, codigo_barra, categoria, stock_critico, precio_venta, creado_en, actualizado_en')
          .eq('activo', true)
          .or(`nombre.ilike.%${searchTerm}%,codigo_barra.ilike.%${searchTerm}%`)
          .limit(10);
        setSearchResults((data as MasterProduct[]) || []);
      } else {
        setSearchResults([]);
      }
    }, 300);
    return () => clearTimeout(delayDebounceFn);
  }, [searchTerm, entryMode]);

  const fetchProducts = async () => {
    try {
      const { data, error } = await supabase
        .from('productos')
        .select('id, numero_lote, maestro_productos(nombre)')
        .order('numero_lote', { ascending: true });
      if (error) throw error;
      setProducts(data || []);
    } catch { toast.error('Error cargando stock existente'); }
  };

  const fetchProviders = async () => {
    const { data } = await supabase.from('proveedores').select('*').order('nombre');
    setProviders(data || []);
  };

  // --- Handlers for Bulk Items ---
  const addItemToBulk = (product: MasterProduct) => {
    if (items.find(i => i.id === product.id)) {
      toast.error('Producto ya en lista');
      return;
    }
    const precioVenta = product.precio_venta || 0;
    const newItem: ReceptionItem = {
      id: product.id,
      nombre: product.nombre,
      codigo: product.codigo_barra || '',
      cantidad: 1,
      precio_costo: precioVenta, // Precargar con el precio de venta como referencia
      precio_venta: precioVenta,
      lote: '',
      vencimiento: ''
    };
    setItems([...items, newItem]);
    setSearchResults([]);
    setSearchTerm('');

    if (precioVenta > 0) {
      toast.success(`Costo precargado: $${precioVenta.toLocaleString()} (precio venta actual)`);
    }
  };
  const updateBulkItem = (index: number, field: keyof ReceptionItem, value: any) => {
    const newItems = [...items];
    newItems[index] = { ...newItems[index], [field]: value };
    setItems(newItems);
  };
  const removeBulkItem = (index: number) => {
    setItems(items.filter((_, i) => i !== index));
  };
  const handleProcessBulk = async () => {
    if (!docNumber) return toast.error('Falta N° Documento. Ingrese el número de factura/guía.');
    if (!selectedProvider) return toast.error('Seleccione Proveedor');
    if (!selectedBodega) return toast.error('Seleccione Bodega de destino');
    if (items.length === 0) return toast.error('La lista está vacía');

    for (const item of items) {
      if (item.cantidad <= 0) return toast.error(`Cantidad inválida en ${item.nombre}`);
      if (!item.vencimiento) return toast.error(`Falta fecha de vencimiento en: ${item.nombre}`);
    }

    if (!confirm('¿Procesar recepción? Se creará stock y lotes.')) return;

    setLoading(true);
    try {
      // Use the RPC created in migration 20251214000003
      const { error } = await supabase.rpc('procesar_recepcion_mercaderia', {
        p_numero_documento: docNumber,
        p_tipo_documento: docType,
        p_proveedor_id: selectedProvider,
        p_usuario_id: user?.id,
        p_bodega_id: selectedBodega,
        p_detalles: items.map(item => ({
          ...item,
          maestro_producto_id: item.id,
          lote: item.lote || 'S/L',
          vencimiento: item.vencimiento || null
        }))
      });

      if (error) throw error;
      toast.success('Recepción procesada correctamente');
      setItems([]);
      setDocNumber('');
      setSearchTerm('');
    } catch (error: any) {
      toast.error(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleManualSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const { data: product } = await supabase.from('productos').select('stock_actual').eq('id', selectedProductId).single();
      if (!product) throw new Error('Producto no existe');

      await supabase.from('productos').update({
        stock_actual: product.stock_actual + Number(quantity),
        actualizado_en: new Date().toISOString()
      }).eq('id', selectedProductId);

      await supabase.from('movimientos').insert([{
        producto_id: selectedProductId,
        usuario_id: user?.id,
        empresa_id: user?.empresa_id,
        tipo_movimiento: 'entrada',
        cantidad: Number(quantity),
        motivo: motivoExistente,
        condicion: 'Bueno'
      }]);
      toast.success('Stock actualizado');
      setQuantity(0); setMotivoExistente(''); setSelectedProductId('');
    } catch (err: any) {
      toast.error(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-7xl mx-auto p-4 space-y-6">
      <div className="flex flex-col md:flex-row justify-between items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
            <Truck size={32} className="text-blue-600" />
            Recepción de Compras
          </h1>
          <p className="text-gray-500">Ingresa facturas de proveedores y carga stock masivamente</p>
        </div>
      </div>

      {/* Mode Tabs */}
      <div className="flex p-1 bg-gray-100 rounded-xl gap-1 max-w-md mx-auto md:mx-0">
        <button onClick={() => setEntryMode('bulk')} className={`flex-1 py-3 rounded-lg text-sm font-bold transition-all ${entryMode === 'bulk' ? 'bg-white shadow text-blue-600' : 'text-gray-500 hover:text-gray-700'}`}>
          <div className="flex items-center justify-center gap-2"><Truck size={16} /> Recepción Factura</div>
        </button>
        <button onClick={() => setEntryMode('existing')} className={`flex-1 py-3 rounded-lg text-sm font-bold transition-all ${entryMode === 'existing' ? 'bg-white shadow text-blue-600' : 'text-gray-500 hover:text-gray-700'}`}>
          <div className="flex items-center justify-center gap-2"><RefreshCw size={16} /> Devolución / Ajuste</div>
        </button>
      </div>

      {/* --- BULK MODE --- */}
      {entryMode === 'bulk' && (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-300">
          {/* Factura Header */}
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm grid grid-cols-1 md:grid-cols-4 gap-6 relative overflow-visible z-30">
            <div>
              <label className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Tipo Doc.</label>
              <select className="w-full p-3 bg-gray-50 border-gray-200 rounded-xl font-bold text-gray-700 outline-none hover:bg-gray-100 transition-colors" value={docType} onChange={e => setDocType(e.target.value)}>
                <option value="FACTURA">FACTURA</option>
                <option value="GUIA">GUÍA DESPACHO</option>
                <option value="BOLETA">BOLETA</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">N° Documento</label>
              <div className="relative group">
                <FileText className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-blue-500" size={18} />
                <input className="w-full pl-10 p-3 bg-gray-50 border-gray-200 rounded-xl font-bold text-gray-700 outline-none focus:ring-2 focus:ring-blue-100 focus:bg-white transition-all" value={docNumber} onChange={e => setDocNumber(e.target.value)} placeholder="Ej: 123456" />
              </div>
            </div>
            <div className="md:col-span-1">
              <label className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Proveedor</label>
              <div className="flex gap-2">
                <select className="w-full p-3 bg-gray-50 border-gray-200 rounded-xl font-bold text-gray-700 outline-none hover:bg-gray-100 transition-colors" value={selectedProvider} onChange={e => setSelectedProvider(e.target.value)}>
                  <option value="">-- Seleccionar --</option>
                  {providers.map(p => <option key={p.id} value={p.id}>{p.nombre}</option>)}
                </select>
                <button onClick={() => setShowProviderModal(true)} className="bg-blue-600 text-white p-3 rounded-xl hover:bg-blue-700 transition-colors shadow-lg shadow-blue-200" title="Nuevo Proveedor">
                  <Plus size={20} />
                </button>
              </div>
            </div>
            <div>
              <label className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">
                <Warehouse size={14} className="inline mr-1" />
                Bodega Destino
              </label>
              <select
                className="w-full p-3 bg-gray-50 border-gray-200 rounded-xl font-bold text-gray-700 outline-none hover:bg-gray-100 transition-colors"
                value={selectedBodega}
                onChange={e => setSelectedBodega(e.target.value)}
              >
                {bodegas.map(b => (
                  <option key={b.id} value={b.id}>
                    {b.nombre} ({b.tipo === 'general' ? 'General' : 'Venta'})
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Product Search */}
          <div className="relative z-20 bg-blue-50/50 p-6 rounded-2xl border border-blue-100">
            <label className="block text-xs font-bold text-blue-400 uppercase tracking-wider mb-2">Buscar o Crear Producto</label>
            <div className="relative flex gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  placeholder="Escribe nombre o escanea código..."
                  className="w-full pl-11 p-4 rounded-xl border border-gray-200 shadow-sm outline-none focus:ring-4 focus:ring-blue-100 focus:border-blue-500 transition-all font-medium text-lg"
                  value={searchTerm}
                  onChange={e => setSearchTerm(e.target.value)}
                />
              </div>
              <button
                onClick={() => setShowNewProductModal(true)}
                className="bg-white border text-blue-600 border-blue-200 px-6 rounded-xl font-bold hover:bg-blue-50 hover:border-blue-300 transition-all flex items-center gap-2 whitespace-nowrap shadow-sm"
              >
                <PackagePlus size={20} /> Crear Nuevo
              </button>
            </div>
            {searchResults.length > 0 && (
              <div className="absolute top-[85px] left-6 right-6 z-50 bg-white rounded-xl shadow-2xl border border-gray-100 overflow-hidden max-h-60 overflow-y-auto animate-in zoom-in-95 duration-100">
                {searchResults.map(product => (
                  <button key={product.id} onClick={() => addItemToBulk(product)} className="w-full text-left p-4 hover:bg-blue-50 border-b border-gray-50 flex justify-between items-center group transition-colors">
                    <div>
                      <div className="font-bold text-gray-800 group-hover:text-blue-700">{product.nombre}</div>
                      <div className="text-xs text-gray-400 flex items-center gap-1"><Barcode size={12} /> {product.codigo_barra || 'S/C'}</div>
                    </div>
                    <div className="bg-gray-100 text-gray-400 group-hover:bg-blue-200 group-hover:text-blue-600 p-2 rounded-lg transition-colors">
                      <Plus size={20} />
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Table */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden overflow-x-auto min-h-[300px]">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs md:text-sm">
                <thead className="bg-gray-50 text-gray-500 font-bold uppercase tracking-wider">
                  <tr>
                    <th className="p-4 border-b border-gray-100">Producto</th>
                    <th className="p-4 w-24 border-b border-gray-100 text-center">Cant.</th>
                    <th className="p-4 w-32 border-b border-gray-100 text-center">Costo Unit.</th>
                    <th className="p-4 w-40 border-b border-gray-100 text-center">Vencimiento</th>
                    <th className="p-4 w-32 text-right border-b border-gray-100">Subtotal</th>
                    <th className="p-4 w-10 border-b border-gray-100"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {items.map((item, idx) => {
                    const costoMayorQuePrecio = item.precio_costo > item.precio_venta && item.precio_venta > 0;
                    return (
                      <tr key={item.id} className={`hover:bg-blue-50/30 transition-colors group ${costoMayorQuePrecio ? 'bg-red-50' : ''}`}>
                        <td className="p-4 font-bold text-gray-800">
                          {item.nombre}
                          <div className="text-[10px] text-gray-400 font-normal">{item.codigo}</div>
                          {item.precio_venta > 0 && (
                            <div className="text-[10px] text-blue-500 font-normal">
                              Precio venta actual: ${item.precio_venta.toLocaleString()}
                            </div>
                          )}
                        </td>
                        <td className="p-2">
                          <input type="number" min="0" step="any" className="w-full p-2 bg-gray-50 border border-gray-100 focus:bg-white focus:border-blue-500 outline-none rounded-lg text-center font-bold transition-all" value={item.cantidad} onChange={e => updateBulkItem(idx, 'cantidad', parseFloat(e.target.value))} />
                        </td>
                        <td className="p-2">
                          <div className="relative">
                            <span className="absolute left-2 top-1/2 -translate-y-1/2 text-gray-400">$</span>
                            <input
                              type="number"
                              className={`w-full pl-6 p-2 border outline-none rounded-lg text-right font-medium transition-all ${costoMayorQuePrecio
                                  ? 'bg-red-100 border-red-300 focus:border-red-500 text-red-700'
                                  : 'bg-gray-50 border-gray-100 focus:bg-white focus:border-blue-500'
                                }`}
                              value={item.precio_costo}
                              onChange={e => updateBulkItem(idx, 'precio_costo', parseFloat(e.target.value))}
                            />
                            {costoMayorQuePrecio && (
                              <div className="text-[9px] text-red-600 font-bold mt-1 text-center">⚠️ Mayor al precio venta</div>
                            )}
                          </div>
                        </td>
                        <td className="p-2 hidden">
                          <input type="text" placeholder="LOTE-001" className="w-full p-2 bg-gray-50 border border-gray-100 focus:bg-white focus:border-blue-500 outline-none rounded-lg text-center uppercase text-xs font-medium tracking-wide transition-all" value={item.lote} onChange={e => updateBulkItem(idx, 'lote', e.target.value)} />
                        </td>
                        <td className="p-2">
                          <input type="date" className="w-full p-2 bg-gray-50 border border-gray-100 focus:bg-white focus:border-blue-500 outline-none rounded-lg text-center text-xs transition-all" value={item.vencimiento} onChange={e => updateBulkItem(idx, 'vencimiento', e.target.value)} />
                        </td>
                        <td className="p-4 text-right font-bold text-gray-900">${(item.cantidad * item.precio_costo).toLocaleString()}</td>
                        <td className="p-2 text-center"><button onClick={() => removeBulkItem(idx)} className="text-gray-300 hover:text-red-500 hover:bg-red-50 p-2 rounded-lg transition-all"><Trash2 size={18} /></button></td>
                      </tr>
                    )
                  })}
                  {items.length === 0 && <tr><td colSpan={7} className="p-12 text-center text-gray-400 italic">No hay productos en la lista de recepción</td></tr>}
                </tbody>
                <tfoot className="bg-gray-50 border-t border-gray-200">
                  <tr>
                    <td colSpan={5} className="p-5 text-right font-bold text-gray-500 uppercase text-xs tracking-wider">Total Neto Documento</td>
                    <td className="p-5 text-right font-black text-2xl text-gray-900">${items.reduce((sum, i) => sum + (i.cantidad * i.precio_costo), 0).toLocaleString()}</td>
                    <td></td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div className="flex justify-end pt-4">
            <Button onClick={handleProcessBulk} isLoading={loading} className="bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700 text-white font-bold py-4 px-8 rounded-xl shadow-xl hover:shadow-green-200 hover:-translate-y-1 transition-all text-lg">
              <Save className="mr-2" size={20} /> Confirmar Recepción
            </Button>
          </div>
        </div>
      )}

      {/* --- EXISTING MODE (Legacy Preserved - Simplified UI) --- */}
      {entryMode === 'existing' && (
        <Card className="p-8 max-w-2xl mx-auto">
          <div className="text-center mb-6">
            <div className="bg-orange-100 text-orange-600 p-4 rounded-full w-fit mx-auto mb-4"><RefreshCw size={32} /></div>
            <h2 className="text-2xl font-bold text-gray-800">Ajuste de Stock / Devolución</h2>
            <p className="text-gray-500">Suma unidades a un lote que ya existe en bodega.</p>
          </div>
          <form onSubmit={handleManualSubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-bold text-gray-700 mb-2">Buscar Lote Existente</label>
              <select className="w-full p-4 border border-gray-200 bg-gray-50 rounded-xl outline-none focus:ring-2 focus:ring-blue-500" value={selectedProductId} onChange={e => setSelectedProductId(e.target.value)} required>
                <option value="">Seleccione Producto...</option>
                {products.map(p => <option key={p.id} value={p.id}>{p.maestro_productos?.nombre}</option>)}
              </select>
            </div>
            <div className="grid grid-cols-2 gap-6">
              <Input label="Cantidad a Sumar" type="number" min={1} value={quantity} onChange={e => setQuantity(parseFloat(e.target.value))} required />
              <Input label="Motivo del Ajuste" placeholder="Ej: Devolución cliente" value={motivoExistente} onChange={e => setMotivoExistente(e.target.value)} required />
            </div>
            <Button type="submit" isLoading={loading} className="w-full py-4 text-lg font-bold shadow-lg">Guardar Ajuste</Button>
          </form>
        </Card>
      )}

      <ProviderModal isOpen={showProviderModal} onClose={() => setShowProviderModal(false)} onProviderCreated={fetchProviders} />
      <QuickProductModal isOpen={showNewProductModal} onClose={() => setShowNewProductModal(false)} onProductCreated={() => { }} />
    </div>
  );
}

// --- MODALS ---

function ProviderModal({ isOpen, onClose, onProviderCreated }: { isOpen: boolean, onClose: () => void, onProviderCreated: () => void }) {
  const [loading, setLoading] = useState(false);
  const { user } = useAuth();
  const [formData, setFormData] = useState({ nombre: '', direccion: '', clasificacion: 'insumos_generales' });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const { error } = await supabase.from('proveedores').insert([{
        ...formData,
        empresa_id: user?.empresa_id
      }]);
      if (error) throw error;
      toast.success('Proveedor creado.');
      onProviderCreated();
      onClose();
    } catch (error: any) {
      toast.error(error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Crear Nuevo Proveedor">
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input label="Nombre Auditoria" name="nombre" value={formData.nombre} onChange={(e) => setFormData(p => ({ ...p, nombre: e.target.value }))} required />
        <Input label="Dirección / Contacto" name="direccion" value={formData.direccion} onChange={(e) => setFormData(p => ({ ...p, direccion: e.target.value }))} />
        <div className="flex justify-end space-x-3 pt-4">
          <Button type="button" variant="secondary" onClick={onClose}>Cancelar</Button>
          <Button type="submit" isLoading={loading}>Guardar</Button>
        </div>
      </form>
    </Modal>
  );
}

function QuickProductModal({ isOpen, onClose, onProductCreated }: { isOpen: boolean, onClose: () => void, onProductCreated: () => void }) {
  const [loading, setLoading] = useState(false);
  const { user } = useAuth();
  const [formData, setFormData] = useState<{
    nombre: string;
    codigo_barra: string;
    categoria: string;
    precio_venta: number | '';
    unidad_medida: string;
    stock_critico: number | '';
  }>({
    nombre: '',
    codigo_barra: '',
    categoria: 'almacen',
    precio_venta: '',
    unidad_medida: 'UN',
    stock_critico: ''
  });

  const [categories, setCategories] = useState<{ value: string, label: string }[]>([]);

  useEffect(() => {
    const loadCats = async () => {
      const { data, error } = await supabase.from('categorias').select('nombre').eq('activo', true).order('nombre');
      if (error) {
        console.warn('Error fetching categories, using defaults:', error.message);
        setCategories([...PRODUCT_CATEGORIES]);
        return;
      }
      if (data && data.length > 0) {
        setCategories(data.map(c => ({ value: c.nombre.toLowerCase().replace(/ /g, '_'), label: c.nombre })));
      } else {
        setCategories([...PRODUCT_CATEGORIES]);
      }
    };
    loadCats();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (formData.precio_venta === '' || Number(formData.precio_venta) <= 0) return toast.error('El precio debe ser mayor a cero.');
    if (formData.stock_critico === '' || Number(formData.stock_critico) < 0) return toast.error('El stock crítico es requerido.');

    setLoading(true);
    try {
      const { error } = await supabase.from('maestro_productos').insert([{
        ...formData,
        stock_critico: Number(formData.stock_critico),
        precio_venta: Number(formData.precio_venta),
        activo: true,
        empresa_id: user?.empresa_id
      }]);
      if (error) throw error;
      toast.success('Producto creado exitosamente.');
      onProductCreated();
      onClose();
      setFormData({ nombre: '', codigo_barra: '', categoria: categories[0]?.value || 'almacen', precio_venta: '', unidad_medida: 'UN', stock_critico: '' });
    } catch (error: any) {
      toast.error(error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Crear Producto Maestro Rápido">
      <form onSubmit={handleSubmit} className="space-y-6">
        
        {/* SECCIÓN: Información Principal */}
        <div className="bg-gray-50/50 p-4 rounded-xl border border-gray-100 space-y-4">
          <h4 className="text-sm font-semibold text-gray-800 flex items-center gap-2 mb-2">
            <Package className="text-blue-500" size={16} />
            Información Principal
          </h4>
          
          <Input label="Nombre del Producto" value={formData.nombre} onChange={(e) => setFormData(p => ({ ...p, nombre: e.target.value }))} required autoFocus placeholder="Ej: Gaseosa 3 Lts" />
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input label="Código Barra (Opcional)" value={formData.codigo_barra} onChange={(e) => setFormData(p => ({ ...p, codigo_barra: e.target.value }))} placeholder="Escanee o deje en blanco" />
            <Select label="Categoría" value={formData.categoria} onChange={(e) => setFormData(p => ({ ...p, categoria: e.target.value }))} options={categories.length ? categories : [{ value: 'almacen', label: 'Cargando...' }]} required />
          </div>
        </div>

        {/* SECCIÓN: Inventario y Precios */}
        <div className="bg-blue-50/30 p-4 rounded-xl border border-blue-100/50 space-y-4">
          <h4 className="text-sm font-semibold text-gray-800 flex items-center gap-2 mb-2">
            <Box className="text-blue-500" size={16} />
            Precios y Configuración de Stock
          </h4>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Input label="Precio Venta Unitario ($)" type="number" value={formData.precio_venta} onChange={(e) => setFormData(p => ({ ...p, precio_venta: e.target.value === '' ? '' : Number(e.target.value) }))} required />
            <Input label="Stock Crítico" type="number" value={formData.stock_critico} onChange={(e) => setFormData(p => ({ ...p, stock_critico: e.target.value === '' ? '' : Number(e.target.value) }))} required />
          </div>
        </div>

        <p className="text-xs text-gray-600 bg-blue-50 p-3 rounded-lg border border-blue-100/50 flex items-center gap-2">
          <Warehouse size={14} className="text-blue-500 flex-shrink-0" />
          Una vez creado, podrás buscarlo inmediatamente para cargarle stock en esta recepción.
        </p>

        <div className="flex justify-end space-x-3 pt-4">
          <Button type="button" variant="secondary" onClick={onClose}>Cancelar</Button>
          <Button type="submit" isLoading={loading}>Crear Producto</Button>
        </div>
      </form>
    </Modal>
  );
}