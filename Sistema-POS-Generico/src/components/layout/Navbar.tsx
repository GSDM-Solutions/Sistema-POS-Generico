import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useLayout } from '../../contexts/LayoutContext';
import {
    ShoppingBag,
    Home,
    Package,
    History,
    Users,
    Settings,
    LogOut,
    ShoppingCart,
    Truck,
    RefreshCw,
    Layers,
    ChevronDown,
    Menu,
    X,
    LayoutPanelLeft,
    FileText,
    Receipt
} from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { clsx } from 'clsx';

const navigationGroups = [
    {
        title: 'Principal',
        icon: Home,
        items: [
            { name: 'Dashboard', href: '/', icon: Home, permission: 'view_dashboard' },
        ]
    },
    {
        title: 'Punto de Venta',
        icon: ShoppingCart,
        items: [
            { name: 'Caja (POS)', href: '/pos', icon: ShoppingCart, permission: 'pos' },
            { name: 'Pre-Ventas', href: '/preventas', icon: FileText, permission: 'create_presales' },
            { name: 'Cajero Pre-Ventas', href: '/preventas/cajero', icon: Receipt, permission: 'confirm_presales' },
            { name: 'Historial Ventas', href: '/sales', icon: History, permission: 'all' },
            { name: 'Clientes', href: '/customers', icon: Users, permission: 'manage_customers' },
        ]
    },
    {
        title: 'Inventario',
        icon: Package,
        items: [
            { name: 'Bodega', href: '/inventory', icon: Package, permission: 'view_stock' },
            { name: 'Recepción', href: '/entries', icon: Truck, permission: 'entries' },
            { name: 'Ajustes', href: '/audit', icon: RefreshCw, permission: 'all' },
        ]
    },
    {
        title: 'Gestión',
        icon: Settings,
        items: [
            { name: 'Movimientos', href: '/movements', icon: History, permission: 'all' },
            { name: 'Maestros', href: '/product-master', icon: Layers, permission: 'manage_master_products' },
            { name: 'Usuarios', href: '/users', icon: Settings, permission: 'all' },
        ]
    }
];

