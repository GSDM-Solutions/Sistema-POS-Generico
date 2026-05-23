import { Package, AlertTriangle, TrendingUp, CreditCard } from 'lucide-react';
import { DashboardStats as DashboardStatsType } from '../../types';
import { clsx } from 'clsx'; // Import clsx for conditional classes

interface DashboardStatsProps {
  stats: DashboardStatsType;
}

export function DashboardStats({ stats }: DashboardStatsProps) {
  const statCards = [
    {
      name: 'Total Productos',
      value: stats.total_products,
      icon: Package,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
      isAlert: false, // Not an alert
      alertText: ''
    },
    {
      name: 'Stock Crítico',
      value: stats.critical_stock_products,
      icon: AlertTriangle,
      color: 'text-orange-600',
      bgColor: 'bg-orange-50',
      isAlert: stats.critical_stock_products > 0,
      alertText: stats.critical_stock_products > 0 ? 'Reponer' : ''
    },
    {
      name: 'Ventas de Hoy',
      value: `$${stats.total_ventas_hoy?.toLocaleString() || 0}`,
      icon: TrendingUp,
      color: 'text-emerald-600',
      bgColor: 'bg-emerald-50',
      isAlert: false,
      alertText: ''
    },
    {
      name: 'Por Cobrar (Fiado)',
      value: `$${stats.total_fiado_pendiente?.toLocaleString() || 0}`,
      icon: CreditCard,
      color: 'text-purple-600',
      bgColor: 'bg-purple-50',
      isAlert: stats.total_fiado_pendiente > 0,
      alertText: stats.total_fiado_pendiente > 0 ? 'Gestión de Cobro Reco' : ''
    }
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      {statCards.map((stat) => (
        <div key={stat.name} className="bg-white/80 backdrop-blur-sm p-6 rounded-3xl shadow-sm border border-slate-100/60 hover:shadow-lg transition-all duration-300 group">
          <div className="flex items-center">
            <div className={`p-3 rounded-2xl ${stat.bgColor} group-hover:scale-110 transition-transform duration-300`}>
              <stat.icon className={`h-7 w-7 ${stat.color}`} strokeWidth={2} />
            </div>
            <div className="ml-5">
              <h3 className="text-sm font-semibold text-slate-500 uppercase tracking-wider">{stat.name}</h3>
              <p className={clsx(
                "text-3xl font-black mt-1 tracking-tight",
                stat.isAlert ? "text-rose-600" : "text-slate-800"
              )}>{stat.value}</p>
              {stat.isAlert && (
                <p className="text-xs font-bold text-rose-500 mt-1.5 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-rose-500 animate-pulse"></span>
                  {stat.alertText}
                </p>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}