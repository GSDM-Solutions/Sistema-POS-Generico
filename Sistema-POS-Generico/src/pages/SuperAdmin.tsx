import React, { useEffect, useState } from 'react';
import { Plus, Edit, Building2, Users, Shield } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Card } from '../components/ui/Card';
import { Modal } from '../components/ui/Modal';
import toast from 'react-hot-toast';

interface Empresa {
    id: string;
    nombre_comercial: string;
    razon_social: string;
    rut: string;
    plan: string;
    activo: boolean;
    created_at: string;
}

interface Usuario {
    id: string;
    email: string;
    name: string;
    role: string;
    empresa_id: string;
    empresas?: { nombre_comercial: string };
}

export function SuperAdmin() {
    const { user } = useAuth();
    const [activeTab, setActiveTab] = useState<'empresas' | 'usuarios'>('empresas');

    if (user?.role !== 'superadmin') {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <Shield className="w-16 h-16 text-red-500 mx-auto mb-4" />
                    <h2 className="text-2xl font-bold text-gray-900">Acceso Denegado</h2>
                    <p className="text-gray-600 mt-2">Solo Super Administradores pueden acceder a esta sección.</p>
                </div>
            </div>
        );
    }

    return (
        <div>
            <div className="flex justify-between items-center mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-gray-900">Super Admin</h1>
                    <p className="text-gray-600 mt-2">Gestión de empresas y usuarios del sistema</p>
                </div>
            </div>

            <div className="mb-6 border-b border-gray-200">
                <nav className="-mb-px flex space-x-6">
                    <button
                        onClick={() => setActiveTab('empresas')}
                        className={`py-3 px-1 border-b-2 font-medium text-sm ${activeTab === 'empresas'
                            ? 'border-blue-500 text-blue-600'
                            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                            }`}
                    >
                        <Building2 className="inline-block w-5 h-5 mr-2" />
                        Empresas
                    </button>
                    <button
                        onClick={() => setActiveTab('usuarios')}
                        className={`py-3 px-1 border-b-2 font-medium text-sm ${activeTab === 'usuarios'
                            ? 'border-blue-500 text-blue-600'
                            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                            }`}
                    >
                        <Users className="inline-block w-5 h-5 mr-2" />
                        Usuarios
                    </button>
                </nav>
            </div>

            {activeTab === 'empresas' ? <EmpresasView /> : <UsuariosView />}
        </div>
    );
}

