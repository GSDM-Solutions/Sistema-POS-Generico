import React, { useEffect, useState } from 'react';
import { Search, Filter, Eye } from 'lucide-react';
import { format } from 'date-fns';
import { Provider, MasterProduct } from '../types';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Card } from '../components/ui/Card';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import toast from 'react-hot-toast';
import { PRODUCT_CATEGORIES } from '../lib/categories';

type LoteInfo = {
  id?: string;
  producto_id?: string;
  proveedor_id?: string;
  proveedor_nombre?: string;
  numero_lote?: string;
  fecha_vencimiento?: string;
  stock_actual?: number;
  observaciones?: string;
};

type InventoryProduct = {
  id: string;
  stock_actual: number;
  numero_lote: string;
  fecha_vencimiento: string | null;
  proveedor_id: string | null;
  observaciones: string;
  bodega_nombre?: string;
  maestro_productos: {
    id: string;
    nombre: string;
    codigo_barra: string;
    categoria: string;
    precio_venta: number;
    stock_critico: number;
  };
  proveedores: { id: string; nombre: string } | null;
  todosLotes: LoteInfo[];
};

export function Inventory() {
  const [products, setProducts] = useState<InventoryProduct[]>([]);
  const [filteredProducts, setFilteredProducts] = useState<InventoryProduct[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [bodegaFilter, setBodegaFilter] = useState('');
  const [bodegas, setBodegas] = useState<{ id: string; nombre: string; tipo: string }[]>([]);
  const [showModal, setShowModal] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState<InventoryProduct | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const { user, hasPermission } = useAuth();

  // Usar sistema de permisos centralizado
  const canManageStock = hasPermission('manage_stock');

  const [formData, setFormData] = useState({
    maestro_producto_id: '',
    proveedor_id: '',
    stock_actual: 0,
    numero_lote: '',
    fecha_vencimiento: '',
    condicion: 'Bueno',
    observaciones: ''
  });

  const [masterProductsList, setMasterProductsList] = useState<MasterProduct[]>([]);
  const [providersList, setProvidersList] = useState<Provider[]>([]);

  const categories = PRODUCT_CATEGORIES;

  const isAdminOrSupervisor = user?.role === 'admin' || user?.role === 'superadmin' || user?.role === 'supervisor';
  const isCajero = user?.role === 'empleado';

  const fetchBodegas = async () => {
    if (!user?.empresa_id) return;
    const { data, error } = await supabase.from('bodegas').select('id, nombre, tipo').eq('empresa_id', user.empresa_id).order('tipo');
    if (error) {
      toast.error('Error al cargar bodegas: ' + error.message);
      return;
    }
    if (data && data.length > 0) setBodegas(data);
  };

  const fetchProducts = async () => {
    setLoading(true);
    try {
      let bodegaId: string | null = null;

      if (isCajero) {
        const ventaBodega = bodegas.find(b => b.tipo === 'venta');
        bodegaId = ventaBodega?.id || null;
      } else if (bodegaFilter) {
        bodegaId = bodegaFilter;
      }

      const result = await supabase.rpc('get_inventory_por_bodega', {
        p_filtro_bodega: bodegaId
      });
      if (result.error) throw result.error;
      const data = result.data;

      const mappedData = (data as Record<string, unknown>[]).map((item: Record<string, unknown>) => ({
        id: item.id as string,
        stock_actual: item.stock_actual as number,
        numero_lote: (item.numero_lote as string) || '',
        fecha_vencimiento: item.fecha_vencimiento as string || null,
        proveedor_id: null,
        observaciones: '',
        maestro_productos: {
          id: item.id as string,
          nombre: item.nombre_producto as string,
          codigo_barra: item.codigo_barra as string || '',
          categoria: (item.categoria as string) || '',
          precio_venta: item.precio_venta as number,
          stock_critico: 5
        },
        proveedores: null,
        todosLotes: [{
          id: item.id as string,
          producto_id: item.id as string,
          proveedor_id: null,
          proveedor_nombre: null,
          numero_lote: (item.numero_lote as string) || '',
          fecha_vencimiento: item.fecha_vencimiento as string || null,
          stock_actual: item.stock_actual as number,
          observaciones: ''
        }],
        bodega_nombre: item.bodega_nombre as string
      }));

      setProducts(mappedData as InventoryProduct[]);
    } catch {
      toast.error('Error al cargar el inventario.');
    } finally {
      setLoading(false);
    }
  };

  const fetchMasterProductsList = async () => {
    try {
      const { data, error } = await supabase.from('maestro_productos').select('id, nombre');
      if (error) throw error;
      setMasterProductsList((data as Pick<MasterProduct, 'id' | 'nombre'>[]) || []);
    } catch {
      toast.error('Error al cargar catálogo.');
    }
  };

  const fetchProvidersList = async () => {
    try {
      const { data, error } = await supabase.from('proveedores').select('id, nombre');
      if (error) throw error;
      setProvidersList((data as Pick<Provider, 'id' | 'nombre'>[]) || []);
    } catch {
      toast.error('Error al cargar proveedores.');
    }
  };

  useEffect(() => {
    if (user?.empresa_id) {
      fetchBodegas();
    }
  }, [user?.empresa_id]);

  useEffect(() => {
    fetchProducts();
    fetchMasterProductsList();
    fetchProvidersList();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bodegaFilter, bodegas]);

  useEffect(() => {
    let filtered = products;
    if (searchTerm) {
      const lowerSearch = searchTerm.toLowerCase();
      filtered = filtered.filter(p =>
        p.maestro_productos?.nombre.toLowerCase().includes(lowerSearch) ||
        p.proveedores?.nombre?.toLowerCase().includes(lowerSearch) ||
        p.numero_lote?.toLowerCase().includes(lowerSearch)
      );
    }
    if (categoryFilter) {
      filtered = filtered.filter(p => p.maestro_productos?.categoria === categoryFilter);
    }
    setFilteredProducts(filtered);
  }, [products, searchTerm, categoryFilter]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canManageStock) return;
    setLoading(true);

    try {
      const isCreatingNew = !selectedProduct;

      if (isCreatingNew) {
        const upperCaseLote = (formData.numero_lote || 'S/L').toUpperCase();

        if (formData.numero_lote) {
          const { data: existing } = await supabase
            .from('productos')
            .select('id')
            .eq('numero_lote', upperCaseLote)
            .maybeSingle();

          if (existing) throw new Error(`Ya existe un lote con el número "${upperCaseLote}".`);
        }
        formData.numero_lote = upperCaseLote;
      }

      const productData = {
        ...formData,
        stock_actual: Number(formData.stock_actual),
        fecha_ingreso: isCreatingNew ? new Date().toISOString() : undefined,
        fecha_vencimiento: formData.fecha_vencimiento || null,
      };

      if (selectedProduct) {
        toast.error('La edición directa está deshabilitada. Use Recepción o Ajustes.');
      } else {
        const { data: newP, error: insErr } = await supabase
          .from('productos')
          .insert([productData])
          .select('id')
          .single();

        if (insErr || !newP) throw insErr || new Error('Error al crear.');

        if (user && productData.stock_actual > 0) {
          await supabase.from('movimientos').insert([{
            producto_id: newP.id,
            usuario_id: user.id,
            tipo_movimiento: 'entrada',
            cantidad: productData.stock_actual,
            motivo: 'Ingreso inicial',
            condicion: 'Bueno',
          }]);
        }
        toast.success('Producto creado.');
      }
      setShowModal(false);
      fetchProducts();
    } catch (error: unknown) {
      toast.error(error instanceof Error ? error.message : 'Error al guardar.');
    } finally {
      setLoading(false);
    }
  };



  const openModal = (product?: InventoryProduct, editMode = false) => {
    setIsEditing(editMode);
    if (product) {
      setSelectedProduct(product);
      setFormData({
        maestro_producto_id: product.maestro_productos.id,
        proveedor_id: product.proveedor_id || '',
        stock_actual: product.stock_actual || 0,
        numero_lote: product.numero_lote || '',
        fecha_vencimiento: product.fecha_vencimiento ? format(new Date(product.fecha_vencimiento), 'yyyy-MM-dd') : '',
        condicion: 'Bueno',
        observaciones: product.observaciones || '',
      });
    } else {
      setSelectedProduct(null);
      setFormData({ maestro_producto_id: '', proveedor_id: '', stock_actual: 0, numero_lote: '', fecha_vencimiento: '', condicion: 'Bueno', observaciones: '' });
    }
    setShowModal(true);
  };

  const getStockStatus = (product: InventoryProduct) => {
    const stock = product.stock_actual || 0;
    const critical = product.maestro_productos?.stock_critico || 5;
    if (stock === 0) return { variant: 'danger' as const, label: 'Sin Stock' };
    if (stock <= critical) return { variant: 'warning' as const, label: 'Stock Crítico' };
    return { variant: 'success' as const, label: 'Stock Normal' };
  };

  if (loading && products.length === 0) {
    return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div></div>;
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Inventario de Productos</h1>
          <p className="text-gray-600 mt-2">
            {isAdminOrSupervisor ? 'Bodega General — Gestión completa de stock' : 'Bodega de Venta — Stock disponible para POS'}
          </p>
        </div>
      </div>

      <Card className="mb-6 p-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
          <div className="space-y-1.5">
            <label className="text-sm font-semibold text-slate-700">Buscar Producto</label>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-4 h-4" />
              <Input placeholder="Buscar por nombre o lote..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} className="pl-10" />
            </div>
          </div>
          
          <div className="space-y-1.5">
            <label className="text-sm font-semibold text-slate-700">Categoría</label>
            <Select options={[{ value: '', label: 'Todas las categorías' }, ...categories]} value={categoryFilter} onChange={(e) => setCategoryFilter(e.target.value)} />
          </div>

          {isAdminOrSupervisor && (
            <div className="space-y-1.5">
              <label className="text-sm font-semibold text-slate-700">Bodega</label>
              <Select
                options={[
                  { value: '', label: 'Todas las bodegas' },
                  ...bodegas.map(b => ({ value: b.id, label: `${b.nombre} (${b.tipo})` }))
                ]}
                value={bodegaFilter}
                onChange={(e) => setBodegaFilter(e.target.value)}
              />
            </div>
          )}

          <div>
            <Button variant="secondary" onClick={() => { setSearchTerm(''); setCategoryFilter(''); setBodegaFilter(''); }} className="w-full justify-center">
              <Filter className="w-4 h-4 mr-2" />
              Limpiar Filtros
            </Button>
          </div>
        </div>
      </Card>

      <Card>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Cód. Barra</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Producto</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Categoría</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Stock Disponible</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Vencimiento</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Acciones</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredProducts.map((product) => {
                const stockStatus = getStockStatus(product);
                return (
                  <tr key={product.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      <div className="text-sm font-medium text-gray-900">{product.maestro_productos?.codigo_barra || '-'}</div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm font-bold text-gray-900">{product.maestro_productos?.nombre}</div>
                      {/* Precio oculto a petición */}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-900 capitalize">{product.maestro_productos?.categoria?.replace('_', ' ')}</td>
                    <td className="px-6 py-4 text-center">
                      <div className="text-sm font-bold text-gray-900">{product.stock_actual}</div>
                      <Badge variant={stockStatus.variant} size="sm">{stockStatus.label}</Badge>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {product.fecha_vencimiento ? format(new Date(product.fecha_vencimiento), 'dd/MM/yyyy') : 'S/V'}
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex space-x-2">
                        <button onClick={() => openModal(product, false)} className="text-blue-600" title="Ver detalle"><Eye className="w-4 h-4" /></button>

                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {filteredProducts.length === 0 && <div className="text-center py-12 text-gray-500">No se encontraron productos</div>}
        </div>
      </Card>

      <Modal isOpen={showModal} onClose={() => setShowModal(false)} title={isEditing ? 'Nuevo Stock' : 'Detalles del Stock'} size="lg">
        {selectedProduct && !isEditing ? (
          <div>
            <div className="mb-4 bg-gray-50 p-4 rounded-lg">
              <h3 className="font-bold text-lg text-gray-800">{selectedProduct.maestro_productos.nombre}</h3>
              <p className="text-gray-500 text-sm">Código: {selectedProduct.maestro_productos.codigo_barra || 'S/C'}</p>
              <p className="text-gray-500 text-sm">Total Stock: <span className="font-bold">{selectedProduct.stock_actual}</span></p>
            </div>

            <h4 className="font-bold text-gray-700 mb-2">Desglose por Lotes/Ingresos</h4>
            <div className="overflow-x-auto border rounded-lg">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Fecha Ingreso</th>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Proveedor</th>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Vencimiento</th>
                    <th className="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Cantidad</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {selectedProduct.todosLotes?.map((lote: LoteInfo) => (
                    <tr key={lote.id}>
                      <td className="px-4 py-2 text-sm text-gray-500">
                        {/* no creado_en here for simplicity, fallback to '-' */}
                        -
                      </td>
                      <td className="px-4 py-2 text-sm text-gray-900 font-medium">
                        {lote.proveedor_nombre || 'Sin Proveedor'}
                      </td>
                      <td className="px-4 py-2 text-sm text-gray-500">
                        {lote.fecha_vencimiento ? format(new Date(lote.fecha_vencimiento), 'dd/MM/yyyy') : 'S/V'}
                      </td>
                      <td className="px-4 py-2 text-sm text-gray-900 font-bold text-right">
                        {lote.stock_actual}
                      </td>
                    </tr>
                  ))}
                  {(!selectedProduct.todosLotes || selectedProduct.todosLotes.length === 0) && (
                    <tr><td colSpan={4} className="p-4 text-center text-gray-500">No hay detalles de lotes disponibles</td></tr>
                  )}
                </tbody>
              </table>
            </div>

            <div className="flex justify-end pt-4">
              <Button type="button" variant="secondary" onClick={() => setShowModal(false)}>Cerrar</Button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Select label="Producto *" options={masterProductsList.map(mp => ({ value: mp.id, label: mp.nombre }))} value={formData.maestro_producto_id} onChange={(e) => setFormData(p => ({ ...p, maestro_producto_id: e.target.value }))} required disabled={!isEditing} />
              <Select label="Proveedor *" options={providersList.map(p => ({ value: p.id, label: p.nombre }))} value={formData.proveedor_id} onChange={(e) => setFormData(p => ({ ...p, proveedor_id: e.target.value }))} required disabled={!isEditing} />
              <Input label="Cantidad *" type="number" step="any" value={formData.stock_actual} onChange={(e) => setFormData(p => ({ ...p, stock_actual: Number(e.target.value) }))} required disabled={!isEditing || !!selectedProduct} />
              {/* Lote oculto, se asigna 'S/L' por defecto */}
              <div className="hidden">
                <Input label="N° Lote" value={formData.numero_lote} onChange={(e) => setFormData(p => ({ ...p, numero_lote: e.target.value }))} disabled={!!selectedProduct} />
              </div>
              <Input label="Vencimiento" type="date" value={formData.fecha_vencimiento} onChange={(e) => setFormData(p => ({ ...p, fecha_vencimiento: e.target.value }))} disabled={!isEditing} />
            </div>
            <textarea
              className="w-full p-2 border rounded-md"
              placeholder="Observaciones..."
              rows={3}
              value={formData.observaciones}
              onChange={(e) => setFormData(p => ({ ...p, observaciones: e.target.value }))}
              disabled={!isEditing}
            />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="secondary" onClick={() => setShowModal(false)}>Cerrar</Button>
              {isEditing && !selectedProduct && <Button type="submit">Guardar Stock</Button>}
            </div>
          </form>
        )}
      </Modal>
    </div>
  );
}