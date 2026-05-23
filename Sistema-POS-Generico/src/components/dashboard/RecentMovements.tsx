import React from 'react';
import { format, isValid } from 'date-fns';
import { es } from 'date-fns/locale';
import { Badge } from '../ui/Badge';
import { Movement } from '../../types';

interface RecentMovementsProps {
  movements: Movement[];
}

export function RecentMovements({ movements }: RecentMovementsProps) {
  const getMovementTypeLabel = (type: string) => {
    switch (type) {
      case 'entrada':
        return 'Entrada';
      case 'salida_administracion':
        return 'Administración';
      case 'salida_eliminacion':
        return 'Eliminación';
      default:
        return type;
    }
  };

  const getMovementVariant = (type: string) => {
    switch (type) {
      case 'entrada':
        return 'success';
      case 'salida_administracion':
        return 'info';
      case 'salida_eliminacion':
        return 'danger';
      default:
        return 'default';
    }
  };

  const formatDate = (dateString: string | null | undefined, formatString: string) => {
    if (!dateString) return 'Fecha no disponible';
    const date = new Date(dateString);
    return isValid(date) ? format(date, formatString, { locale: es }) : 'Fecha inválida';
  };

  return (
    <div className="bg-white rounded-3xl shadow-sm border border-slate-100/60 flex flex-col">
      <div className="p-6 border-b border-slate-100/60 bg-white/50 backdrop-blur-sm rounded-t-3xl">
        <h3 className="font-bold text-slate-800">Últimos Movimientos</h3>
      </div>
      <div className="p-2 flex-1">
        <div className="max-h-[280px] overflow-y-auto pr-2 overflow-x-hidden space-y-1 scrollbar-thin scrollbar-thumb-slate-200 scrollbar-track-transparent">
          {movements.length === 0 ? (
            <p className="text-slate-400 text-center py-8 text-sm">No hay movimientos recientes</p>
          ) : (
            movements.slice(0, 15).map((movement, index) => (
              <div key={movement.id || index} className="flex items-center justify-between p-3 hover:bg-slate-50 rounded-xl transition-colors group">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-1">
                    <Badge variant={getMovementVariant(movement.tipo_movimiento)} className="text-[10px] px-2 py-0.5">
                      {getMovementTypeLabel(movement.tipo_movimiento)}
                    </Badge>
                    <h4 className="text-sm font-semibold text-slate-800 line-clamp-1">
                      {movement.producto_nombre || 'Producto no disponible'}
                    </h4>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-slate-500">
                    <span className="font-medium bg-slate-100 px-1.5 rounded text-slate-600">
                      Cant: {movement.cantidad}
                    </span>
                    <span className="truncate max-w-[120px]" title={movement.usuario_nombre}>
                      {movement.usuario_nombre || 'Sistema'}
                    </span>
                  </div>
                </div>
                <div className="text-right pl-3">
                  <p className="text-xs font-medium text-slate-600 group-hover:text-slate-900 transition-colors">
                    {formatDate(movement.fecha, 'dd MMM yyyy')}
                  </p>
                  <p className="text-[10px] text-slate-400 mt-0.5">
                    {formatDate(movement.fecha, 'HH:mm')}
                  </p>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
