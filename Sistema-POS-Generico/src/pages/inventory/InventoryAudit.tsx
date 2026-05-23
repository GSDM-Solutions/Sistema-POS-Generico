import React, { useEffect, useState, useRef } from 'react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { ConfirmModal } from '../../components/ui/ConfirmModal';
import { toast } from 'react-hot-toast';
import { DirectAdjustment } from './DirectAdjustment';
import {
    ClipboardList,
    Plus,
    Scan,
    CheckCircle,
    AlertTriangle,
    ArrowRight,
    Trash2,
    Target,
    Wrench
} from 'lucide-react';

interface InventorySession {
    id: string;
    nombre: string;
    estado: 'OPEN' | 'COUNTING' | 'REVIEW' | 'APPLIED' | 'CANCELLED';
    tipo: 'GENERAL' | 'SELECTIVO' | 'AJUSTE_DIRECTO';
    fecha_inicio: string;
    observaciones?: string;
    motivo_ajuste?: string;
    bodega_id?: string;
}

interface DiscrepancyReport {
    maestro_producto_id: string;
    nombre_producto: string;
    stock_sistema: number;
    stock_fisico: number;
    diferencia: number;
    valor_diferencia: number;
}

type AuditTab = 'GENERAL' | 'SELECTIVO' | 'AJUSTE_DIRECTO';

const TAB_LABELS: Record<AuditTab, string> = {
    'GENERAL': 'Conteo General',
    'SELECTIVO': 'Conteo Selectivo',
    'AJUSTE_DIRECTO': 'Ajuste Directo',
};

const TAB_DESCRIPTIONS: Record<AuditTab, string> = {
    'GENERAL': 'Cuenta todo el inventario. Los productos NO escaneados se ajustaran a cero.',
    'SELECTIVO': 'Solo cuenta los SKUs que escanees. Los productos NO escaneados no se modifican.',
    'AJUSTE_DIRECTO': 'Ajusta stock manualmente por consumo, rotura, caida a piso u otros motivos.',
};

const TAB_ICONS: Record<AuditTab, React.ReactNode> = {
    'GENERAL': <ClipboardList size={18} />,
    'SELECTIVO': <Target size={18} />,
    'AJUSTE_DIRECTO': <Wrench size={18} />,
};

