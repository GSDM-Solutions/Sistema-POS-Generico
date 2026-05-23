import { Link, useLocation } from 'react-router-dom';
import { LayoutPanelLeft } from 'lucide-react';
import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { useLayout } from '../../contexts/LayoutContext';
import {
  ShoppingBag,
  Layers,
  Home,
  Package,
  History,
  Users,
  Settings,
  LogOut,
  Truck,
  RefreshCw,
  FileText,
  Clock,
  Shield,
  Printer
} from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { clsx } from 'clsx';

// Definimos grupos de navegación para mejorar la UX
const navigationGroups = [
  {
    title: 'Principal',
    items: [
      { name: 'Dashboard', href: '/', icon: Home, permission: 'view_dashboard' },
    ]
  },
  {
    title: 'Punto de Venta',
    items: [
      { name: 'Pre-Ventas', href: '/preventas', icon: FileText, permission: 'create_presales' },
      { name: 'Cajero Pre-Ventas', href: '/preventas/cajero', icon: Clock, permission: 'confirm_presales' },
      { name: 'Historial Ventas', href: '/sales', icon: History, permission: 'all' },
      { name: 'Clientes', href: '/customers', icon: Users, permission: 'manage_customers' },
    ]
  },
  {
    title: 'Inventario',
    items: [
      { name: 'Bodega General', href: '/inventory', icon: Package, permission: 'view_stock' },
      { name: 'Traslados', href: '/traslados', icon: Truck, permission: 'all' },
      { name: 'Recepción', href: '/entries', icon: Truck, permission: 'entries' },
    ]
  },
  {
    title: 'Gestión',
    items: [
      { name: 'Ajustes', href: '/audit', icon: RefreshCw, permission: 'all' },
      { name: 'Movimientos', href: '/movements', icon: RefreshCw, permission: 'all' },
      { name: 'Maestros', href: '/product-master', icon: Layers, permission: 'manage_master_products' },
      { name: 'Imprimir Códigos', href: '/print-barcodes', icon: Printer, permission: 'manage_master_products' },
      { name: 'Usuarios', href: '/users', icon: Settings, permission: 'all' },
      { name: 'Super Admin', href: '/superadmin', icon: Shield, permission: 'superadmin' },
    ]
  }
];

// Vista simplificada para Cajero/Vendedor
const navigationGroupsCajero = [
  {
    title: 'Principal',
    items: [
      { name: 'Dashboard', href: '/', icon: Home, permission: 'view_dashboard' },
    ]
  },
  {
    title: 'Punto de Venta',
    items: [
      { name: 'Pre-Ventas', href: '/preventas', icon: FileText, permission: 'create_presales' },
      { name: 'Cajero Pre-Ventas', href: '/preventas/cajero', icon: Clock, permission: 'confirm_presales' },
      { name: 'Clientes', href: '/customers', icon: Users, permission: 'manage_customers' },
    ]
  },
  {
    title: 'Inventario',
    items: [
      { name: 'Bodega de Venta', href: '/inventory', icon: Package, permission: 'view_stock' },
    ]
  }
];

export function Sidebar() {
  const location = useLocation();
  const { user, hasPermission, logout } = useAuth();
  const { toggleLayout } = useLayout();
  const [empresaNombre, setEmpresaNombre] = useState('GESTIÓNPRO');

  const isAdminOrSupervisor = user?.role === 'admin' || user?.role === 'superadmin' || user?.role === 'supervisor';
  const groups = isAdminOrSupervisor ? navigationGroups : navigationGroupsCajero;

  useEffect(() => {
    const fetchEmpresa = async () => {
      if (user?.empresa_id) {
        const { data } = await supabase
          .from('empresas')
          .select('nombre_comercial')
          .eq('id', user.empresa_id)
          .single();

        if (data?.nombre_comercial) {
          setEmpresaNombre(data.nombre_comercial);
        }
      }
    };
    fetchEmpresa();
  }, [user?.empresa_id]);

  return (
    <div className="flex flex-col w-72 bg-slate-900 border-r border-slate-800 text-slate-300 transition-all duration-300">
      {/* Brand Header */}
      <div className="flex items-center h-20 px-6 bg-slate-950 border-b border-slate-800 shadow-sm">
        <div className="p-2 bg-blue-600 rounded-lg mr-3 shadow-lg shadow-blue-900/20">
          <ShoppingBag className="text-white h-6 w-6" />
        </div>
        <div>
          <h1 className="text-lg font-bold text-white tracking-tight">{empresaNombre}</h1>
          <div className="flex items-center gap-2 mt-0.5">
            <p className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">
              {isAdminOrSupervisor ? 'Admin - Bodega General' : 'Vendedor - Bodega Venta'}
            </p>
          </div>
        </div>
      </div>

      {/* Navigation Groups */}
      <div className="flex-1 flex flex-col overflow-y-auto py-6 px-4 space-y-8 dark-scrollbar">
        {groups.map((group, idx) => {
          // Filter items based on permission
          const filteredItems = group.items.filter(item =>
            hasPermission(item.permission) ||
            (user?.role === 'admin' && item.permission === 'all') ||
            (user?.role === 'superadmin' && item.permission === 'superadmin')
          );

          if (filteredItems.length === 0) return null;

          return (
            <div key={idx}>
              <h3 className="px-3 text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">{group.title}</h3>
              <div className="space-y-1">
                {filteredItems.map((item) => {
                  const isActive = location.pathname === item.href;
                  return (
                    <Link
                      key={item.name}
                      to={item.href}
                      className={clsx(
                        'group flex items-center px-3 py-2.5 text-sm font-medium rounded-xl transition-all duration-200',
                        isActive
                          ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-900/20 translate-x-1'
                          : 'hover:bg-slate-800 hover:text-white hover:translate-x-1'
                      )}
                    >
                      <item.icon className={clsx(
                        "mr-3 h-5 w-5 transition-colors",
                        isActive ? "text-white" : "text-slate-400 group-hover:text-emerald-400"
                      )} />
                      {item.name}
                    </Link>
                  );
                })}
              </div>
            </div>
          )
        })}
      </div>



      {/* User Footer */}
      <div className="p-4 bg-slate-950 border-t border-slate-800">
        <div className="flex items-center mb-4 px-2">
          <button
            onClick={toggleLayout}
            className="p-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg mr-2 transition-colors"
            title="Cambiar diseño"
          >
            <LayoutPanelLeft size={20} />
          </button>
          <div className="flex-1 overflow-hidden">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-gradient-to-tr from-blue-600 to-indigo-600 rounded-full flex items-center justify-center shadow-lg text-white font-bold text-xs">
                {user?.name.charAt(0).toUpperCase()}
              </div>
              <div className="overflow-hidden">
                <p className="text-sm font-medium text-white truncate">{user?.name}</p>
                <p className="text-xs text-slate-400 capitalize truncate">{user?.role}</p>
              </div>
            </div>
          </div>
        </div>

        <button
          onClick={logout}
          className="flex items-center w-full px-3 py-2 text-sm font-medium text-red-400 hover:bg-red-950/30 hover:text-red-300 rounded-lg transition-colors"
        >
          <LogOut className="mr-3 h-4 w-4" />
          Cerrar Sesión
        </button>
      </div>
    </div>
  );
}