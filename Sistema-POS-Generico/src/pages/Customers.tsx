
import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { toast } from 'react-hot-toast';
import {
    Search, Plus, FileText,
    DollarSign, Phone, MapPin, X, Pencil, MessageSquare
} from 'lucide-react';


interface Customer {
    id: string;
    rut: string;
    nombre: string;
    direccion: string | null;
    telefono: string | null;
    cupo_credito: number;
    saldo_actual: number;
    activo: boolean;
    giro?: string;
    es_empresa?: boolean;
}

interface Movement {
    id: string;
    fecha: string;
    tipo: 'COMPRA' | 'ABONO' | 'AJUSTE';
    monto: number;
    saldo_posterior: number;
    descripcion: string | null;
}

export function Customers() {
    const { user } = useAuth();
    const [customers, setCustomers] = useState<Customer[]>([]);
    const [searchTerm, setSearchTerm] = useState('');

    // Modals
    const [isAddOpen, setIsAddOpen] = useState(false);
    const [editingId, setEditingId] = useState<string | null>(null);
    const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null); // For history/payments

    const [newCustomer, setNewCustomer] = useState({
        rut: '', nombre: '', direccion: '', telefono: '', cupo_credito: 70000,
        giro: '',
        es_empresa: false
    });

    const [paymentAmount, setPaymentAmount] = useState('');
    const [movements, setMovements] = useState<Movement[]>([]);

    // Filtro de Tabs Principal (Listado)
    const [activeTab, setActiveTab] = useState<'PERSONA' | 'EMPRESA'>('PERSONA');

    useEffect(() => {
        fetchCustomers();
    }, []);

    const fetchCustomers = async () => {
        try {
            const { data, error } = await supabase
                .from('clientes')
                .select('*')
                .order('nombre');
            if (error) throw error;
            setCustomers(data || []);
        } catch {
            toast.error('Error al procesar cliente');
        }
    };

    const handleAddCustomer = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            if (editingId) {
                // UPDATE
                const { error } = await supabase.from('clientes')
                    .update({
                        rut: newCustomer.rut,
                        nombre: newCustomer.nombre,
                        direccion: newCustomer.direccion,
                        telefono: newCustomer.telefono,
                        cupo_credito: newCustomer.cupo_credito,
                        giro: newCustomer.giro,
                        es_empresa: newCustomer.es_empresa
                    })
                    .eq('id', editingId);

                if (error) throw error;
                toast.success('Cliente actualizado correctamente');
            } else {
                // CREATE
                const { error } = await supabase.from('clientes').insert([{
                    ...newCustomer,
                    empresa_id: user?.empresa_id,
                    saldo_actual: 0
                }]);
                if (error) throw error;
                toast.success('Cliente creado exitosamente');
            }

            setIsAddOpen(false);
            setEditingId(null);
            fetchCustomers();
            // Reset form
            setNewCustomer({
                rut: '', nombre: '', direccion: '', telefono: '', cupo_credito: 70000,
                giro: '',
                es_empresa: false
            });
        } catch {
            toast.error('Error al procesar cliente');
        }
    };

    const fetchMovements = async (clienteId: string) => {
        const { data } = await supabase
            .from('movimientos_cuenta_corriente')
            .select('*')
            .eq('cliente_id', clienteId)
            .order('fecha', { ascending: false });
        setMovements(data || []);
    };

    const handleOpenDetail = (client: Customer) => {
        setSelectedCustomer(client);
        fetchMovements(client.id);
    };

    const processPayment = async () => {
        if (!selectedCustomer || !paymentAmount) return;
        const amount = parseFloat(paymentAmount);
        if (isNaN(amount) || amount <= 0) {
            toast.error('Monto inválido');
            return;
        }

        try {
            const newBalance = selectedCustomer.saldo_actual - amount;

            const { error: moveError } = await supabase.from('movimientos_cuenta_corriente').insert({
                cliente_id: selectedCustomer.id,
                tipo: 'ABONO',
                monto: -amount, // Negative to reduce debt
                saldo_posterior: newBalance,
                descripcion: 'Abono en Caja',
                usuario_id: user?.id,
                empresa_id: user?.empresa_id
            });
            if (moveError) throw moveError;

            // 2. Update Customer Balance
            const { error: updateError } = await supabase
                .from('clientes')
                .update({ saldo_actual: newBalance, actualizado_en: new Date().toISOString() })
                .eq('id', selectedCustomer.id);

            if (updateError) throw updateError;

            toast.success('Abono registrado');
            setPaymentAmount('');

            // Refresh
            const { data } = await supabase.from('clientes').select('*').eq('id', selectedCustomer.id).single();
            if (data) {
                setSelectedCustomer(data);
                setCustomers(prev => prev.map(c => c.id === data.id ? data : c));
            }
            fetchMovements(selectedCustomer.id);

        } catch {
            toast.error('Error al procesar cliente');
        }
    };

    const sendWhatsAppReminder = (customer: Customer) => {
        if (!customer.telefono) {
            toast.error('El cliente no tiene teléfono registrado');
            return;
        }
        const cleanPhone = customer.telefono.replace(/\D/g, '');
        // Prefix with 56 if not present (Chile context)
        const countryCode = cleanPhone.length === 9 ? '56' : '';
        const finalPhone = countryCode + cleanPhone;

        const appName = import.meta.env.VITE_APP_NAME || 'nuestro negocio';
        const message = `Hola ${customer.nombre}, te escribimos de ${appName} para recordarte que mantienes un saldo pendiente de $${customer.saldo_actual.toLocaleString()}. Puedes pasar a regularizarlo cuando gustes. ¡Muchas gracias! 🛒`;

        const url = `https://wa.me/${finalPhone}?text=${encodeURIComponent(message)}`;
        window.open(url, '_blank');
    };

    const filteredCustomers = customers
        .filter(c => {
            const matchesSearch = c.nombre.toLowerCase().includes(searchTerm.toLowerCase()) || c.rut.includes(searchTerm);
            const matchesTab = activeTab === 'EMPRESA' ? c.es_empresa : !c.es_empresa;
            return matchesSearch && matchesTab;
        });

    return (
        <div className="p-6 max-w-7xl mx-auto space-y-6">
            {/* Header */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <h1 className="text-3xl font-black text-gray-900 tracking-tight">Clientes y Crédito</h1>
                    <p className="text-gray-500 mt-1">Administra los cupos de fiado y cuentas corrientes</p>
                </div>
                <button
                    onClick={() => setIsAddOpen(true)}
                    className="bg-blue-600 hover:bg-blue-700 text-white px-5 py-3 rounded-xl font-bold shadow-lg shadow-blue-600/20 flex items-center gap-2 transition-all active:scale-95"
                >
                    <Plus size={20} /> Nuevo Cliente
                </button>
            </div>

            {/* Search Bar & Tabs */}
            <div className="flex flex-col md:flex-row gap-4 items-center">
                {/* Tabs */}
                <div className="bg-gray-100 p-1 rounded-xl flex gap-1 w-full md:w-auto">
                    <button
                        onClick={() => setActiveTab('PERSONA')}
                        className={`flex-1 md:flex-none px-6 py-2.5 rounded-lg text-sm font-bold transition-all ${activeTab === 'PERSONA'
                            ? 'bg-white text-green-700 shadow-sm'
                            : 'text-gray-500 hover:text-gray-700'}`}
                    >
                        Personas (Fiado)
                    </button>
                    <button
                        onClick={() => setActiveTab('EMPRESA')}
                        className={`flex-1 md:flex-none px-6 py-2.5 rounded-lg text-sm font-bold transition-all ${activeTab === 'EMPRESA'
                            ? 'bg-white text-blue-700 shadow-sm'
                            : 'text-gray-500 hover:text-gray-700'}`}
                    >
                        Empresas (Factura)
                    </button>
                </div>

                {/* Search */}
                <div className="relative flex-1 w-full">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input
                        type="text"
                        placeholder={activeTab === 'PERSONA' ? "Buscar Persona por nombre o RUT..." : "Buscar Empresa por Razón Social o RUT..."}
                        className="w-full pl-11 pr-4 py-3 rounded-xl bg-white border border-gray-100 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 shadow-sm outline-none transition-all"
                        value={searchTerm}
                        onChange={e => setSearchTerm(e.target.value)}
                    />
                </div>
            </div>

            {/* Customers Grid (TABLE VIEW) */}
            <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse">
                        <thead>
                            <tr className="bg-gray-50/50 border-b border-gray-100 text-xs uppercase font-bold text-gray-400 tracking-wider">
                                <th className="p-5">Cliente</th>
                                <th className="p-5 hidden md:table-cell">Contacto</th>
                                <th className="p-5 text-center">{activeTab === 'PERSONA' ? 'Estado Deuda' : 'Datos Empresa'}</th>
                                <th className="p-5 text-right">Acciones</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-50">
                            {filteredCustomers.map(customer => (
                                <tr key={customer.id} className="hover:bg-blue-50/30 transition-colors group">
                                    <td className="p-5">
                                        <div className="flex items-center gap-4">
                                            <div className="w-10 h-10 rounded-full bg-gray-100 text-gray-600 flex items-center justify-center font-bold text-lg shrink-0 group-hover:bg-blue-100 group-hover:text-blue-600 transition-colors">
                                                {customer.nombre.charAt(0)}
                                            </div>
                                            <div>
                                                <div className="font-bold text-gray-900">{customer.nombre}</div>
                                                <div className="text-xs text-gray-400 font-mono">{customer.rut}</div>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="p-5 hidden md:table-cell">
                                        <div className="space-y-1">
                                            {customer.telefono && (
                                                <div className="flex items-center gap-2 text-sm text-gray-500">
                                                    <Phone size={14} className="text-gray-300" /> {customer.telefono}
                                                </div>
                                            )}
                                            {customer.direccion && (
                                                <div className="flex items-center gap-2 text-sm text-gray-500">
                                                    <MapPin size={14} className="text-gray-300" /> {customer.direccion}
                                                </div>
                                            )}
                                            {!customer.telefono && !customer.direccion && (
                                                <span className="text-gray-300 text-sm italic">Sin datos de contacto</span>
                                            )}
                                        </div>
                                    </td>
                                    <td className="p-5">
                                        {activeTab === 'PERSONA' ? (
                                            <div className="w-full max-w-[200px] mx-auto">
                                                <div className="flex justify-between text-xs mb-1.5 font-medium">
                                                    <span className={customer.saldo_actual > 0 ? "text-blue-600" : "text-gray-500"}>
                                                        ${customer.saldo_actual.toLocaleString()}
                                                    </span>
                                                    <span className="text-gray-400">
                                                        Cupo ${customer.cupo_credito.toLocaleString()}
                                                    </span>
                                                </div>
                                                <div className="h-2 w-full bg-gray-100 rounded-full overflow-hidden">
                                                    <div
                                                        className={`h-full rounded-full transition-all ${customer.saldo_actual > customer.cupo_credito * 0.9 ? 'bg-red-500' :
                                                            customer.saldo_actual > customer.cupo_credito * 0.5 ? 'bg-orange-500' :
                                                                customer.saldo_actual > 0 ? 'bg-blue-500' : 'bg-gray-300'
                                                            }`}
                                                        style={{ width: `${Math.min((customer.saldo_actual / customer.cupo_credito) * 100, 100)}%` }}
                                                    />
                                                </div>
                                                <div className="text-center mt-1">
                                                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${customer.saldo_actual > 0 ? 'bg-orange-50 text-orange-600' : 'bg-green-50 text-green-600'}`}>
                                                        {customer.saldo_actual > 0 ? 'CON DEUDA' : 'AL DÍA'}
                                                    </span>
                                                </div>
                                            </div>
                                        ) : (
                                            <div className="flex flex-col items-center justify-center text-center">
                                                <span className="bg-blue-100 text-blue-700 text-xs font-bold px-3 py-1 rounded-full uppercase tracking-wide">
                                                    Empresa
                                                </span>
                                                <span className="text-[10px] text-gray-400 mt-1 max-w-[150px] truncate">
                                                    {customer.giro || 'Sin Giro'}
                                                </span>
                                            </div>
                                        )}
                                    </td>
                                    <td className="p-5 text-right">
                                        {activeTab === 'PERSONA' ? (
                                            <button
                                                onClick={() => handleOpenDetail(customer)}
                                                className="px-4 py-2 border border-blue-100 rounded-lg text-sm font-bold text-blue-600 hover:bg-blue-50 hover:border-blue-200 shadow-sm transition-all flex items-center gap-2 ml-auto"
                                            >
                                                <FileText size={16} />
                                                Gestionar
                                            </button>
                                        ) : (
                                            user?.role === 'admin' && (
                                                <button
                                                    onClick={() => {
                                                        setEditingId(customer.id);
                                                        setNewCustomer({
                                                            rut: customer.rut,
                                                            nombre: customer.nombre,
                                                            direccion: customer.direccion || '',
                                                            telefono: customer.telefono || '',
                                                            cupo_credito: customer.cupo_credito,
                                                            giro: customer.giro || '',
                                                            es_empresa: true
                                                        });
                                                        setIsAddOpen(true);
                                                    }}
                                                    className="px-4 py-2 border border-gray-200 rounded-lg text-sm font-bold text-gray-500 hover:bg-white hover:border-blue-500 hover:text-blue-600 shadow-sm transition-all flex items-center gap-2 ml-auto"
                                                    title="Editar Datos Empresa"
                                                >
                                                    <Pencil size={16} />
                                                    Editar
                                                </button>
                                            )
                                        )}
                                    </td>
                                </tr>
                            ))}
                            {filteredCustomers.length === 0 && (
                                <tr>
                                    <td colSpan={4} className="p-12 text-center text-gray-400">
                                        No se encontraron clientes
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Add Customer Modal */}
            {isAddOpen && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
                    <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-200">
                        {/* Modal Header & Tabs */}
                        <div className="bg-gray-50 border-b border-gray-100">
                            <div className="flex justify-between items-center p-4 pb-0">
                                <h3 className="text-xl font-bold text-gray-800">{editingId ? 'Editar Cliente' : 'Nuevo Cliente'}</h3>
                                <button onClick={() => setIsAddOpen(false)} className="p-2 hover:bg-gray-200 rounded-full text-gray-500 transition-colors">
                                    <X size={20} />
                                </button>
                            </div>

                            {!editingId && (
                                <div className="flex px-4 mt-4 space-x-4">
                                    <button
                                        onClick={() => setNewCustomer(prev => ({ ...prev, es_empresa: false }))}
                                        className={`flex-1 pb-3 text-sm font-bold border-b-2 transition-colors ${!newCustomer.es_empresa
                                            ? 'border-blue-600 text-blue-600'
                                            : 'border-transparent text-gray-400 hover:text-gray-600'}`}
                                        type="button"
                                    >
                                        Persona (Fiado)
                                    </button>
                                    <button
                                        onClick={() => setNewCustomer(prev => ({ ...prev, es_empresa: true, cupo_credito: 0 }))}
                                        className={`flex-1 pb-3 text-sm font-bold border-b-2 transition-colors ${newCustomer.es_empresa
                                            ? 'border-blue-600 text-blue-600'
                                            : 'border-transparent text-gray-400 hover:text-gray-600'}`}
                                        type="button"
                                    >
                                        Empresa (Factura)
                                    </button>
                                </div>
                            )}
                        </div>

                        <form onSubmit={handleAddCustomer} className="p-6 space-y-4">

                            {/* Form Fields Dynamic */}
                            {newCustomer.es_empresa ? (
                                // EMPRESA FORM
                                <>
                                    <div className="bg-blue-50 p-3 rounded-lg text-xs text-blue-800 border border-blue-100 mb-2">
                                        <p className="font-bold">Datos para Facturación Electrónica</p>
                                        <p>Ingrese la Razón Social y Giro exactos.</p>
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-700 mb-1">RUT Empresa</label>
                                        <input required placeholder="76.123.456-K" className="w-full p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all uppercase"
                                            value={newCustomer.rut} onChange={e => setNewCustomer({ ...newCustomer, rut: e.target.value })} />
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-700 mb-1">Razón Social</label>
                                        <input required className="w-full p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all uppercase"
                                            value={newCustomer.nombre} onChange={e => setNewCustomer({ ...newCustomer, nombre: e.target.value })} />
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-700 mb-1">Giro Comercial</label>
                                        <input required placeholder="Ej: VENTA DE INSUMOS..." className="w-full p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all uppercase"
                                            value={newCustomer.giro} onChange={e => setNewCustomer({ ...newCustomer, giro: e.target.value })} />
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-700 mb-1">Dirección Tributaria</label>
                                        <input required className="w-full p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all"
                                            value={newCustomer.direccion} onChange={e => setNewCustomer({ ...newCustomer, direccion: e.target.value })} />
                                    </div>
                                </>
                            ) : (
                                // PERSONA FORM
                                <>
                                    <div className="bg-green-50 p-3 rounded-lg text-xs text-green-800 border border-green-100 mb-2">
                                        <p className="font-bold">Cliente Habitual / Fiado</p>
                                        <p>Se habilitará una cuenta corriente para este cliente.</p>
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-700 mb-1">RUT (Opcional)</label>
                                        <input placeholder="12.345.678-9" className="w-full p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all"
                                            value={newCustomer.rut} onChange={e => setNewCustomer({ ...newCustomer, rut: e.target.value })} />
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-700 mb-1">Nombre Completo</label>
                                        <input required className="w-full p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all capitalize"
                                            value={newCustomer.nombre} onChange={e => setNewCustomer({ ...newCustomer, nombre: e.target.value })} />
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-700 mb-1">Dirección (Opcional)</label>
                                        <input className="w-full p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all"
                                            value={newCustomer.direccion} onChange={e => setNewCustomer({ ...newCustomer, direccion: e.target.value })} />
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-700 mb-1">Cupo Crédito Inicial</label>
                                        <div className="relative">
                                            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 font-bold">$</span>
                                            <input type="number" required className="w-full pl-8 p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all font-bold text-gray-700"
                                                value={newCustomer.cupo_credito} onChange={e => setNewCustomer({ ...newCustomer, cupo_credito: Number(e.target.value) })} />
                                        </div>
                                    </div>
                                </>
                            )}

                            <div>
                                <label className="block text-sm font-bold text-gray-700 mb-1">Teléfono / Contacto</label>
                                <input className="w-full p-3 rounded-xl border border-gray-200 focus:border-blue-500 outline-none transition-all"
                                    value={newCustomer.telefono} onChange={e => setNewCustomer({ ...newCustomer, telefono: e.target.value })} />
                            </div>

                            <button type="submit" className={`w-full py-4 font-bold rounded-xl shadow-lg mt-4 transition-transform active:scale-95 text-white ${newCustomer.es_empresa ? 'bg-blue-800 hover:bg-blue-900' : 'bg-green-600 hover:bg-green-700'}`}>
                                {newCustomer.es_empresa ? 'Guardar Empresa' : 'Registrar Cliente'}
                            </button>
                        </form>
                    </div>
                </div>
            )}

            {/* Account Detail Modal */}
            {selectedCustomer && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
                    <div className="bg-white rounded-3xl shadow-2xl w-full max-w-2xl overflow-hidden flex flex-col max-h-[90vh] animate-in zoom-in-95 duration-200">
                        <div className="p-6 bg-gray-50 border-b border-gray-200 flex justify-between items-center">
                            <div>
                                <h3 className="text-xl font-bold text-gray-900">{selectedCustomer.nombre}</h3>
                                <p className="text-sm text-gray-500">Historial de Cuenta Corriente</p>
                            </div>
                            <div className="flex gap-2">
                                <button
                                    onClick={() => sendWhatsAppReminder(selectedCustomer)}
                                    className="p-2 bg-green-100 text-green-700 hover:bg-green-200 rounded-full transition-colors"
                                    title="Enviar Recordatorio WhatsApp"
                                >
                                    <MessageSquare size={20} />
                                </button>
                                <button onClick={() => setSelectedCustomer(null)} className="p-2 hover:bg-gray-200 rounded-full text-gray-400 hover:text-gray-600 transition-colors"><X size={24} /></button>
                            </div>

                        </div>

                        <div className="p-6 grid grid-cols-1 sm:grid-cols-2 gap-4 border-b border-gray-100">
                            <div className="bg-gradient-to-br from-blue-50 to-indigo-50 p-4 rounded-xl border border-blue-100 flex flex-col justify-center">
                                <p className="text-blue-600 text-sm font-bold mb-1 uppercase tracking-wider">Deuda Total</p>
                                <p className="text-4xl font-black text-blue-900 tracking-tight">${selectedCustomer.saldo_actual.toLocaleString()}</p>
                            </div>
                            <div className="bg-white border-2 border-dashed border-gray-200 p-4 rounded-xl flex flex-col justify-center">
                                <label className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Registrar Abono Rápido</label>
                                <div className="flex gap-2">
                                    <div className="relative flex-1">
                                        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 font-bold">$</span>
                                        <input
                                            type="number"
                                            placeholder="0"
                                            className="w-full pl-8 p-2 bg-gray-50 rounded-lg outline-none font-bold text-gray-700 border-transparent focus:bg-white focus:ring-2 focus:ring-green-100 transition-all"
                                            value={paymentAmount}
                                            onChange={e => setPaymentAmount(e.target.value)}
                                        />
                                    </div>
                                    <button
                                        onClick={processPayment}
                                        className="bg-green-600 hover:bg-green-700 text-white px-4 rounded-lg font-bold shadow-sm active:scale-95 transition-all"
                                    >
                                        <DollarSign size={20} />
                                    </button>
                                </div>
                            </div>
                        </div>

                        <div className="flex-1 overflow-y-auto bg-white">
                            <table className="w-full text-sm">
                                <thead className="text-left bg-gray-50 text-gray-500 font-bold text-xs uppercase tracking-wider sticky top-0">
                                    <tr>
                                        <th className="px-6 py-3">Fecha</th>
                                        <th className="px-6 py-3">Tipo</th>
                                        <th className="px-6 py-3 text-right">Monto</th>
                                        <th className="px-6 py-3 text-right">Saldo</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-gray-100">
                                    {movements.map(m => (
                                        <tr key={m.id} className="group hover:bg-gray-50 transition-colors">
                                            <td className="px-6 py-4 text-gray-500 font-medium whitespace-nowrap">
                                                {new Date(m.fecha).toLocaleDateString()}
                                                <div className="text-[10px] text-gray-400">{new Date(m.fecha).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
                                            </td>
                                            <td className="px-6 py-4">
                                                <span className={`px-2 py-1 rounded text-[10px] font-black uppercase tracking-wide ${m.tipo === 'COMPRA' ? 'bg-red-50 text-red-600' : 'bg-green-50 text-green-600'
                                                    }`}>
                                                    {m.tipo}
                                                </span>
                                            </td>
                                            <td className={`px-6 py-4 text-right font-bold ${m.tipo === 'COMPRA' ? 'text-gray-900' : 'text-green-600'
                                                }`}>
                                                {m.tipo === 'COMPRA' ? '+' : ''} ${Math.abs(m.monto).toLocaleString()}
                                            </td>
                                            <td className="px-6 py-4 text-right text-gray-500 font-medium">
                                                ${m.saldo_posterior.toLocaleString()}
                                            </td>
                                        </tr>
                                    ))}
                                    {movements.length === 0 && (
                                        <tr>
                                            <td colSpan={4} className="text-center py-12 text-gray-400 italic">Sin movimientos registrados</td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