export function Navbar() {
    const location = useLocation();
    const { user, hasPermission, logout } = useAuth();
    const { toggleLayout } = useLayout();
    const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
    const [activeDropdown, setActiveDropdown] = useState<string | null>(null);

    const isGroupActive = (items: { name: string; href: string; icon: React.ElementType; permission: string }[]) => items.some(item => location.pathname === item.href);

    return (
        <nav className="bg-slate-900 text-slate-200 shadow-md border-b border-slate-800 sticky top-0 z-50">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex items-center justify-between h-16">

                    {/* Logo Section */}
                    <div className="flex items-center flex-shrink-0">
                        <button
                            onClick={toggleLayout}
                            className="p-1.5 mr-3 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors hidden md:block"
                            title="Cambiar vista lateral/superior"
                        >
                            <LayoutPanelLeft className="h-5 w-5" />
                        </button>
                        <div className="p-1.5 bg-blue-600 rounded-lg mr-2 shadow-lg shadow-blue-900/20">
                            <ShoppingBag className="text-white h-5 w-5" />
                        </div>
                        <span className="font-bold text-xl text-white tracking-tight">MARKET<span className="text-blue-400">PRO</span></span>
                    </div>

                    {/* Desktop Navigation */}
                    <div className="hidden md:block ml-10">
                        <div className="flex items-baseline space-x-1">
                            {navigationGroups.map((group) => {
                                // Check permissions for the whole group (if at least one item is allowed)
                                const hasGroupPermission = group.items.some(item =>
                                    hasPermission(item.permission) ||
                                    (item.permission === 'all' && user?.role === 'admin') ||
                                    (item.permission === 'superadmin' && user?.role === 'superadmin')
                                );

                                if (!hasGroupPermission) return null;

                                const active = isGroupActive(group.items);

                                return (
                                    <div
                                        key={group.title}
                                        className="relative group"
                                        onMouseEnter={() => setActiveDropdown(group.title)}
                                        onMouseLeave={() => setActiveDropdown(null)}
                                    >
                                        <button className={clsx(
                                            "px-3 py-2 rounded-md text-sm font-medium flex items-center transition-colors",
                                            active ? "bg-slate-800 text-blue-400" : "text-slate-300 hover:bg-slate-800 hover:text-white"
                                        )}>
                                            <group.icon className="w-4 h-4 mr-2 opacity-70" />
                                            {group.title}
                                            <ChevronDown className="w-3 h-3 ml-1 opacity-50 group-hover:opacity-100 transition-opacity" />
                                        </button>

                                        {/* Dropdown Menu */}
                                        <div className={clsx(
                                            "absolute left-0 mt-0 w-56 rounded-md shadow-lg bg-slate-800 ring-1 ring-black ring-opacity-5 focus:outline-none transition-all duration-200 origin-top-left z-50",
                                            activeDropdown === group.title ? "opacity-100 scale-100 visible" : "opacity-0 scale-95 invisible"
                                        )}>
                                            <div className="py-1">
                                                {group.items.map(item => {
                                                    const allowed = hasPermission(item.permission) ||
                                                        (item.permission === 'all' && user?.role === 'admin') ||
                                                        (item.permission === 'manage_master_products' && (user?.role === 'admin' || user?.role === 'bodega'));

                                                    if (!allowed) return null;

                                                    return (
                                                        <Link
                                                            key={item.name}
                                                            to={item.href}
                                                            className={clsx(
                                                                "block px-4 py-2 text-sm hover:bg-slate-700 transition-colors flex items-center",
                                                                location.pathname === item.href ? "text-blue-400 bg-slate-700/50" : "text-slate-300"
                                                            )}
                                                        >
                                                            <item.icon className="w-4 h-4 mr-3 opacity-70" />
                                                            {item.name}
                                                        </Link>
                                                    )
                                                })}
                                            </div>
                                        </div>
                                    </div>
                                )
                            })}
                        </div>
                    </div>

                    {/* User Profile & Logout */}
                    <div className="hidden md:block">
                        <div className="ml-4 flex items-center md:ml-6">
                            <div className="flex items-center gap-3">
                                <div className="text-right hidden lg:block">
                                    <div className="text-sm font-medium text-white">{user?.name}</div>
                                    <div className="text-xs text-slate-400 capitalize">{user?.role}</div>
                                </div>
                                <div className="h-8 w-8 rounded-full bg-gradient-to-tr from-blue-600 to-indigo-600 flex items-center justify-center text-white font-bold text-xs ring-2 ring-slate-700">
                                    {user?.name.charAt(0).toUpperCase()}
                                </div>
                                <button
                                    onClick={logout}
                                    className="ml-2 p-1 rounded-full text-slate-400 hover:text-red-400 focus:outline-none"
                                    title="Cerrar Sesión"
                                >
                                    <LogOut className="h-5 w-5" />
                                </button>
                            </div>
                        </div>
                    </div>

                    {/* Mobile menu button */}
                    <div className="-mr-2 flex md:hidden">
                        <button
                            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                            className="bg-slate-800 inline-flex items-center justify-center p-2 rounded-md text-slate-400 hover:text-white hover:bg-slate-700 focus:outline-none"
                        >
                            {mobileMenuOpen ? <X className="block h-6 w-6" /> : <Menu className="block h-6 w-6" />}
                        </button>
                    </div>
                </div>
            </div>

            {/* Mobile Menu */}
            {mobileMenuOpen && (
                <div className="md:hidden bg-slate-900 border-t border-slate-800">
                    <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3">
                        {navigationGroups.map(group => (
                            <div key={group.title} className="mb-4">
                                <div className="px-3 text-xs font-bold text-slate-500 uppercase tracking-widest mb-2">{group.title}</div>
                                {group.items.map(item => (
                                    <Link
                                        key={item.href}
                                        to={item.href}
                                        onClick={() => setMobileMenuOpen(false)}
                                        className={clsx(
                                            "block px-3 py-2 rounded-md text-base font-medium flex items-center",
                                            location.pathname === item.href ? "bg-slate-800 text-emerald-400" : "text-slate-300 hover:bg-slate-700 hover:text-white"
                                        )}
                                    >
                                        <item.icon className="w-5 h-5 mr-3" />
                                        {item.name}
                                    </Link>
                                ))}
                            </div>
                        ))}
                        <div className="border-t border-slate-800 pt-4 pb-2">
                            <button onClick={logout} className="flex items-center w-full px-5 py-2 text-base font-medium text-red-400 hover:bg-slate-800">
                                <LogOut className="w-5 h-5 mr-3" />
                                Cerrar Sesión
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </nav>
    );
}
