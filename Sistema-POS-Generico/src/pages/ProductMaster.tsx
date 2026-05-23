import React, { useCallback, useEffect, useState } from 'react';
import { Plus, Edit, Trash2, Package, Box, Power } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Card } from '../components/ui/Card';
import { Modal } from '../components/ui/Modal';
import { Badge } from '../components/ui/Badge';
import toast from 'react-hot-toast';
import { MasterProduct, Provider, ProductPresentation } from '../types';
import { PRODUCT_CATEGORIES } from '../lib/categories';

type Tab = 'products' | 'providers' | 'categories';

interface Category {
  id: string;
  nombre: string;
  descripcion?: string;
  activo?: boolean;
}

export function ProductMaster() {
  const [activeTab, setActiveTab] = useState<Tab>('products');

  return (
    <div>
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Maestros</h1>
          <p className="text-gray-600 mt-2">Gestión central de catálogos del negocio.</p>
        </div>
      </div>

      <div className="mb-6 border-b border-gray-200">
        <nav className="-mb-px flex space-x-6">
          <button
            onClick={() => setActiveTab('products')}
            className={`py-3 px-1 border-b-2 font-medium text-sm ${activeTab === 'products' ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}`}>
            Maestro de Productos
          </button>
          <button
            onClick={() => setActiveTab('providers')}
            className={`py-3 px-1 border-b-2 font-medium text-sm ${activeTab === 'providers' ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}`}>
            Maestro de Proveedores
          </button>
          <button
            onClick={() => setActiveTab('categories')}
            className={`py-3 px-1 border-b-2 font-medium text-sm ${activeTab === 'categories' ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}`}>
            Maestro de Categorías
          </button>
        </nav>
      </div>

      {activeTab === 'products' ? <ProductMasterView /> : activeTab === 'providers' ? <ProviderMasterView /> : <CategoryMasterView />}
    </div>
  );
}

