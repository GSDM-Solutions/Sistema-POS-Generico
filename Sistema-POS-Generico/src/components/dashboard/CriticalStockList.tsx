import React, { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Card } from '../ui/Card';

import { AlertTriangle } from 'lucide-react';
import toast from 'react-hot-toast';

type CriticalProduct = {
  maestro_producto_id: string;
  nombre: string;
  stock_actual: number;
  stock_critico: number;
  categoria: string;
  unidad_medida: string;
};

export function CriticalStockList() {
  const [products, setProducts] = useState<CriticalProduct[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchCriticalProducts = async () => {
      setLoading(true);
      try {
        const { data, error } = await supabase.rpc('get_critical_stock_products_list');
        if (error) {
          throw error;
        }
        setProducts(data || []);
      } catch {
        toast.error('Error al cargar productos con stock crítico');
      } finally {
        setLoading(false);
      }
    };

    fetchCriticalProducts();
  }, []);

  if (loading) {
    return (
      <Card className="p-4 col-span-full">
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      </Card>
    );
  }

  return (
    <Card className="p-4 col-span-full">
      <div className="flex items-center mb-4">
        <AlertTriangle className="h-6 w-6 text-orange-500 mr-2" />
        <h2 className="text-lg font-semibold text-gray-800">Productos en Stock Crítico ({products.length})</h2>
      </div>

      {products.length === 0 ? (
        <p className="text-gray-600">No hay productos actualmente en stock crítico.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Producto</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Stock Actual</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Stock Crítico</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Categoría</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">U. Medida</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {products.map((product, idx) => (
                <tr key={`${product.maestro_producto_id}-${idx}`}>
                  <td className="px-4 py-2 whitespace-nowrap text-sm font-medium text-gray-900">{product.nombre}</td>
                  <td className="px-4 py-2 whitespace-nowrap text-sm text-red-600 font-semibold">{product.stock_actual}</td>
                  <td className="px-4 py-2 whitespace-nowrap text-sm text-gray-700">{product.stock_critico}</td>
                  <td className="px-4 py-2 whitespace-nowrap text-sm text-gray-700">
                    {product.categoria || 'N/A'}
                  </td>
                  <td className="px-4 py-2 whitespace-nowrap text-sm text-gray-700">{product.unidad_medida || 'N/A'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
