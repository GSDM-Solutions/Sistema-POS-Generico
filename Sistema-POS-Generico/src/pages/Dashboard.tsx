import React, { useEffect, useState } from 'react';
import { DashboardStats as DashboardStatsComponent } from '../components/dashboard/DashboardStats';
import { RecentMovements } from '../components/dashboard/RecentMovements';
import { CategoryChart } from '../components/dashboard/CategoryChart';
import { TopProductsList } from '../components/dashboard/TopProductsList';
import { SalesTrendChart } from '../components/dashboard/SalesTrendChart';
import { DashboardStats } from '../types';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';
import { CriticalStockList } from '../components/dashboard/CriticalStockList';
import { ExpiringProductsList } from '../components/dashboard/ExpiringProductsList';
import { ShoppingCart, Truck, Package, Users, ArrowRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Skeleton } from '../components/ui/Skeleton';

export function Dashboard() {
  const [stats, setStats] = useState<DashboardStats>({
    total_products: 0,
    critical_stock_products: 0,
    total_ventas_hoy: 0,
    total_fiado_pendiente: 0,
    expired_products: 0,
    quarantine_products: 0,
    recent_movements: [],
    category_distribution: [],
    top_products: [],
    sales_trend: []
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase.rpc('get_dashboard_stats');

      if (error) {
        console.error('Error fetching dashboard stats:', error);
        throw error;
      }

      if (data) {
        console.log('Dashboard Data from Supabase:', data);
        setStats(data);
      }

    } catch {
      toast.error('Error al cargar los datos del dashboard.');
    } finally {
      setLoading(false);
    }
  };

  const QuickActionCard = ({ to, icon: Icon, title, desc, gradient, iconColor }: { to: string; icon: React.ElementType; title: string; desc: string; gradient: string; iconColor: string }) => (
    <Link to={to} className={`group p-6 rounded-3xl shadow-md hover:shadow-2xl transition-all duration-500 hover:-translate-y-2 relative overflow-hidden border border-white/40 ${gradient} backdrop-blur-sm`}>
      <div className="absolute top-0 right-0 w-32 h-32 -mr-12 -mt-12 rounded-full bg-white opacity-20 blur-2xl group-hover:blur-xl transition-all duration-500"></div>
      <div className="absolute bottom-0 left-0 w-24 h-24 -ml-8 -mb-8 rounded-full bg-black opacity-5 blur-2xl"></div>
      
      <div className="relative z-10 flex items-start justify-between">
        <div>
          <div className={`p-3.5 rounded-2xl w-fit mb-5 bg-white/90 shadow-sm backdrop-blur-md ${iconColor} group-hover:scale-110 transition-transform duration-300`}>
            <Icon size={26} strokeWidth={2.5} />
          </div>
          <h3 className="font-extrabold text-white text-xl mb-1 tracking-tight">{title}</h3>
          <p className="text-white/80 text-sm font-medium">{desc}</p>
        </div>
        <div className="opacity-0 group-hover:opacity-100 transition-opacity duration-300 text-white bg-white/20 p-2 rounded-full backdrop-blur-sm">
          <ArrowRight size={20} strokeWidth={3} />
        </div>
      </div>
    </Link>
  );

  if (loading) {
    return (
      <div className="space-y-8">
        <div>
          <Skeleton width="250px" height="36px" className="mb-2" />
          <Skeleton width="350px" height="20px" />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 space-y-3">
              <Skeleton variant="circular" width="48px" height="48px" />
              <Skeleton width="70%" height="20px" />
              <Skeleton width="50%" height="14px" />
            </div>
          ))}
        </div>

        <div className="border-t border-slate-200 pt-8">
          <Skeleton width="200px" height="28px" className="mb-6" />
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="bg-white p-4 rounded-xl shadow-sm border space-y-2">
                <Skeleton width="60%" height="14px" />
                <Skeleton width="80%" height="28px" />
              </div>
            ))}
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 bg-white p-6 rounded-2xl shadow-sm border">
            <Skeleton width="150px" height="20px" className="mb-4" />
            <Skeleton height="200px" />
          </div>
          <div className="bg-white p-6 rounded-2xl shadow-sm border space-y-3">
            <Skeleton width="150px" height="20px" />
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} height="16px" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-10 pb-10">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <h1 className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-slate-900 via-slate-700 to-slate-800 tracking-tight">Panel de Control</h1>
          <p className="text-slate-500 mt-2 font-medium text-lg">Bienvenido al sistema de gestión MarketPro.</p>
        </div>
        <div className="bg-white/60 backdrop-blur-md border border-slate-200/60 px-5 py-2.5 rounded-2xl shadow-sm">
          <p className="text-sm font-semibold text-slate-600">
            {new Date().toLocaleDateString('es-CL', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
          </p>
        </div>
      </div>

      {/* Quick Actions Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        <QuickActionCard
          to="/pos"
          icon={ShoppingCart}
          title="Punto de Venta"
          desc="Iniciar nueva venta"
          gradient="bg-gradient-to-br from-emerald-500 via-emerald-600 to-teal-700"
          iconColor="text-emerald-600"
        />
        <QuickActionCard
          to="/entries"
          icon={Truck}
          title="Recepción"
          desc="Ingresar mercadería"
          gradient="bg-gradient-to-br from-blue-500 via-blue-600 to-indigo-700"
          iconColor="text-blue-600"
        />
        <QuickActionCard
          to="/inventory"
          icon={Package}
          title="Inventario"
          desc="Consultar stock"
          gradient="bg-gradient-to-br from-violet-500 via-purple-600 to-fuchsia-700"
          iconColor="text-purple-600"
        />
        <QuickActionCard
          to="/customers"
          icon={Users}
          title="Clientes"
          desc="Gestionar cuentas"
          gradient="bg-gradient-to-br from-amber-500 via-orange-500 to-rose-600"
          iconColor="text-orange-600"
        />
      </div>

      <div className="border-t border-slate-200/60 pt-8">
        <div className="flex items-center gap-3 mb-8">
            <div className="h-8 w-2 bg-gradient-to-b from-blue-500 to-indigo-600 rounded-full"></div>
            <h2 className="text-2xl font-black text-slate-800 tracking-tight">Métricas en Tiempo Real</h2>
        </div>
        <DashboardStatsComponent stats={stats} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <SalesTrendChart data={stats.sales_trend || []} />
        </div>
        <div>
          <TopProductsList products={stats.top_products || []} />
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-6">
          <h3 className="font-bold text-slate-700 mt-4 flex items-center gap-2"><div className="w-2 h-2 bg-red-500 rounded-full"></div> Alertas de Stock</h3>
          <CriticalStockList />
          <ExpiringProductsList daysThreshold={30} title="Vencimiento Cercano (30 días)" />
        </div>
        <div className="space-y-6">
          <h3 className="font-bold text-slate-700 mt-4 flex items-center gap-2"><div className="w-2 h-2 bg-blue-500 rounded-full"></div> Actividad Reciente</h3>
          <RecentMovements movements={stats.recent_movements} />
          <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
            <h4 className="font-bold text-gray-800 mb-4">Distribución por Categoría</h4>
            <CategoryChart data={stats.category_distribution} />
          </div>
        </div>
      </div>
    </div>
  );
}