function ProductMasterView() {
  const [masterProducts, setMasterProducts] = useState<MasterProduct[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState<MasterProduct | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [showFilter, setShowFilter] = useState<'activos' | 'inactivos' | 'todos'>('activos');

  const { user } = useAuth();
  const canManage = user?.role === 'admin';
  const [presentations, setPresentations] = useState<ProductPresentation[]>([]);
  const [newPresentation, setNewPresentation] = useState<{
    codigo_barra: string;
    nombre_presentacion: string;
    factor_conversion: number | '';
    precio_venta: number | '';
  }>({
    codigo_barra: '',
    nombre_presentacion: '',
    factor_conversion: '',
    precio_venta: ''
  });

  const [formData, setFormData] = useState<{
    nombre: string;
    categoria: string;
    descripcion: string;
    stock_critico: number | '';
    precio_venta: number | '';
    codigo_barra: string;
    unidad_medida: string;
    controla_stock: boolean;
  }>({
    nombre: '',
    categoria: 'almacen',
    descripcion: '',
    stock_critico: '',
    precio_venta: '',
    codigo_barra: '',
    unidad_medida: 'UN',
    controla_stock: true
  });

  /* categories removed, dynamic loading below */
  const [categories, setCategories] = useState<{ value: string, label: string }[]>([]);

  const fetchCategories = useCallback(async () => {
    const { data, error } = await supabase.from('categorias').select('id, nombre').eq('activo', true).order('nombre');
    if (error) {
      console.warn('Error fetching categories from DB, using defaults:', error.message);
      setCategories([...PRODUCT_CATEGORIES]);
      return;
    }
    if (data && data.length > 0) {
      setCategories(data.map(c => ({ value: c.nombre.toLowerCase().replace(/ /g, '_'), label: c.nombre })));
    } else {
      setCategories([...PRODUCT_CATEGORIES]);
    }
  }, []);

  const fetchMasterProducts = useCallback(async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('maestro_productos')
        .select('*')
        .order('nombre', { ascending: true });

      // Aplicar filtro según estado
      if (showFilter === 'activos') {
        query = query.eq('activo', true);
      } else if (showFilter === 'inactivos') {
        query = query.eq('activo', false);
      }
      // 'todos' no aplica filtro

      const { data, error } = await query;

      if (error) throw error;
      setMasterProducts(data || []);
    } catch {
      toast.error('Error al cargar el maestro de productos.');
    } finally {
      setLoading(false);
    }
  }, [showFilter]);

  useEffect(() => {
    fetchCategories();
    fetchMasterProducts();
  }, [showFilter, fetchCategories, fetchMasterProducts]);

  const fetchPresentations = async (productId: string) => {
    const { data } = await supabase
      .from('producto_presentaciones')
      .select('*')
      .eq('maestro_producto_id', productId)
      .order('factor_conversion', { ascending: true });
    setPresentations(data || []);
  };

  const addPresentation = async () => {
    if (!selectedProduct) return;
    if (!newPresentation.codigo_barra || !newPresentation.nombre_presentacion) return toast.error('Datos incompletos');
    if (newPresentation.factor_conversion === '' || Number(newPresentation.factor_conversion) <= 0) return toast.error('El factor debe ser mayor a cero.');

    try {
      const { error } = await supabase.from('producto_presentaciones').insert([{
        maestro_producto_id: selectedProduct.id,
        codigo_barra: newPresentation.codigo_barra,
        nombre_presentacion: newPresentation.nombre_presentacion,
        factor_conversion: Number(newPresentation.factor_conversion),
        precio_venta: newPresentation.precio_venta === '' ? null : Number(newPresentation.precio_venta),
        empresa_id: user?.empresa_id
      }]);

      if (error) throw error;
      toast.success('Presentación agregada');
      fetchPresentations(selectedProduct.id);
      setNewPresentation({ codigo_barra: '', nombre_presentacion: '', factor_conversion: '', precio_venta: '' });
    } catch (e: unknown) {
      toast.error(e instanceof Error ? e.message : 'Error al crear presentación');
    }
  };

  const deletePresentation = async (id: string) => {
    if (!confirm('¿Eliminar presentación?')) return;
    const { error } = await supabase.from('producto_presentaciones').delete().eq('id', id);
    if (!error) {
      toast.success('Eliminado');
      if (selectedProduct) fetchPresentations(selectedProduct.id);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canManage) return toast.error('No tienes permiso.');

    if (formData.precio_venta === '' || Number(formData.precio_venta) <= 0) {
      return toast.error('El precio de venta debe ser mayor a cero.');
    }
    if (formData.stock_critico === '' || Number(formData.stock_critico) < 0) {
      return toast.error('El stock crítico no puede estar en blanco.');
    }

    setLoading(true);
    try {
      const productData = {
        ...formData,
        stock_critico: Number(formData.stock_critico),
        precio_venta: Number(formData.precio_venta),
      };

      if (isEditing && selectedProduct) {
        const { error } = await supabase
          .from('maestro_productos')
          .update(productData)
          .eq('id', selectedProduct.id);
        if (error) throw error;
        toast.success('Producto maestro actualizado.');
      } else {
        // Agregar empresa_id para multi-empresa
        const { error } = await supabase.from('maestro_productos').insert([{
          ...productData,
          empresa_id: user?.empresa_id
        }]);
        if (error) throw error;
        toast.success('Nuevo producto maestro creado.');
      }
      setShowModal(false);
      fetchMasterProducts();
    } catch (error: unknown) {
      toast.error(error instanceof Error ? error.message : 'Error al guardar el producto.');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleActivo = async (id: string, currentActivo: boolean) => {
    const action = currentActivo ? 'desactivar' : 'reactivar';
    if (!canManage || !confirm(`¿Seguro que quieres ${action} este producto?`)) return;

    try {
      const { error } = await supabase
        .from('maestro_productos')
        .update({ activo: !currentActivo })
        .eq('id', id);
      if (error) throw error;
      toast.success(`Producto ${currentActivo ? 'desactivado' : 'reactivado'} correctamente.`);
      fetchMasterProducts();
    } catch (error: unknown) {
      toast.error('Error: ' + (error instanceof Error ? error.message : 'Error desconocido'));
    }
  };

  const openModal = (product?: MasterProduct) => {
    if (product) {
      setSelectedProduct(product);
      setIsEditing(true);
      setFormData({
        nombre: product.nombre,
        categoria: product.categoria,
        descripcion: product.descripcion || '',
        stock_critico: product.stock_critico,
        precio_venta: product.precio_venta || 0,
        codigo_barra: product.codigo_barra || '',
        unidad_medida: product.unidad_medida || 'UN',
        controla_stock: product.controla_stock
      });
      fetchPresentations(product.id);
    } else {
      setSelectedProduct(null);
      setIsEditing(false);
      setPresentations([]);
      setFormData({
        nombre: '',
        categoria: 'almacen',
        descripcion: '',
        stock_critico: '',
        precio_venta: '',
        codigo_barra: '',
        unidad_medida: 'UN',
        controla_stock: true
      });
    }
    setShowModal(true);
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-4">
        {/* Filtro de estado */}
        <div className="flex gap-2">
          <button
            onClick={() => setShowFilter('activos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'activos' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Activos
          </button>
          <button
            onClick={() => setShowFilter('inactivos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'inactivos' ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Inactivos
          </button>
          <button
            onClick={() => setShowFilter('todos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'todos' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Todos
          </button>
        </div>

        {canManage && (
          <Button onClick={() => openModal()}>
            <Plus className="w-4 h-4 mr-2" />
            Agregar Producto al Catálogo
          </Button>
        )}
      </div>
      <Card>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Cód. Barra</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Producto</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Categoría</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Precio</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Stock Crítico</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Inventario</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Acciones</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {masterProducts.map((product) => (
                <tr key={product.id} className={!product.activo ? 'bg-red-50 opacity-60' : ''}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <Badge variant={product.activo ? 'success' : 'danger'}>
                      {product.activo ? 'Activo' : 'Inactivo'}
                    </Badge>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{product.codigo_barra || '-'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{product.nombre}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 capitalize">{product.categoria.replace('_', ' ')}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${product.precio_venta?.toLocaleString() || 0}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{product.stock_critico}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <Badge variant={product.controla_stock ? 'default' : 'info'}>
                      {product.controla_stock ? 'Sí' : 'No (Libre)'}
                    </Badge>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    {canManage && (
                      <div className="flex space-x-2">
                        <button onClick={() => openModal(product)} className="text-green-600 hover:text-green-900" title="Editar">
                          <Edit className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleToggleActivo(product.id, product.activo !== false)}
                          className={product.activo ? "text-orange-600 hover:text-orange-900" : "text-green-600 hover:text-green-900"}
                          title={product.activo ? 'Desactivar' : 'Reactivar'}
                        >
                          <Power className="w-4 h-4" />
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Modal isOpen={showModal} onClose={() => setShowModal(false)} title={isEditing ? 'Editar Producto Maestro' : 'Agregar Producto Maestro'}>
        <form onSubmit={handleSubmit} className="space-y-6">
          
          {/* SECCIÓN: Información Principal */}
          <div className="bg-gray-50/50 p-4 rounded-xl border border-gray-100 space-y-4">
            <h4 className="text-sm font-semibold text-gray-800 flex items-center gap-2 mb-2">
              <Package className="text-blue-500" size={16} />
              Información Principal
            </h4>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input label="Código de Barra (Unitario)" name="codigo_barra" value={formData.codigo_barra} onChange={(e) => setFormData(p => ({ ...p, codigo_barra: e.target.value }))} placeholder="Escanee o ingrese código" />
              <Input label="Nombre del Producto" name="nombre" value={formData.nombre} onChange={(e) => setFormData(p => ({ ...p, nombre: e.target.value }))} required placeholder="Ej: Gaseosa 3 Lts" />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Select label="Categoría" name="categoria" options={categories} value={formData.categoria} onChange={(e) => setFormData(p => ({ ...p, categoria: e.target.value }))} required />
              <Select
                label="Unidad Base"
                name="unidad_medida"
                value={formData.unidad_medida}
                onChange={(e) => setFormData(p => ({ ...p, unidad_medida: e.target.value }))}
                options={[
                  { value: 'UN', label: 'Unidad (UN)' },
                  { value: 'KG', label: 'Kilogramo (KG)' },
                  { value: 'LT', label: 'Litro (LT)' },
                  { value: 'MT', label: 'Metro (MT)' }
                ]}
              />
            </div>
            
            <Input label="Descripción (Opcional)" name="descripcion" value={formData.descripcion} onChange={(e) => setFormData(p => ({ ...p, descripcion: e.target.value }))} placeholder="Detalles adicionales del producto..." />
          </div>

          {/* SECCIÓN: Inventario y Precios */}
          <div className="bg-blue-50/30 p-4 rounded-xl border border-blue-100/50 space-y-4">
            <h4 className="text-sm font-semibold text-gray-800 flex items-center gap-2 mb-2">
              <Box className="text-blue-500" size={16} />
              Precios y Configuración de Stock
            </h4>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
              <Input label="Precio Venta Unitario ($)" name="precio_venta" type="number" value={formData.precio_venta} onChange={(e) => setFormData(p => ({ ...p, precio_venta: e.target.value === '' ? '' : Number(e.target.value) }))} required />
              <Input label="Stock Crítico" name="stock_critico" type="number" value={formData.stock_critico} onChange={(e) => setFormData(p => ({ ...p, stock_critico: e.target.value === '' ? '' : Number(e.target.value) }))} required />
              
              <div className="flex flex-col pb-1">
                <label className="text-sm font-medium text-gray-700 mb-2">Control de Inventario</label>
                <div className="flex items-center h-10 bg-white border border-gray-200 rounded-lg px-3 shadow-sm">
                  <input
                    type="checkbox"
                    checked={formData.controla_stock}
                    onChange={(e) => setFormData(p => ({ ...p, controla_stock: e.target.checked }))}
                    className="h-5 w-5 text-blue-600 rounded border-gray-300 focus:ring-blue-500 cursor-pointer"
                  />
                  <span className="ml-3 text-sm font-medium text-gray-700">
                    {formData.controla_stock ? 'Descuento de stock activo' : 'Stock libre (sin control)'}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {isEditing && (
            <div className="border-t pt-4 mt-4">
              <h4 className="font-bold text-gray-800 flex items-center gap-2 mb-3">
                <Package className="text-blue-600" size={18} />
                Presentaciones / Packs de Venta
              </h4>
              <div className="bg-gray-50 p-3 rounded-xl space-y-3">
                {presentations.map(p => (
                  <div key={p.id} className="flex items-center justify-between bg-white p-2 border rounded-lg shadow-sm">
                    <div className="flex items-center gap-3">
                      <Box className="text-gray-400" size={16} />
                      <div>
                        <div className="font-bold text-sm text-gray-800">{p.nombre_presentacion}</div>
                        <div className="text-xs text-gray-500 flex gap-2">
                          <span>Código: {p.codigo_barra}</span>
                          <span className="bg-blue-50 text-blue-700 px-1 rounded">x{p.factor_conversion} {formData.unidad_medida}</span>
                          {p.precio_venta && <span className="bg-green-50 text-green-700 px-1 rounded">${p.precio_venta.toLocaleString()}</span>}
                        </div>
                      </div>
                    </div>
                    <Button size="sm" variant="danger" onClick={() => deletePresentation(p.id)} type="button">
                      <Trash2 size={14} />
                    </Button>
                  </div>
                ))}

                <div className="grid grid-cols-12 gap-2 items-end pt-2 border-t border-gray-200">
                  <div className="col-span-3">
                    <label className="text-xs text-gray-500">Nombre Pack</label>
                    <input
                      className="w-full text-sm border rounded p-1"
                      placeholder="Ej: Caja x12"
                      value={newPresentation.nombre_presentacion}
                      onChange={e => setNewPresentation({ ...newPresentation, nombre_presentacion: e.target.value })}
                    />
                  </div>
                  <div className="col-span-3">
                    <label className="text-xs text-gray-500">Cód. Barra</label>
                    <input
                      className="w-full text-sm border rounded p-1"
                      placeholder="Scan..."
                      value={newPresentation.codigo_barra}
                      onChange={e => setNewPresentation({ ...newPresentation, codigo_barra: e.target.value })}
                    />
                  </div>
                  <div className="col-span-2">
                    <label className="text-xs text-gray-500">Factor</label>
                    <input
                      type="number"
                      className="w-full text-sm border rounded p-1"
                      placeholder="Cant."
                      value={newPresentation.factor_conversion}
                      onChange={e => setNewPresentation({ ...newPresentation, factor_conversion: e.target.value === '' ? '' : Number(e.target.value) })}
                    />
                  </div>
                  <div className="col-span-2">
                    <label className="text-xs text-gray-500">Precio</label>
                    <input
                      type="number"
                      className="w-full text-sm border rounded p-1"
                      placeholder="Opcional"
                      value={newPresentation.precio_venta}
                      onChange={e => setNewPresentation({ ...newPresentation, precio_venta: e.target.value === '' ? '' : Number(e.target.value) })}
                    />
                  </div>
                  <div className="col-span-12 md:col-span-2 mt-2 md:mt-0">
                    <Button type="button" size="sm" onClick={addPresentation} className="w-full bg-indigo-600 hover:bg-indigo-700">
                      <Plus size={16} className="mr-1" /> Añadir
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          )}

          <div className="flex justify-end space-x-3 pt-4">
            <Button type="button" variant="secondary" onClick={() => setShowModal(false)}>Cancelar</Button>
            <Button type="submit" isLoading={loading}>{isEditing ? 'Actualizar' : 'Crear'}</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

function ProviderMasterView() {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [selectedProvider, setSelectedProvider] = useState<Provider | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [showFilter, setShowFilter] = useState<'activos' | 'inactivos' | 'todos'>('activos');

  const { user } = useAuth();
  const canManage = user?.role === 'admin';
  const [formData, setFormData] = useState({
    nombre: '',
    direccion: '',
    clasificacion: 'general',
  });
  const classifications = [
    { value: 'distribuidor', label: 'Distribuidor Mayorista' },
    { value: 'fabrica', label: 'Fábrica Directa' },
    { value: 'local', label: 'Proveedor Local' },
    { value: 'servicios', label: 'Servicios' },
    { value: 'general', label: 'General' },
  ];

  const fetchProviders = useCallback(async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('proveedores')
        .select('*')
        .order('nombre', { ascending: true });

      if (showFilter === 'activos') {
        query = query.eq('activo', true);
      } else if (showFilter === 'inactivos') {
        query = query.eq('activo', false);
      }

      const { data, error } = await query;

      if (error) throw error;
      setProviders(data || []);
    } catch {
      toast.error('Error al cargar los proveedores.');
    } finally {
      setLoading(false);
    }
  }, [showFilter]);

  useEffect(() => {
    fetchProviders();
  }, [showFilter, fetchProviders]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canManage) return toast.error('No tienes permiso.');

    setLoading(true);
    try {
      if (isEditing && selectedProvider) {
        const { error } = await supabase
          .from('proveedores')
          .update(formData)
          .eq('id', selectedProvider.id);
        if (error) throw error;
        toast.success('Proveedor actualizado.');
      } else {
        const { error } = await supabase.from('proveedores').insert([{ ...formData, empresa_id: user?.empresa_id }]);
        if (error) throw error;
        toast.success('Nuevo proveedor creado.');
      }
      setShowModal(false);
      fetchProviders();
    } catch (error: unknown) {
      toast.error(error instanceof Error ? error.message : 'Error al guardar el proveedor.');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleActivo = async (id: string, currentActivo: boolean) => {
    const action = currentActivo ? 'desactivar' : 'reactivar';
    if (!canManage || !confirm(`¿Seguro que quieres ${action} este proveedor?`)) return;

    try {
      const { error } = await supabase
        .from('proveedores')
        .update({ activo: !currentActivo })
        .eq('id', id);
      if (error) throw error;
      toast.success(`Proveedor ${currentActivo ? 'desactivado' : 'reactivado'} correctamente.`);
      fetchProviders();
    } catch (error: unknown) {
      toast.error('Error: ' + (error instanceof Error ? error.message : 'Error desconocido'));
    }
  };

  const openModal = (provider?: Provider) => {
    if (provider) {
      setSelectedProvider(provider);
      setIsEditing(true);
      setFormData({
        nombre: provider.nombre,
        direccion: provider.direccion || '',
        clasificacion: provider.clasificacion || 'otros',
      });
    } else {
      setSelectedProvider(null);
      setIsEditing(false);
      setFormData({ nombre: '', direccion: '', clasificacion: 'medicamentos' });
    }
    setShowModal(true);
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-4">
        {/* Filtro de estado */}
        <div className="flex gap-2">
          <button
            onClick={() => setShowFilter('activos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'activos' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Activos
          </button>
          <button
            onClick={() => setShowFilter('inactivos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'inactivos' ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Inactivos
          </button>
          <button
            onClick={() => setShowFilter('todos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'todos' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Todos
          </button>
        </div>

        {canManage && (
          <Button onClick={() => openModal()}>
            <Plus className="w-4 h-4 mr-2" />
            Agregar Proveedor
          </Button>
        )}
      </div>
      <Card>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nombre</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Dirección</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Clasificación</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Acciones</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {providers.map((provider) => (
                <tr key={provider.id} className={provider.activo === false ? 'bg-red-50 opacity-60' : ''}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <Badge variant={provider.activo !== false ? 'success' : 'danger'}>
                      {provider.activo !== false ? 'Activo' : 'Inactivo'}
                    </Badge>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{provider.nombre}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{provider.direccion}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{provider.clasificacion}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    {canManage && (
                      <div className="flex space-x-2">
                        <button onClick={() => openModal(provider)} className="text-green-600 hover:text-green-900" title="Editar">
                          <Edit className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleToggleActivo(provider.id, provider.activo !== false)}
                          className={provider.activo !== false ? "text-orange-600 hover:text-orange-900" : "text-green-600 hover:text-green-900"}
                          title={provider.activo !== false ? 'Desactivar' : 'Reactivar'}
                        >
                          <Power className="w-4 h-4" />
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Modal isOpen={showModal} onClose={() => setShowModal(false)} title={isEditing ? 'Editar Proveedor' : 'Agregar Proveedor'}>
        <form onSubmit={handleSubmit} className="space-y-4">
          <Input label="Nombre del Proveedor" name="nombre" value={formData.nombre} onChange={(e) => setFormData(p => ({ ...p, nombre: e.target.value }))} required />
          <Input label="Dirección" name="direccion" value={formData.direccion} onChange={(e) => setFormData(p => ({ ...p, direccion: e.target.value }))} />
          <Select label="Clasificación" name="clasificacion" options={classifications} value={formData.clasificacion} onChange={(e) => setFormData(p => ({ ...p, clasificacion: e.target.value }))} required />
          <div className="flex justify-end space-x-3 pt-4">
            <Button type="button" variant="secondary" onClick={() => setShowModal(false)}>Cancelar</Button>
            <Button type="submit" isLoading={loading}>{isEditing ? 'Actualizar' : 'Crear'}</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

function CategoryMasterView() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<Category | null>(null);
  const [formData, setFormData] = useState({ nombre: '', descripcion: '' });
  const [showFilter, setShowFilter] = useState<'activos' | 'inactivos' | 'todos'>('activos');
  const { user } = useAuth();
  const canManage = user?.role === 'admin';

  const fetchCategories = useCallback(async () => {
    setLoading(true);
    let query = supabase.from('categorias').select('*').order('nombre');

    if (showFilter === 'activos') {
      query = query.eq('activo', true);
    } else if (showFilter === 'inactivos') {
      query = query.eq('activo', false);
    }

    const { data } = await query;
    setCategories(data || []);
    setLoading(false);
  }, [showFilter]);

  useEffect(() => { fetchCategories(); }, [showFilter, fetchCategories]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canManage) return toast.error('Sin permisos');

    setLoading(true);
    try {
      if (selectedCategory) {
        const { error } = await supabase.from('categorias').update(formData).eq('id', selectedCategory.id);
        if (error) throw error;
        toast.success('Categoría actualizada');
      } else {
        const { error } = await supabase.from('categorias').insert([{ ...formData, empresa_id: user?.empresa_id }]);
        if (error) throw error;
        toast.success('Categoría creada');
      }
      setShowModal(false);
      fetchCategories();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Error al guardar categoría');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleActivo = async (id: string, currentActivo: boolean) => {
    const action = currentActivo ? 'desactivar' : 'reactivar';
    if (!canManage || !confirm(`¿Seguro que quieres ${action} esta categoría?`)) return;

    try {
      const { error } = await supabase
        .from('categorias')
        .update({ activo: !currentActivo })
        .eq('id', id);
      if (error) throw error;
      toast.success(`Categoría ${currentActivo ? 'desactivada' : 'reactivada'} correctamente.`);
      fetchCategories();
    } catch (error: unknown) {
      toast.error('Error: ' + (error instanceof Error ? error.message : 'Error desconocido'));
    }
  };

  const openModal = (cat?: Category) => {
    setSelectedCategory(cat || null);
    setFormData(cat ? { nombre: cat.nombre, descripcion: cat.descripcion || '' } : { nombre: '', descripcion: '' });
    setShowModal(true);
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-4">
        {/* Filtro de estado */}
        <div className="flex gap-2">
          <button
            onClick={() => setShowFilter('activos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'activos' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Activos
          </button>
          <button
            onClick={() => setShowFilter('inactivos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'inactivos' ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Inactivos
          </button>
          <button
            onClick={() => setShowFilter('todos')}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${showFilter === 'todos' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
          >
            Todos
          </button>
        </div>

        {canManage && <Button onClick={() => openModal()}><Plus className="w-4 h-4 mr-2" /> Nueva Categoría</Button>}
      </div>
      <Card>
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nombre</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Descripción</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Acciones</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {categories.map(cat => (
              <tr key={cat.id} className={cat.activo === false ? 'bg-red-50 opacity-60' : ''}>
                <td className="px-6 py-4 whitespace-nowrap">
                  <Badge variant={cat.activo !== false ? 'success' : 'danger'}>
                    {cat.activo !== false ? 'Activo' : 'Inactivo'}
                  </Badge>
                </td>
                <td className="px-6 py-4 font-medium">{cat.nombre}</td>
                <td className="px-6 py-4 text-gray-500">{cat.descripcion}</td>
                <td className="px-6 py-4 text-right">
                  {canManage && (
                    <div className="flex justify-end space-x-2">
                      <button onClick={() => openModal(cat)} className="text-blue-600 hover:text-blue-900" title="Editar">
                        <Edit size={16} />
                      </button>
                      <button
                        onClick={() => handleToggleActivo(cat.id, cat.activo !== false)}
                        className={cat.activo !== false ? "text-orange-600 hover:text-orange-900" : "text-green-600 hover:text-green-900"}
                        title={cat.activo !== false ? 'Desactivar' : 'Reactivar'}
                      >
                        <Power size={16} />
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>

      <Modal isOpen={showModal} onClose={() => setShowModal(false)} title={selectedCategory ? 'Editar Categoría' : 'Nueva Categoría'}>
        <form onSubmit={handleSubmit} className="space-y-4">
          <Input label="Nombre" value={formData.nombre} onChange={e => setFormData({ ...formData, nombre: e.target.value })} required />
          <Input label="Descripción" value={formData.descripcion} onChange={e => setFormData({ ...formData, descripcion: e.target.value })} />
          <div className="flex justify-end pt-4 space-x-2">
            <Button type="button" variant="secondary" onClick={() => setShowModal(false)}>Cancelar</Button>
            <Button type="submit" isLoading={loading}>Guardar</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
} 