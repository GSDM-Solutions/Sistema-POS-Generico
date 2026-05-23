import { useEffect, useState } from 'react';
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
    (async () => {
      setLoading(true);
      try {
        const { data, error } = await supabase.rpc('get_critical_stock_products_list');
        if (error) throw error;
        setProducts(data || []);
      } catch {
        toast.error('Error al cargar stock critico');
      } finally { setLoading(false); }
    })();
  }, []);

  if (loading) {
    return <Card className="p-4"><div className="flex items-center justify-center h-24"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div></div></Card>;
  }

  return (
    <Card className="p-4">
      <div className="flex items-center gap-2 mb-3">
        <AlertTriangle className="h-5 w-5 text-orange-500" />
        <h3 className="font-bold text-gray-800 text-sm">Stock Critico ({products.length})</h3>
      </div>
      {products.length === 0 ? (
        <p className="text-gray-400 text-xs">Sin productos en estado critico.</p>
      ) : (
        <div className="space-y-1.5 max-h-64 overflow-y-auto">
          {products.map(p => (
            <div key={p.maestro_producto_id} className="flex items-center justify-between gap-2 py-1.5 px-2 rounded-lg hover:bg-gray-50 text-xs">
              <div className="flex-1 min-w-0">
                <p className="font-medium text-gray-800 truncate">{p.nombre}</p>
                <p className="text-gray-400 truncate">{p.categoria || 'N/A'} &middot; {p.unidad_medida || 'UN'}</p>
              </div>
              <div className="text-right flex-shrink-0">
                <span className="text-red-600 font-bold">{p.stock_actual}</span>
                <span className="text-gray-400"> / {p.stock_critico}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}
