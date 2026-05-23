import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { Card } from '../ui/Card';
import { differenceInDays } from 'date-fns';
import { Clock } from 'lucide-react';
import toast from 'react-hot-toast';

type ExpiringProduct = {
  id: string;
  nombre_producto: string;
  numero_lote: string;
  fecha_vencimiento: string;
  stock_actual: number;
  dias_restantes: number;
  bodega_nombre: string;
};

interface Props { daysThreshold: number; title: string; }

export function ExpiringProductsList({ daysThreshold, title }: Props) {
  const [products, setProducts] = useState<ExpiringProduct[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        const { data, error } = await supabase.rpc('get_expiring_products_list', { days_threshold: daysThreshold });
        if (error) throw error;
        setProducts(data || []);
      } catch {
        toast.error('Error al cargar vencimientos');
      } finally { setLoading(false); }
    })();
  }, [daysThreshold]);

  if (loading) {
    return <Card className="p-4"><div className="flex items-center justify-center h-24"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div></div></Card>;
  }

  return (
    <Card className="p-4">
      <div className="flex items-center gap-2 mb-3">
        <Clock className="h-5 w-5 text-red-500" />
        <h3 className="font-bold text-gray-800 text-sm">{title} ({products.length})</h3>
      </div>
      {products.length === 0 ? (
        <p className="text-gray-400 text-xs">Sin productos por vencer.</p>
      ) : (
        <div className="space-y-1.5 max-h-64 overflow-y-auto">
          {products.map((p, idx) => {
            const days = p.dias_restantes ?? (p.fecha_vencimiento ? differenceInDays(new Date(p.fecha_vencimiento), new Date()) : 999);
            const badge = days < 7 ? 'bg-red-100 text-red-700 font-bold' : days < 15 ? 'bg-orange-100 text-orange-700' : 'bg-yellow-100 text-yellow-700';
            return (
              <div key={`${p.id}-${idx}`} className="flex items-center justify-between gap-2 py-1.5 px-2 rounded-lg hover:bg-gray-50 text-xs">
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-gray-800 truncate">{p.nombre_producto}</p>
                  <p className="text-gray-400 truncate">Lote: {p.numero_lote} &middot; {p.bodega_nombre}</p>
                </div>
                <div className="text-right flex-shrink-0">
                  <div className="font-bold text-gray-700">{p.stock_actual}</div>
                  <span className={`px-1.5 py-0.5 rounded-full text-[10px] ${badge}`}>
                    {days}d
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </Card>
  );
}