export function InventoryAudit() {
    const [activeTab, setActiveTab] = useState<AuditTab>('GENERAL');
    const [sessions, setSessions] = useState<InventorySession[]>([]);
    const [activeSession, setActiveSession] = useState<InventorySession | null>(null);
    const [showNewSessionModal, setShowNewSessionModal] = useState(false);
    const [newSessionName, setNewSessionName] = useState('');
    const [bodegas, setBodegas] = useState<{ id: string; nombre: string }[]>([]);
    const [selectedBodegaId, setSelectedBodegaId] = useState('');

    const [isCounting, setIsCounting] = useState(false);
    const [scanCode, setScanCode] = useState('');
    const [scanQty, setScanQty] = useState(1);
    const [scanExpiration, setScanExpiration] = useState('');
    const [lastScanned, setLastScanned] = useState<{ nombre: string; cantidad: number; factor: number } | null>(null);
    const scanInputRef = useRef<HTMLInputElement>(null);

    const [report, setReport] = useState<DiscrepancyReport[]>([]);
    const [showReport, setShowReport] = useState(false);
    const [confirmFinish, setConfirmFinish] = useState(false);
    const [confirmApply, setConfirmApply] = useState(false);
    const [deleteTarget, setDeleteTarget] = useState<InventorySession | null>(null);

    const { user } = useAuth();

    useEffect(() => {
        fetchSessions();
        fetchBodegas();
    }, [activeTab]);

    const fetchBodegas = async () => {
        const { data } = await supabase.from('bodegas').select('id, nombre').eq('empresa_id', user?.empresa_id).eq('activo', true);
        if (data && data.length > 0) {
            setBodegas(data);
            setSelectedBodegaId(data[0].id);
        }
    };

    const fetchSessions = async () => {
        const query = supabase
            .from('inventory_sessions')
            .select('*')
            .eq('empresa_id', user?.empresa_id);

        if (activeTab !== 'AJUSTE_DIRECTO') {
            query.in('tipo', ['GENERAL', 'SELECTIVO']);
        } else {
            query.eq('tipo', 'AJUSTE_DIRECTO');
        }

        const { data } = await query.order('fecha_inicio', { ascending: false });
        setSessions(data || []);
    };

    const createSession = async () => {
        if (!newSessionName) return;
        const { error } = await supabase.from('inventory_sessions').insert([{
            nombre: newSessionName,
            creado_por: user?.id,
            empresa_id: user?.empresa_id,
            estado: 'OPEN',
            tipo: activeTab,
            bodega_id: selectedBodegaId || null
        }]);

        if (error) toast.error('Error al crear sesion');
        else {
            toast.success('Sesion creada');
            fetchSessions();
            setShowNewSessionModal(false);
        }
    };

    const enterSession = async (session: InventorySession) => {
        setActiveSession(session);
        if (session.estado === 'OPEN' || session.estado === 'COUNTING') {
            setIsCounting(true);
            if (session.estado === 'OPEN') {
                await supabase.from('inventory_sessions').update({ estado: 'COUNTING' }).eq('id', session.id);
            }
        } else {
            setIsCounting(false);
            loadReport(session.id);
        }
    };

    const handleScan = async () => {
        if (!activeSession || !scanCode) return;

        const { data: products, error } = await supabase.rpc('search_products_pos', { p_query: scanCode });

        if (error || !products || products.length === 0) {
            toast.error('Producto no encontrado');
            setScanCode('');
            return;
        }

        const match = products[0];

        const { error: insertError } = await supabase.from('inventory_counts').insert([{
            session_id: activeSession.id,
            maestro_producto_id: match.maestro_id,
            codigo_escaneado: scanCode,
            cantidad_escaneada: scanQty,
            factor_conversion: match.factor_conversion,
            usuario_id: user?.id,
            fecha_vencimiento: scanExpiration || null
        }]);

        if (insertError) {
            toast.error('Error al registrar conteo');
        } else {
            toast.success(`Leido: ${match.nombre_producto} (x${scanQty * match.factor_conversion} un.)`);
            setLastScanned({
                nombre: match.nombre_producto,
                cantidad: scanQty,
                factor: match.factor_conversion
            });
            setScanCode('');
            setScanQty(1);
            setScanExpiration('');
            scanInputRef.current?.focus();
            loadReport(activeSession.id);
        }
    };

    const loadReport = async (sessionId: string) => {
        let reportData;

        const { data: frozenData } = await supabase
            .from('inventory_session_results')
            .select(`
                maestro_producto_id,
                nombre_producto,
                stock_sistema: stock_sistema_snapshot,
                stock_fisico: stock_fisico_final,
                diferencia,
                valor_diferencia: valor_ajuste
            `)
            .eq('session_id', sessionId);

        if (frozenData && frozenData.length > 0) {
            reportData = frozenData;
        } else {
            try {
                const { data: liveData, error: rpcError } = await supabase.rpc('analizar_diferencias_inventario', { p_session_id: sessionId });
                if (rpcError) {
                    console.error('RPC Error:', JSON.stringify(rpcError));
                }
                reportData = liveData?.map((r: Record<string, unknown>) => ({
                    ...r,
                    valor_diferencia: r.valor_ajuste ?? r.valor_diferencia ?? 0
                }));
            } catch (e: any) {
                console.error('RPC Exception:', e?.message || e);
                reportData = [];
            }
        }

        if (reportData) {
            setReport(reportData);
            if (!isCounting) {
                setShowReport(true);
            }
        }
    };

    const finishCount = async () => {
        setConfirmFinish(true);
    };

    const doFinishCount = async () => {
        setConfirmFinish(false);
        if (!activeSession) return;

        await supabase.from('inventory_sessions').update({ estado: 'REVIEW' }).eq('id', activeSession.id);
        setIsCounting(false);
        loadReport(activeSession.id);
        fetchSessions();
    };

    const applyAdjustments = () => {
        setConfirmApply(true);
    };

    const doApplyAdjustments = async () => {
        setConfirmApply(false);
        if (!activeSession || !user) return;

        const { error } = await supabase.rpc('aplicar_ajuste_inventario', {
            p_session_id: activeSession.id,
            p_usuario_id: user.id
        });

        if (error) {
            const msg = (error as { message?: string }).message || 'Error desconocido';
            toast.error('Error al aplicar ajustes: ' + msg);
        } else {
            toast.success('Inventario ajustado correctamente.');
            setShowReport(false);
            setActiveSession(null);
            fetchSessions();
        }
    };

    const deleteSession = async () => {
        if (!deleteTarget) return;
        const { error } = await supabase
            .from('inventory_sessions')
            .delete()
            .eq('id', deleteTarget.id);

        if (error) {
            toast.error('Error al eliminar sesion: ' + ((error as { message?: string }).message || ''));
        } else {
            toast.success('Sesion eliminada');
            fetchSessions();
        }
        setDeleteTarget(null);
    };

    useEffect(() => {
        if (activeSession && isCounting) {
            loadReport(activeSession.id);
        }
    }, [isCounting, activeSession]);

    // =========================================================
    // RENDER: AJUSTE DIRECTO
    // =========================================================
    if (activeTab === 'AJUSTE_DIRECTO') {
        return (
            <div className="p-6">
                <div className="mb-6">
                    <div className="flex gap-2 border-b border-gray-200 pb-0 mb-0">
                        {(['GENERAL', 'SELECTIVO', 'AJUSTE_DIRECTO'] as AuditTab[]).map(tab => (
                            <button
                                key={tab}
                                onClick={() => { setActiveTab(tab); setActiveSession(null); setIsCounting(false); setShowReport(false); }}
                                className={`flex items-center gap-2 px-5 py-3 text-sm font-medium rounded-t-lg transition-colors border border-b-0 ${
                                    activeTab === tab
                                        ? 'bg-white text-blue-700 border-gray-200'
                                        : 'bg-gray-50 text-gray-500 border-transparent hover:text-gray-700 hover:bg-gray-100'
                                }`}
                            >
                                {TAB_ICONS[tab]} {TAB_LABELS[tab]}
                            </button>
                        ))}
                    </div>
                    <div className="bg-blue-50 border border-blue-100 rounded-b-lg rounded-tr-lg px-4 py-3">
                        <p className="text-sm text-blue-700">{TAB_DESCRIPTIONS[activeTab]}</p>
                    </div>
                </div>
                <DirectAdjustment />
            </div>
        );
    }

    // =========================================================
    // RENDER: COUNTING SCREEN
    // =========================================================
    if (isCounting && activeSession) {
        const isSelectivo = activeSession.tipo === 'SELECTIVO';
        return (
            <div className="max-w-6xl mx-auto">
                <div className="flex justify-between items-center mb-6">
                    <div>
                        <div className="flex items-center gap-2 mb-1">
                            <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                                isSelectivo ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700'
                            }`}>
                                {isSelectivo ? 'SELECTIVO' : 'GENERAL'}
                            </span>
                            <h2 className="text-2xl font-bold text-gray-800">{activeSession.nombre}</h2>
                        </div>
                        <p className="text-gray-500">
                            {isSelectivo
                                ? 'Solo los productos escaneados seran comparados y ajustados.'
                                : 'Todos los productos del inventario seran comparados.'}
                            {activeSession.bodega_id && (
                                <> &middot; <span className="font-medium">{bodegas.find(b => b.id === activeSession.bodega_id)?.nombre || 'Bodega'}</span></>
                            )}
                        </p>
                    </div>
                    <Button variant="secondary" onClick={() => { setIsCounting(false); setActiveSession(null); }}>Salir</Button>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    <div className="lg:col-span-1 space-y-6">
                        <Card className={`p-6 shadow-sm sticky top-6 ${isSelectivo ? 'bg-purple-50 border-2 border-purple-200' : 'bg-slate-50 border-2 border-slate-200'}`}>
                            <form onSubmit={e => e.preventDefault()} className="flex flex-col gap-4">
                                <div>
                                    <label className="block text-sm font-bold text-gray-700 mb-2">Codigo de Barra</label>
                                    <div className="relative">
                                        <Scan className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
                                        <input
                                            ref={scanInputRef}
                                            autoFocus
                                            value={scanCode}
                                            onChange={e => setScanCode(e.target.value)}
                                            onKeyDown={e => {
                                                if (e.key === 'Enter' && scanCode.trim()) {
                                                    e.preventDefault();
                                                    handleScan();
                                                }
                                            }}
                                            className="w-full pl-12 pr-4 py-3 text-lg rounded-xl border-gray-300 focus:ring-4 focus:ring-blue-500/20 focus:border-blue-500 shadow-sm"
                                            placeholder="Escanear..."
                                        />
                                    </div>
                                </div>
                                <div>
                                    <label className="block text-sm font-bold text-gray-700 mb-2">Cantidad (Negativo para restar)</label>
                                    <input
                                        type="number"
                                        value={scanQty}
                                        onChange={e => setScanQty(Number(e.target.value))}
                                        className={`w-full py-3 text-center text-lg rounded-xl border-gray-300 shadow-sm ${scanQty < 0 ? 'text-red-600 bg-red-50 border-red-300' : ''}`}
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-bold text-gray-700 mb-2">Vencimiento (opcional)</label>
                                    <input
                                        type="date"
                                        value={scanExpiration}
                                        onChange={e => setScanExpiration(e.target.value)}
                                        className="w-full py-3 text-center rounded-xl border-gray-300 shadow-sm text-sm"
                                    />
                                </div>
                                <Button type="button" onClick={handleScan} size="lg" className={`w-full py-4 text-lg shadow-md ${scanQty < 0 ? 'bg-red-600 hover:bg-red-700 text-white' : ''}`}>
                                    {scanQty < 0 ? <><AlertTriangle className="mr-2" /> CORREGIR (RESTAR)</> : <><Plus className="mr-2" /> Registrar</>}
                                </Button>
                            </form>

                            {lastScanned && (
                                <div className="mt-6 p-4 bg-green-50 border border-green-200 rounded-xl flex flex-col items-center text-center text-green-800 animate-fade-in shadow-sm">
                                    <CheckCircle size={32} className="mb-2 text-green-600" />
                                    <p className="font-bold text-lg leading-tight">{lastScanned.nombre}</p>
                                    <p className="text-sm mt-1 opacity-80">Agregado: +{lastScanned.cantidad * lastScanned.factor}</p>
                                </div>
                            )}

                            <div className="pt-8 mt-8 border-t border-gray-200">
                                <Button onClick={finishCount} variant="primary" className="w-full bg-slate-800 text-white hover:bg-slate-900 shadow-lg">
                                    Finalizar y Ajustar <ArrowRight className="ml-2" />
                                </Button>
                            </div>
                        </Card>
                    </div>

                    <div className="lg:col-span-2">
                        <Card className="overflow-hidden border border-gray-200 shadow-sm">
                            <div className="bg-gray-50 px-6 py-4 border-b border-gray-200 flex justify-between items-center">
                                <h3 className="font-bold text-gray-700 flex items-center gap-2">
                                    <ClipboardList size={20} /> Progreso del Conteo
                                </h3>
                                <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full font-bold">
                                    {report.filter(r => r.stock_fisico > 0).length} Productos Contados
                                </span>
                            </div>
                            <div className="overflow-x-auto max-h-[600px] overflow-y-auto">
                                <table className="w-full text-left">
                                    <thead className="bg-white text-xs uppercase text-gray-500 sticky top-0 shadow-sm z-10">
                                        <tr>
                                            <th className="p-4 bg-gray-50">Producto</th>
                                            <th className="p-4 bg-gray-50 text-right">Tu Conteo Total</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-gray-100">
                                        {report.filter(r => r.stock_fisico > 0).length === 0 ? (
                                            <tr>
                                                <td colSpan={2} className="p-8 text-center text-gray-400 italic">
                                                    Escanea un producto para comenzar...
                                                </td>
                                            </tr>
                                        ) : (
                                            report.filter(r => r.stock_fisico > 0).map(row => (
                                                <tr key={row.maestro_producto_id} className={`hover:bg-gray-50 transition-colors ${row.maestro_producto_id === lastScanned?.maestro_id ? 'bg-blue-50' : ''}`}>
                                                    <td className="p-4">
                                                        <div className="font-bold text-gray-800">{row.nombre_producto}</div>
                                                    </td>
                                                    <td className="p-4 text-right font-bold text-blue-600 text-lg">
                                                        {row.stock_fisico}
                                                    </td>
                                                </tr>
                                            ))
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        </Card>
                    </div>
                </div>

                <ConfirmModal
                    isOpen={confirmFinish}
                    onClose={() => setConfirmFinish(false)}
                    onConfirm={doFinishCount}
                    title="Finalizar Conteo"
                    message={isSelectivo
                        ? 'Finalizar conteo selectivo? Solo los productos escaneados seran comparados y ajustados. Los demas productos no se modificaran.'
                        : 'Finalizar conteo general? Todos los productos con stock en el sistema seran comparados. Los NO escaneados se ajustaran a cero.'}
                    confirmText="Finalizar"
                />
            </div>
        );
    }

    // =========================================================
    // RENDER: REPORT SCREEN
    // =========================================================
    if (showReport && activeSession) {
        const isSelectivo = activeSession.tipo === 'SELECTIVO';
        return (
            <div className="max-w-6xl mx-auto">
                <Button variant="secondary" onClick={() => { setShowReport(false); setActiveSession(null); }} className="mb-4">Volver</Button>
                <div className="flex items-center gap-3 mb-2">
                    <span className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                        isSelectivo ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700'
                    }`}>
                        {isSelectivo ? 'SELECTIVO' : 'GENERAL'}
                    </span>
                    <h2 className="text-2xl font-bold">
                        {activeSession.estado === 'APPLIED' ? 'Reporte Final de Ajustes' : `Reporte de Discrepancias: ${activeSession.nombre}`}
                    </h2>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
                    <Card className="p-6 bg-white border border-gray-100 flex items-center gap-4">
                        <div className="p-3 bg-blue-50 rounded-full text-blue-600">
                            <ClipboardList size={24} />
                        </div>
                        <div>
                            <p className="text-sm text-gray-500">Total Productos Ajustados</p>
                            <p className="text-2xl font-bold">{report.filter(r => r.diferencia !== 0).length}</p>
                        </div>
                    </Card>

                    <Card className={`p-6 border flex items-center gap-4 ${report.reduce((acc, curr) => acc + curr.valor_diferencia, 0) >= 0 ? 'bg-green-50 border-green-100' : 'bg-red-50 border-red-100'}`}>
                        <div className={`p-3 rounded-full ${report.reduce((acc, curr) => acc + curr.valor_diferencia, 0) >= 0 ? 'bg-green-200 text-green-700' : 'bg-red-200 text-red-700'}`}>
                            <AlertTriangle size={24} />
                        </div>
                        <div>
                            <p className="text-sm text-gray-700 font-medium">Impacto Financiero Total</p>
                            <p className={`text-2xl font-bold ${report.reduce((acc, curr) => acc + curr.valor_diferencia, 0) >= 0 ? 'text-green-700' : 'text-red-700'}`}>
                                {report.reduce((acc, curr) => acc + curr.valor_diferencia, 0) >= 0 ? '+' : ''}
                                ${report.reduce((acc, curr) => acc + curr.valor_diferencia, 0).toLocaleString()}
                            </p>
                        </div>
                    </Card>

                    <Card className="p-6 bg-gray-50 border border-gray-100 flex items-center gap-4">
                        <div className="p-3 bg-gray-200 rounded-full text-gray-600">
                            <CheckCircle size={24} />
                        </div>
                        <div>
                            <p className="text-sm text-gray-500">Estado de Sesion</p>
                            <p className="text-xl font-bold first-letter:capitalize">{activeSession.estado === 'APPLIED' ? 'Cerrada y Aplicada' : 'En Revision'}</p>
                        </div>
                    </Card>
                </div>

                <div className="bg-white rounded-xl shadow border overflow-hidden">
                    <table className="w-full text-left">
                        <thead className="bg-gray-50 text-xs uppercase text-gray-500">
                            <tr>
                                <th className="p-4">Producto</th>
                                <th className="p-4 text-right">Sistema (Teorico)</th>
                                <th className="p-4 text-right">Fisico (Conteo)</th>
                                <th className="p-4 text-right">Ajuste Realizado</th>
                                <th className="p-4 text-right">Valor Ajuste</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                            {report.map(row => (
                                <tr key={row.maestro_producto_id} className={row.diferencia !== 0 ? 'bg-red-50/30' : ''}>
                                    <td className="p-4 font-medium">{row.nombre_producto}</td>
                                    <td className="p-4 text-right text-gray-600">{row.stock_sistema}</td>
                                    <td className="p-4 text-right font-bold">{row.stock_fisico}</td>
                                    <td className={`p-4 text-right font-bold ${row.diferencia < 0 ? 'text-red-500' : (row.diferencia > 0 ? 'text-blue-500' : 'text-gray-400')}`}>
                                        {row.diferencia > 0 ? '+' : ''}{row.diferencia}
                                        {activeSession.estado === 'APPLIED' && <span className="text-xs text-gray-400 ml-1">(Aplicado)</span>}
                                    </td>
                                    <td className="p-4 text-right text-sm">
                                        ${row.valor_diferencia.toLocaleString()}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                <div className="flex justify-end gap-4 mt-6">
                    {activeSession.estado !== 'APPLIED' && (
                        <Button onClick={applyAdjustments} className="bg-emerald-600 hover:bg-emerald-700">
                            <AlertTriangle className="mr-2" size={18} />
                            Ajustar Inventario Automaticamente
                        </Button>
                    )}
                </div>

                <ConfirmModal
                    isOpen={confirmApply}
                    onClose={() => setConfirmApply(false)}
                    onConfirm={doApplyAdjustments}
                    title="Ajustar Inventario"
                    message="Esta accion modificara el stock real del sistema para igualarlo al conteo fisico. Esta accion NO se puede deshacer. Continuar?"
                    confirmText="Ajustar Inventario"
                    variant="danger"
                />
            </div>
        );
    }

    // =========================================================
    // RENDER: MAIN LIST SCREEN
    // =========================================================
    return (
        <div className="p-6">
            {/* Tab Navigation */}
            <div className="mb-6">
                <div className="flex gap-2 border-b border-gray-200">
                    {(['GENERAL', 'SELECTIVO', 'AJUSTE_DIRECTO'] as AuditTab[]).map(tab => (
                        <button
                            key={tab}
                            onClick={() => { setActiveTab(tab); setActiveSession(null); setIsCounting(false); setShowReport(false); }}
                            className={`flex items-center gap-2 px-5 py-3 text-sm font-medium rounded-t-lg transition-colors border border-b-0 ${
                                activeTab === tab
                                    ? 'bg-white text-blue-700 border-gray-200'
                                    : 'bg-gray-50 text-gray-500 border-transparent hover:text-gray-700 hover:bg-gray-100'
                            }`}
                        >
                            {TAB_ICONS[tab]} {TAB_LABELS[tab]}
                        </button>
                    ))}
                </div>
                <div className="bg-blue-50 border border-blue-100 rounded-b-lg rounded-tr-lg px-4 py-3">
                    <p className="text-sm text-blue-700">{TAB_DESCRIPTIONS[activeTab]}</p>
                </div>
            </div>

            {activeTab !== 'AJUSTE_DIRECTO' && (
                <>
                    <div className="flex justify-between items-center mb-8">
                        <div>
                            <h1 className="text-3xl font-bold text-gray-900">{TAB_LABELS[activeTab]}</h1>
                            <p className="text-gray-600 mt-2">Gestione conteos fisicos y cuadratura de stock.</p>
                        </div>
                        <Button onClick={() => setShowNewSessionModal(true)}>
                            <Plus className="mr-2" /> Nueva Sesion
                        </Button>
                    </div>

                    <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                        {sessions.filter(s => s.tipo !== 'AJUSTE_DIRECTO').map(session => (
                            <Card key={session.id} className="hover:shadow-lg transition-shadow cursor-pointer relative group" onClick={() => enterSession(session)}>
                                <button
                                    onClick={(e) => { e.stopPropagation(); setDeleteTarget(session); }}
                                    className="absolute top-3 right-3 p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg opacity-0 group-hover:opacity-100 transition-all"
                                    title="Eliminar sesion"
                                >
                                    <Trash2 size={16} />
                                </button>
                                <div className="flex justify-between items-start mb-4">
                                    <div className={`p-3 rounded-lg ${
                                        session.tipo === 'SELECTIVO' ? 'bg-purple-50 text-purple-600' : 'bg-blue-50 text-blue-600'
                                    }`}>
                                        {session.tipo === 'SELECTIVO' ? <Target size={24} /> : <ClipboardList size={24} />}
                                    </div>
                                    <span className={`px-3 py-1 rounded-full text-xs font-bold 
                                        ${session.estado === 'OPEN' ? 'bg-green-100 text-green-700' :
                                            session.estado === 'COUNTING' ? 'bg-yellow-100 text-yellow-700' :
                                                session.estado === 'REVIEW' ? 'bg-purple-100 text-purple-700' :
                                                    'bg-gray-100 text-gray-600'}`}>
                                        {session.estado}
                                    </span>
                                </div>
                                <div className="flex items-center gap-2 mb-1">
                                    <span className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${
                                        session.tipo === 'SELECTIVO' ? 'bg-purple-100 text-purple-600' : 'bg-blue-100 text-blue-600'
                                    }`}>
                                        {session.tipo === 'SELECTIVO' ? 'SELECTIVO' : 'GENERAL'}
                                    </span>
                                    <h3 className="font-bold text-lg">{session.nombre}</h3>
                                </div>
                                <div className="flex items-center gap-3">
                                    <p className="text-sm text-gray-500">Iniciado: {new Date(session.fecha_inicio).toLocaleDateString()}</p>
                                    {session.bodega_id && (
                                        <span className="text-xs text-gray-400 bg-gray-100 px-1.5 py-0.5 rounded">
                                            {bodegas.find(b => b.id === session.bodega_id)?.nombre || 'Bodega'}
                                        </span>
                                    )}
                                </div>
                            </Card>
                        ))}
                        {sessions.filter(s => s.tipo !== 'AJUSTE_DIRECTO').length === 0 && (
                            <div className="col-span-full py-16 text-center text-gray-400">
                                <ClipboardList size={48} className="mx-auto mb-3 opacity-30" />
                                <p className="text-lg">Sin sesiones de conteo</p>
                                <p className="text-sm mt-1">Cree una nueva sesion para comenzar</p>
                            </div>
                        )}
                    </div>

                    <Modal isOpen={showNewSessionModal} onClose={() => setShowNewSessionModal(false)} title={`Nueva Sesion - ${TAB_LABELS[activeTab]}`}>
                        <div className="space-y-4">
                            <div className="bg-amber-50 border border-amber-200 rounded-lg p-3">
                                <p className="text-sm text-amber-700">
                                    {activeTab === 'GENERAL'
                                        ? 'Importante: Todos los productos NO escaneados se ajustaran a CERO. Use este modo cuando vaya a contar todo el inventario.'
                                        : 'Los productos que NO escanee quedaran con su stock actual sin cambios.'}
                                </p>
                            </div>
                            <Input
                                label="Nombre de la Sesion"
                                placeholder="Ej: Inventario General 2025"
                                value={newSessionName}
                                onChange={e => setNewSessionName(e.target.value)}
                            />
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">Bodega a contar</label>
                                <select
                                    value={selectedBodegaId}
                                    onChange={e => setSelectedBodegaId(e.target.value)}
                                    className="w-full px-3 py-2 border border-gray-300 rounded-lg shadow-sm text-sm focus:ring-blue-500 focus:border-blue-500"
                                >
                                    {bodegas.map(b => (
                                        <option key={b.id} value={b.id}>{b.nombre}</option>
                                    ))}
                                </select>
                            </div>
                            <div className="flex justify-end pt-4">
                                <Button onClick={createSession}>Crear e Iniciar</Button>
                            </div>
                        </div>
                    </Modal>
                    <ConfirmModal
                        isOpen={!!deleteTarget}
                        onClose={() => setDeleteTarget(null)}
                        onConfirm={deleteSession}
                        title="Eliminar Sesion"
                        message={`Seguro que deseas eliminar la sesion "${deleteTarget?.nombre}"? Se perderan todos los conteos registrados.`}
                        confirmText="Eliminar"
                        variant="danger"
                    />
                </>
            )}
        </div>
    );
}