function EmpresasView() {
    const [empresas, setEmpresas] = useState<Empresa[]>([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [selectedEmpresa, setSelectedEmpresa] = useState<Empresa | null>(null);
    const [formData, setFormData] = useState({
        nombre_comercial: '',
        razon_social: '',
        rut: '',
        plan: 'basico',
        activo: true,
    });

    useEffect(() => {
        fetchEmpresas();
    }, []);

    const fetchEmpresas = async () => {
        setLoading(true);
        const { data, error } = await supabase
            .from('empresas')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            toast.error('Error al cargar empresas');
        } else {
            setEmpresas(data || []);
        }
        setLoading(false);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);

        try {
            if (selectedEmpresa) {
                const { error } = await supabase
                    .from('empresas')
                    .update(formData)
                    .eq('id', selectedEmpresa.id);
                if (error) throw error;
                toast.success('Empresa actualizada');
            } else {
                const { error } = await supabase.from('empresas').insert([formData]);
                if (error) throw error;
                toast.success('Empresa creada');
            }
            setShowModal(false);
            fetchEmpresas();
        } catch (error: unknown) {
          toast.error(error instanceof Error ? error.message : 'Error al crear empresa');
        } finally {
            setLoading(false);
        }
    };

    const openModal = (empresa?: Empresa) => {
        if (empresa) {
            setSelectedEmpresa(empresa);
            setFormData({
                nombre_comercial: empresa.nombre_comercial,
                razon_social: empresa.razon_social,
                rut: empresa.rut,
                plan: empresa.plan,
                activo: empresa.activo,
            });
        } else {
            setSelectedEmpresa(null);
            setFormData({
                nombre_comercial: '',
                razon_social: '',
                rut: '',
                plan: 'basico',
                activo: true,
            });
        }
        setShowModal(true);
    };

    return (
        <div>
            <div className="flex justify-end mb-4">
                <Button onClick={() => openModal()}>
                    <Plus className="w-4 h-4 mr-2" />
                    Nueva Empresa
                </Button>
            </div>

            <Card>
                <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                        <thead className="bg-gray-50">
                            <tr>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Empresa</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">RUT</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Plan</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Acciones</th>
                            </tr>
                        </thead>
                        <tbody className="bg-white divide-y divide-gray-200">
                            {empresas.map((empresa) => (
                                <tr key={empresa.id}>
                                    <td className="px-6 py-4">
                                        <div className="text-sm font-medium text-gray-900">{empresa.nombre_comercial}</div>
                                        <div className="text-sm text-gray-500">{empresa.razon_social}</div>
                                    </td>
                                    <td className="px-6 py-4 text-sm text-gray-900">{empresa.rut}</td>
                                    <td className="px-6 py-4 text-sm text-gray-900 capitalize">{empresa.plan}</td>
                                    <td className="px-6 py-4">
                                        <span
                                            className={`px-2 py-1 text-xs font-semibold rounded-full ${empresa.activo ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                                                }`}
                                        >
                                            {empresa.activo ? 'Activa' : 'Inactiva'}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4 text-sm font-medium">
                                        <button onClick={() => openModal(empresa)} className="text-blue-600 hover:text-blue-900 mr-3">
                                            <Edit className="w-4 h-4" />
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </Card>

            <Modal isOpen={showModal} onClose={() => setShowModal(false)} title={selectedEmpresa ? 'Editar Empresa' : 'Nueva Empresa'}>
                <form onSubmit={handleSubmit} className="space-y-4">
                    <Input
                        label="Nombre Comercial"
                        value={formData.nombre_comercial}
                        onChange={(e) => setFormData({ ...formData, nombre_comercial: e.target.value })}
                        required
                    />
                    <Input
                        label="Razón Social"
                        value={formData.razon_social}
                        onChange={(e) => setFormData({ ...formData, razon_social: e.target.value })}
                        required
                    />
                    <Input
                        label="RUT"
                        value={formData.rut}
                        onChange={(e) => setFormData({ ...formData, rut: e.target.value })}
                        required
                    />
                    <Select
                        label="Plan"
                        value={formData.plan}
                        onChange={(e) => setFormData({ ...formData, plan: e.target.value })}
                        options={[
                            { value: 'basico', label: 'Básico' },
                            { value: 'premium', label: 'Premium' },
                            { value: 'enterprise', label: 'Enterprise' },
                        ]}
                    />
                    <div className="flex items-center">
                        <input
                            type="checkbox"
                            checked={formData.activo}
                            onChange={(e) => setFormData({ ...formData, activo: e.target.checked })}
                            className="h-4 w-4 text-blue-600 rounded"
                        />
                        <label className="ml-2 text-sm text-gray-700">Empresa Activa</label>
                    </div>
                    <div className="flex justify-end space-x-3 pt-4">
                        <Button type="button" variant="secondary" onClick={() => setShowModal(false)}>
                            Cancelar
                        </Button>
                        <Button type="submit" isLoading={loading}>
                            {selectedEmpresa ? 'Actualizar' : 'Crear'}
                        </Button>
                    </div>
                </form>
            </Modal>
        </div>
    );
}

function UsuariosView() {
    const [usuarios, setUsuarios] = useState<Usuario[]>([]);
    const [empresas, setEmpresas] = useState<Empresa[]>([]);
    const [loading, setLoading] = useState(false);
    const [showModal, setShowModal] = useState(false);
    const [selectedUsuario, setSelectedUsuario] = useState<Usuario | null>(null);
    const [formData, setFormData] = useState({
        email: '',
        name: '',
        role: 'empleado',
        empresa_id: '',
        password: '',
    });

    useEffect(() => {
        fetchUsuarios();
        fetchEmpresas();
    }, []);

    const fetchUsuarios = async () => {
        const { data, error } = await supabase
            .from('users')
            .select('*, empresas(nombre_comercial)')
            .order('created_at', { ascending: false });

        if (error) {
            toast.error('Error al cargar usuarios');
        } else {
            setUsuarios(data || []);
        }
    };

    const fetchEmpresas = async () => {
        const { data } = await supabase.from('empresas').select('*').eq('activo', true);
        setEmpresas(data || []);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);

        try {
            if (selectedUsuario) {
                // Actualizar usuario existente
                const { error } = await supabase
                    .from('users')
                    .update({
                        name: formData.name,
                        role: formData.role,
                        empresa_id: formData.empresa_id,
                    })
                    .eq('id', selectedUsuario.id);
                if (error) throw error;
                toast.success('Usuario actualizado');
                setShowModal(false);
                fetchUsuarios();
            } else {
                // Llamar a Edge Function para crear usuario
                const { data: { session } } = await supabase.auth.getSession();

                const response = await fetch(
                    `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/swift-service`,
                    {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${session?.access_token}`,
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            email: formData.email,
                            password: formData.password,
                            name: formData.name,
                            role: formData.role,
                            empresa_id: formData.empresa_id,
                        }),
                    }
                );

                const result = await response.json();

                if (!result.success) {
                    throw new Error(result.error || 'Error al crear usuario');
                }

                toast.success('Usuario creado exitosamente');
                setShowModal(false);
                fetchUsuarios();
            }
        } catch (error: unknown) {
            toast.error(error instanceof Error ? error.message || 'Error al procesar la solicitud' : 'Error al procesar la solicitud');
        } finally {
            setLoading(false);
        }
    };

    const openModal = (usuario?: Usuario) => {
        if (usuario) {
            setSelectedUsuario(usuario);
            setFormData({
                email: usuario.email,
                name: usuario.name,
                role: usuario.role,
                empresa_id: usuario.empresa_id,
                password: '',
            });
        } else {
            setSelectedUsuario(null);
            setFormData({
                email: '',
                name: '',
                role: 'empleado',
                empresa_id: '',
                password: '',
            });
        }
        setShowModal(true);
    };

    return (
        <div>
            <div className="flex justify-end mb-4">
                <Button onClick={() => openModal()}>
                    <Plus className="w-4 h-4 mr-2" />
                    Nuevo Usuario
                </Button>
            </div>

            <Card>
                <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                        <thead className="bg-gray-50">
                            <tr>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Usuario</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Empresa</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Rol</th>
                                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Acciones</th>
                            </tr>
                        </thead>
                        <tbody className="bg-white divide-y divide-gray-200">
                            {usuarios.map((usuario) => (
                                <tr key={usuario.id}>
                                    <td className="px-6 py-4">
                                        <div className="text-sm font-medium text-gray-900">{usuario.name}</div>
                                        <div className="text-sm text-gray-500">{usuario.email}</div>
                                    </td>
                                    <td className="px-6 py-4 text-sm text-gray-900">{usuario.empresas?.nombre_comercial}</td>
                                    <td className="px-6 py-4">
                                        <span className="px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800 capitalize">
                                            {usuario.role}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4 text-sm font-medium">
                                        <button onClick={() => openModal(usuario)} className="text-blue-600 hover:text-blue-900">
                                            <Edit className="w-4 h-4" />
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </Card>

            <Modal isOpen={showModal} onClose={() => setShowModal(false)} title={selectedUsuario ? 'Editar Usuario' : 'Nuevo Usuario'}>
                <form onSubmit={handleSubmit} className="space-y-4">
                    <Input
                        label="Email"
                        type="email"
                        value={formData.email}
                        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                        required
                        disabled={!!selectedUsuario}
                    />
                    <Input
                        label="Nombre"
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        required
                    />
                    {!selectedUsuario && (
                        <Input
                            label="Contraseña"
                            type="password"
                            value={formData.password}
                            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                            required
                            placeholder="Mínimo 6 caracteres"
                        />
                    )}
                    <Select
                        label="Empresa"
                        value={formData.empresa_id}
                        onChange={(e) => setFormData({ ...formData, empresa_id: e.target.value })}
                        options={empresas.map((e) => ({ value: e.id, label: e.nombre_comercial }))}
                        required
                    />
                    <Select
                        label="Rol"
                        value={formData.role}
                        onChange={(e) => setFormData({ ...formData, role: e.target.value })}
                        options={[
                            { value: 'empleado', label: 'Empleado (Cajero/Vendedor)' },
                            { value: 'supervisor', label: 'Supervisor (Encargado)' },
                            { value: 'admin', label: 'Administrador (Gerente)' },
                            { value: 'superadmin', label: 'Super Admin' },
                        ]}
                    />
                    <div className="flex justify-end space-x-3 pt-4">
                        <Button type="button" variant="secondary" onClick={() => setShowModal(false)}>
                            Cancelar
                        </Button>
                        <Button type="submit" isLoading={loading}>
                            {selectedUsuario ? 'Actualizar' : 'Crear'}
                        </Button>
                    </div>
                </form>
            </Modal>
        </div>
    );
}
