import React, { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Card } from '../ui/Card';
import { format, differenceInDays } from 'date-fns';
import { es } from 'date-fns/locale';
import { Clock } from 'lucide-react';
import toast from 'react-hot-toast';

type ExpiringProduct = {
  producto_id: string;
  producto_nombre: string;
  numero_lote: string;
  stock_actual: number;
  fecha_vencimiento: string;
  condicion: string;
};

interface ExpiringProductsListProps {
  daysThreshold: number;
  title: string;
}

export function ExpiringProductsList({ daysThreshold, title }: ExpiringProductsListProps) {
  const [products, setProducts] = useState<ExpiringProduct[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchExpiringProducts = async () => {
      setLoading(true);
      try {
        const { data, error } = await supabase.rpc('get_expiring_products_list', { days_threshold: daysThreshold });
        if (error) {
          throw error;
        }
        setProducts(data || []);
      } catch {
        toast.error('Error al cargar productos por vencer');
      } finally {
        setLoading(false);
      }
    };

    fetchExpiringProducts();
  }, [daysThreshold]);

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
        <Clock className="h-6 w-6 text-red-500 mr-2" />
        <h2 className="text-lg font-semibold text-gray-800">{title} ({products.length})</h2>
      </div>

      {products.length === 0 ? (
        <p className="text-gray-600">No hay productos {title.toLowerCase()} actualmente.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Producto</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Stock Actual</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Vencimiento</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Condición</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {products.map((product, idx) => {
                const daysLeft = product.fecha_vencimiento ? differenceInDays(new Date(product.fecha_vencimiento), new Date()) : 999;
                let statusClass = 'text-gray-700';
                if (daysLeft < 15) statusClass = 'text-red-700 font-bold bg-red-100';
                else if (daysLeft < 30) statusClass = 'text-yellow-700 font-bold bg-yellow-100';
                else statusClass = 'text-green-700 bg-green-100';

                return (
                  <tr key={idx}>
                    <td className="px-4 py-2 whitespace-nowrap text-sm font-medium text-gray-900">{product.producto_nombre}</td>
                    <td className="px-4 py-2 whitespace-nowrap text-sm font-semibold">{product.stock_actual}</td>
                    <td className="px-4 py-2 whitespace-nowrap text-sm">
                      <span className={`px-2 py-1 rounded-full ${statusClass}`}>
                        {product.fecha_vencimiento ? format(new Date(product.fecha_vencimiento), 'dd MMM yyyy', { locale: es }) : 'N/A'}
                      </span>
                    </td>
                    <td className="px-4 py-2 whitespace-nowrap text-sm text-gray-700">{product.condicion}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
