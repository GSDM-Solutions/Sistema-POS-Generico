
import React, { useState, useEffect, useRef, useMemo } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { toast } from 'react-hot-toast';
import {
    Search, ShoppingCart, User,
    Plus, Minus, X, Receipt, ArrowRightLeft, FileText, DollarSign, Info, AlertTriangle, Trash2,
    ScanLine, WifiOff, Database, LogOut, RefreshCw, Hash, Banknote, CreditCard, ShoppingBag,
    Keyboard
} from 'lucide-react';
import { TransactionReceipt } from '../components/pos/TransactionReceipt';
import { Modal } from '../components/ui/Modal';
import { ConfirmModal } from '../components/ui/ConfirmModal';
import { playAddSound, playRemoveSound, playCheckoutSound } from '../lib/sounds';
import { useOfflinePOS, cacheProducts, getCachedProducts, saveOfflineSale, saveSetting, getSetting, trackLocalStockUsage, getLocalStockUsage, getStockSnapshot } from '../lib/offlineDB';

type TipoDocumento = 'BOLETA' | 'FACTURA';
type MetodoPago = 'CASH' | 'CARD' | 'TRANSFER' | 'CREDIT';
type FormaPagoDB = 'BOLETA' | 'FACTURA' | 'TRANSFERENCIA' | 'FIADO';

// Types
interface Product {
    id: string;
    maestro_producto: {
        nombre: string;
        codigo_barra: string | null;
        precio_venta: number;
    };
    numero_lote: string | null;
    fecha_vencimiento: string | null;
    stock_actual: number;
    factor_conversion: number;
    es_presentacion: boolean;
    nombre_presentacion: string | null;
    unidad_medida: string;
    controla_stock: boolean;
}

interface CartItem extends Product {
    quantity: number;
    cartItemId: string;
}

interface Customer {
    id: string;
    nombre: string;
    rut: string;
    cupo_credito: number;
    saldo_actual: number;
    giro?: string;
    es_empresa?: boolean;
    direccion?: string;
    telefono?: string;
}

interface PreVentaItem {
    nombre: string;
    cantidad: number;
    precio: number;
    producto_id: string;
    factor?: number;
    unidad_medida?: string;
}

interface PreVentaData {
    id: string;
    codigo_preventa: string;
    estado: string;
    total: number;
    items: PreVentaItem[];
    vendedor_nombre: string;
    cliente_nombre: string | null;
    cliente_id: string | null;
    notas_vendedor: string | null;
    tipo_venta: string;
}

interface ReceiptData {
    folio: string;
    fecha: Date;
    total: number;
    items: { nombre: string; cantidad: number; precio: number; unidad_medida: string }[];
    tipo_venta: string;
    forma_pago_detalle?: string;
    cliente?: { nombre: string; rut: string; saldo_actual: number; giro?: string; direccion?: string };
    usuario: string | undefined;
    efectivo_recibido?: number;
    vuelto?: number;
    saldo_anterior?: number;
    nuevo_saldo?: number;
}

export function POS() {
    const { user, logout } = useAuth();
    const [searchTerm, setSearchTerm] = useState('');
    const [products, setProducts] = useState<Product[]>([]);
    const [cart, setCart] = useState<CartItem[]>([]);
    const [loading, setLoading] = useState(false);
    const [isCheckoutOpen, setIsCheckoutOpen] = useState(false);
    const [isPriceCheckerOpen, setIsPriceCheckerOpen] = useState(false);

    const [uiPaymentMethod, setUiPaymentMethod] = useState<MetodoPago>('CASH');
    const [uiDocumentType, setUiDocumentType] = useState<TipoDocumento>('BOLETA');

    const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
    const [customerSearch, setCustomerSearch] = useState('');
    const [customers, setCustomers] = useState<Customer[]>([]);
    const [processing, setProcessing] = useState(false);
    const processingLockRef = useRef(false);
    const [lastTransaction, setLastTransaction] = useState<ReceiptData | null>(null);

    const [preVentaModal, setPreVentaModal] = useState<{
        isOpen: boolean;
        data: PreVentaData | null;
    }>({ isOpen: false, data: null });
    const [preVentaIdCargada, setPreVentaIdCargada] = useState<string | null>(null);
    const [confirmModal, setConfirmModal] = useState<{ isOpen: boolean; message: string; onConfirm: () => void } | null>(null);

    const paymentMethod: FormaPagoDB = useMemo(() => {
        if (uiPaymentMethod === 'CREDIT') return 'FIADO';
        if (uiDocumentType === 'FACTURA') return 'FACTURA';
        if (uiPaymentMethod === 'TRANSFER') return 'TRANSFERENCIA';
        return 'BOLETA';
    }, [uiPaymentMethod, uiDocumentType]);

    const searchInputRef = useRef<HTMLInputElement>(null);
    const searchAbortRef = useRef<AbortController | null>(null);
    const scannerLockRef = useRef(false);

    const { isOffline, pendingSales, failedSales, syncPendingSales } = useOfflinePOS();

    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key === 'F2') {
                e.preventDefault();
                setCart([]);
                playRemoveSound();
            }
            if (e.key === 'F3') {
                e.preventDefault();
                setIsPriceCheckerOpen(true);
            }
            if (e.key === 'F4') {
                e.preventDefault();
                if (cart.length > 0) setIsCheckoutOpen(true);
            }
            if (e.ctrlKey && e.key === 'z') {
                e.preventDefault();
                const last = cart[cart.length - 1];
                if (last) {
                    setCart(prev => prev.slice(0, -1));
                    playRemoveSound();
                }
            }
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [cart]);

    const [voucherNumber, setVoucherNumber] = useState('');
    const [cashReceived, setCashReceived] = useState('');
    const [scanError, setScanError] = useState<string | null>(null);
    const [cacheMinutesOld, setCacheMinutesOld] = useState<number | null>(null);

    useEffect(() => {
        setVoucherNumber('');
        setCashReceived('');
    }, [isCheckoutOpen, uiPaymentMethod]);

    useEffect(() => {
        if (!scanError) return;
        const t = setTimeout(() => setScanError(null), 3000);
        return () => clearTimeout(t);
    }, [scanError]);

    useEffect(() => {
        const timer = setTimeout(() => {
            fetchProducts();
        }, 800);
        return () => clearTimeout(timer);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [searchTerm]);

    useEffect(() => {
        fetchProducts();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useEffect(() => {
        if (isOffline) return;
        const interval = setInterval(() => {
            fetchProducts();
        }, 60 * 1000);
        return () => clearInterval(interval);
    }, [isOffline]);

    const fetchProducts = async () => {
        try {
            searchAbortRef.current?.abort();
            const controller = new AbortController();
            searchAbortRef.current = controller;

            if (searchTerm.toUpperCase().startsWith('PV-')) {
                await buscarPreVenta(searchTerm.toUpperCase());
                return;
            }

            if (isOffline) {
                const cached = await getCachedProducts();
                const snapshot = await getStockSnapshot();
                if (snapshot?.takenAt) {
                    const mins = Math.round((Date.now() - snapshot.takenAt) / 60000);
                    setCacheMinutesOld(mins);
                }
                if (cached.length > 0) {
                    setProducts(cached);
                    const minsOld = snapshot?.takenAt
                        ? Math.round((Date.now() - snapshot.takenAt) / 60000)
                        : '?';
                    if (minsOld > 5) {
                        toast.error(`Cache desactualizado (${minsOld} min). Stock puede no ser exacto.`, { duration: 5000 });
                    } else {
                        toast.success(`Usando productos en cache (hace ${minsOld} min)`);
                    }
                } else {
                    setProducts([]);
                    toast.error('Cache vacio. Reconecte para operar.', { duration: 0 });
                }
                return;
            }

            const { data, error } = await supabase.rpc('search_products_pos_bodega', {
                p_query: searchTerm || ''
            });

            if (error) {
                toast.error('Error buscando productos');
                const cached = await getCachedProducts();
                if (cached.length > 0) setProducts(cached);
            } else {
                const mapped = data?.map((p: Record<string, unknown>) => ({
                    id: p.id,
                    stock_actual: p.stock_actual,
                    numero_lote: p.numero_lote,
                    fecha_vencimiento: p.fecha_vencimiento,
                    factor_conversion: p.factor_conversion || 1,
                    es_presentacion: p.es_presentacion || false,
                    nombre_presentacion: p.nombre_presentacion,
                    unidad_medida: p.unidad_medida || 'UN',
                    controla_stock: p.controla_stock ?? true,
                    maestro_producto: {
                        nombre: p.nombre_producto,
                        codigo_barra: p.codigo_barra,
                        precio_venta: p.precio_venta
                    }
                }));
                setProducts(mapped || []);

                if (mapped && mapped.length > 0) {
                    await cacheProducts(mapped);
                }
            }
        } catch {
            setLoading(false);
        }
    };

    const buscarPreVenta = async (codigo: string) => {
        try {
            setLoading(true);

            const { data, error } = await supabase.rpc('buscar_preventa_por_codigo', {
                p_codigo: codigo
            });

            if (error) {
                toast.error('Error al buscar pre-venta');
                return;
            }

            if (!data || data.length === 0) {
                toast.error(`Pre-venta ${codigo} no encontrada o ya procesada`);
                setSearchTerm('');
                return;
            }

            const preVenta = data[0];

            if (preVenta.estado !== 'PENDIENTE') {
                toast.error(`Pre-venta ${codigo} no está pendiente (Estado: ${preVenta.estado})`);
                setSearchTerm('');
                return;
            }

            setPreVentaModal({ isOpen: true, data: preVenta });
            setLoading(false);

        } catch {
            toast.error('Error al procesar pre-venta');
            setLoading(false);
        }
    };

    const confirmarCargaPreVenta = async () => {
        const preVenta = preVentaModal.data;
        if (!preVenta) return;

        try {
            setPreVentaModal({ isOpen: false, data: null });
            setLoading(true);

            let itemsCargados = 0;
            let erroresStock = 0;

            for (const item of preVenta.items) {
                try {
                    const { data: productData, error: productError } = await supabase
                        .from('productos')
                        .select(`
                            id,
                            stock_actual,
                            numero_lote,
                            fecha_vencimiento,
                            maestro_producto:maestro_productos (
                                nombre,
                                codigo_barra,
                                precio_venta,
                                unidad_medida,
                                controla_stock
                            )
                        `)
                        .eq('id', item.producto_id)
                        .single();

                    if (productError || !productData) {
                        erroresStock++;
                        continue;
                    }

                    const maestroData = Array.isArray(productData.maestro_producto)
                        ? productData.maestro_producto[0]
                        : productData.maestro_producto;

                    if (!maestroData) {
                        erroresStock++;
                        continue;
                    }

                    const product: Product = {
                        id: productData.id,
                        stock_actual: productData.stock_actual,
                        numero_lote: productData.numero_lote,
                        fecha_vencimiento: productData.fecha_vencimiento,
                        factor_conversion: item.factor || 1,
                        es_presentacion: (item.factor || 1) > 1,
                        nombre_presentacion: null,
                        unidad_medida: maestroData.unidad_medida || 'UN',
                        controla_stock: maestroData.controla_stock ?? true,
                        maestro_producto: {
                            nombre: maestroData.nombre,
                            codigo_barra: maestroData.codigo_barra,
                            precio_venta: maestroData.precio_venta
                        }
                    };

                    if (product.controla_stock) {
                        const stockRequerido = item.cantidad * (item.factor || 1);
                        if (stockRequerido > product.stock_actual) {
                            toast.error(`Stock insuficiente para ${product.maestro_producto.nombre}`);
                            erroresStock++;
                            continue;
                        }
                    }

                    const cartItemId = `${product.id}-${product.factor_conversion}`;
                    setCart(prev => {
                        const existing = prev.find(i => i.cartItemId === cartItemId);
                        if (existing) {
                            return prev.map(i =>
                                i.cartItemId === cartItemId
                                    ? { ...i, quantity: i.quantity + item.cantidad }
                                    : i
                            );
                        }
                        return [...prev, { ...product, quantity: item.cantidad, cartItemId }];
                    });

                    itemsCargados++;
                } catch {
                    erroresStock++;
                }
            }

            setSearchTerm('');
            setProducts([]);

            if (itemsCargados > 0) {
                setPreVentaIdCargada(preVenta.id);

                toast.success(
                    `Pre-Venta ${preVenta.codigo_preventa} cargada\n${itemsCargados} productos agregados al carrito`,
                    { duration: 4000 }
                );

                if (preVenta.cliente_id) {
                    const { data: clienteData } = await supabase
                        .from('clientes')
                        .select('*')
                        .eq('id', preVenta.cliente_id)
                        .single();

                    if (clienteData) {
                        setSelectedCustomer(clienteData);
                    }
                }

                if (preVenta.tipo_venta === 'FIADO') {
                    setUiPaymentMethod('CREDIT');
                } else if (preVenta.tipo_venta === 'TRANSFERENCIA') {
                    setUiPaymentMethod('TRANSFER');
                } else if (preVenta.tipo_venta === 'FACTURA') {
                    setUiDocumentType('FACTURA');
                }
            }

            if (erroresStock > 0) {
                toast.error(`${erroresStock} productos no pudieron cargarse por falta de stock`);
            }

        } catch {
            toast.error('Error al cargar productos');
        } finally {
            setLoading(false);
        }
    };

    const addToCart = async (product: Product) => {
        const cartItemId = `${product.id}-${product.factor_conversion}`;

        if (product.controla_stock) {
            const currentUsage = cart
                .filter(i => i.id === product.id)
                .reduce((sum, i) => sum + (i.quantity * i.factor_conversion), 0);

            let effectiveStock = product.stock_actual;
            if (isOffline) {
                const localUsage = await getLocalStockUsage(product.id);
                effectiveStock = product.stock_actual - localUsage;
            }

            const demandWithAdd = currentUsage + product.factor_conversion;

            if (demandWithAdd > effectiveStock) {
                setScanError(product.maestro_producto.nombre);
                toast.error(`Stock insuficiente. Disp: ${effectiveStock}`);
                return;
            }
        }

        setCart(prev => {
            const existing = prev.find(item => item.cartItemId === cartItemId);
            if (existing) {
                return prev.map(item =>
                    item.cartItemId === cartItemId
                        ? { ...item, quantity: item.quantity + 1 }
                        : item
                );
            }
            return [...prev, { ...product, quantity: 1, cartItemId }];
        });
        playAddSound();
    };

    const removeFromCart = (cartItemId: string) => {
        setCart(prev => prev.filter(item => item.cartItemId !== cartItemId));
        playRemoveSound();
    };

    const requestRemove = (cartItemId: string) => {
        removeFromCart(cartItemId);
        toast.success('Producto eliminado');
    };

    const handleQuantityChange = (cartItemId: string, delta: number) => {
        updateQuantity(cartItemId, delta);
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (e.key === 'Enter') {
            if (scannerLockRef.current) {
                scannerLockRef.current = false;
                return;
            }
            const exactMatch = products.find(p => p.maestro_producto.codigo_barra === searchTerm)
                || (products.length === 1 ? products[0] : null);

            if (exactMatch) {
                addToCart(exactMatch);
                setSearchTerm('');
                toast.success(exactMatch.es_presentacion ? 'Pack Agregado' : 'Producto agregado');
                searchInputRef.current?.focus();
            }
        }
    };

    const handleSearchChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const value = e.target.value;
        setSearchTerm(value);

        if (value.length >= 8) {
            const exactMatch = products.find(p => p.maestro_producto.codigo_barra === value);
            if (exactMatch) {
                scannerLockRef.current = true;
                addToCart(exactMatch);
                setSearchTerm('');
                toast.success(exactMatch.es_presentacion ? 'Pack Agregado' : 'Producto agregado');
                return;
            }

            try {
                const { data, error } = await supabase.rpc('search_products_pos_bodega', {
                    p_query: value
                });

                if (!error && data && data.length > 0) {
                    const p = data[0];

                    if (p.controla_stock && p.stock_actual <= 0) {
                        setScanError(p.nombre_producto as string);
                        toast.error(`Sin stock: ${p.nombre_producto}`);
                        setSearchTerm('');
                        scannerLockRef.current = true;
                        return;
                    }

                    const product = {
                        id: p.id,
                        stock_actual: p.stock_actual,
                        numero_lote: p.numero_lote,
                        fecha_vencimiento: p.fecha_vencimiento,
                        factor_conversion: p.factor_conversion || 1,
                        es_presentacion: p.es_presentacion || false,
                        nombre_presentacion: p.nombre_presentacion,
                        unidad_medida: p.unidad_medida || 'UN',
                        controla_stock: p.controla_stock ?? true,
                        maestro_producto: {
                            nombre: p.nombre_producto,
                            codigo_barra: p.codigo_barra,
                            precio_venta: p.precio_venta
                        }
                    };

                    addToCart(product);
                    scannerLockRef.current = true;
                    setSearchTerm('');
                    toast.success(product.es_presentacion ? 'Pack Agregado' : 'Producto agregado');
                } else if (!error) {
                    setScanError(value);
                    toast.error('Producto sin stock en bodega de venta');
                    setSearchTerm('');
                    scannerLockRef.current = true;
                }
            } catch {
                // Silently fail, user can still search manually
            }
        }
    };

    const updateQuantity = (cartItemId: string, delta: number) => {
        const target = cart.find(i => i.cartItemId === cartItemId);
        if (!target) return;

        const newQty = target.quantity + delta;
        if (newQty < 1) return;

        if (target.controla_stock) {
            const otherUsage = cart
                .filter(i => i.id === target.id && i.cartItemId !== cartItemId)
                .reduce((sum, i) => sum + (i.quantity * i.factor_conversion), 0);

            const newUsage = otherUsage + (newQty * target.factor_conversion);

            if (newUsage > target.stock_actual) {
                toast.error('Stock maximo alcanzado');
                return;
            }
        }

        setCart(prev => prev.map(item => item.cartItemId === cartItemId ? { ...item, quantity: newQty } : item));
    };

    const cartTotal = cart.reduce((sum, item) => sum + (item.maestro_producto.precio_venta * item.quantity), 0);
    const neto = cartTotal / 1.19;
    const ivaAmount = cartTotal - neto;
    const cashReceivedNum = parseFloat(cashReceived) || 0;
    const changeAmount = cashReceivedNum - cartTotal;

    useEffect(() => {
        if ((paymentMethod === 'FIADO' || paymentMethod === 'FACTURA') && customerSearch) {
            const timer = setTimeout(async () => {
                let query = supabase
                    .from('clientes')
                    .select('*')
                    .ilike('nombre', `%${customerSearch}%`)
                    .limit(5);

                if (paymentMethod === 'FACTURA') {
                    query = query.eq('es_empresa', true);
                } else if (paymentMethod === 'FIADO') {
                    query = query.eq('es_empresa', false);
                }

                const { data } = await query;
                setCustomers(data || []);
            }, 300);
            return () => clearTimeout(timer);
        }
    }, [paymentMethod, customerSearch]);

    const isAdmin = user?.role === 'admin';
    const creditExceeded = paymentMethod === 'FIADO' && !!selectedCustomer && (selectedCustomer.cupo_credito - selectedCustomer.saldo_actual) < cartTotal;
    const cashInsufficient = uiPaymentMethod === 'CASH' && cashReceivedNum > 0 && cashReceivedNum < cartTotal;

    const handleCheckout = async () => {
        if (processingLockRef.current) return;
        processingLockRef.current = true;

        if (cart.length === 0) {
            processingLockRef.current = false;
            return;
        }
        if (uiPaymentMethod === 'CASH' && cashReceivedNum < cartTotal) {
            toast.error('Efectivo insuficiente');
            processingLockRef.current = false;
            return;
        }
        if ((uiPaymentMethod === 'CARD' || uiPaymentMethod === 'TRANSFER') && !voucherNumber.trim()) {
            toast.error('Debe ingresar el numero de transaccion');
            processingLockRef.current = false;
            return;
        }
        if ((paymentMethod === 'FIADO' || paymentMethod === 'FACTURA') && !selectedCustomer) {
            toast.error(`Debe seleccionar un cliente para ${paymentMethod === 'FIADO' ? 'Fiado' : 'Factura'}`);
            processingLockRef.current = false;
            return;
        }

        if (creditExceeded && !isAdmin) {
            toast.error('Credito excedido. Se requiere autorizacion de Administrador.');
            processingLockRef.current = false;
            return;
        }

        const confirmMessage = creditExceeded
            ? 'ADVERTENCIA: El cliente excede su cupo. Desea FORZAR la venta como Administrador?'
            : null;

        if (confirmMessage) {
            setConfirmModal({
                isOpen: true,
                message: confirmMessage,
                onConfirm: () => {
                    setConfirmModal(null);
                    executeCheckout();
                }
            });
            processingLockRef.current = false;
            return;
        }

        processingLockRef.current = false;
        executeCheckout();
    };

    const executeCheckout = async () => {
        if (processingLockRef.current) return;
        processingLockRef.current = true;

        if (isOffline) {
            try {
                const saleData = {
                    items: cart.map(i => ({
                        producto_id: i.id,
                        cantidad: i.quantity,
                        precio: i.maestro_producto.precio_venta,
                        nombre: i.maestro_producto.nombre,
                        factor: i.factor_conversion
                    })),
                    total: cartTotal,
                    payment_method: paymentMethod,
                    customer_id: selectedCustomer?.id || null,
                    customer_name: selectedCustomer?.nombre || null,
                    voucher_number: voucherNumber.trim() || null,
                    usuario_id: user?.id,
                    usuario_email: user?.email
                };

                await saveOfflineSale(saleData);

                for (const item of cart) {
                    if (item.controla_stock) {
                        await trackLocalStockUsage(item.id, item.quantity * item.factor_conversion);
                    }
                }

                const receiptData: ReceiptData = {
                    folio: `LOCAL-${Date.now()}`,
                    fecha: new Date(),
                    total: cartTotal,
                    items: cart.map(i => ({
                        nombre: i.es_presentacion && i.nombre_presentacion
                            ? `${i.maestro_producto.nombre} (${i.nombre_presentacion})`
                            : i.maestro_producto.nombre,
                        cantidad: i.quantity,
                        precio: i.maestro_producto.precio_venta,
                        unidad_medida: i.unidad_medida
                    })),
                    tipo_venta: paymentMethod,
                    usuario: user?.email,
                    ...(uiPaymentMethod === 'CASH' ? {
                        efectivo_recibido: cashReceivedNum,
                        vuelto: changeAmount
                    } : {}),
                    ...(paymentMethod === 'FIADO' && selectedCustomer ? {
                        saldo_anterior: selectedCustomer.saldo_actual,
                        nuevo_saldo: selectedCustomer.saldo_actual + cartTotal
                    } : {})
                };

                setLastTransaction(receiptData);
                setCart([]);
                setIsCheckoutOpen(false);
                setProcessing(false);
                processingLockRef.current = false;

                toast.success('Venta guardada (sin conexion) - Se sincronizara automaticamente');
                return;
            } catch {
                toast.error('Error guardando venta offline');
                processingLockRef.current = false;
                return;
            }
        }

        setProcessing(true);
        try {
            const payload = cart.map(item => ({
                producto_id: item.id,
                cantidad: item.quantity,
                precio: item.maestro_producto.precio_venta,
                factor: item.factor_conversion
            }));

            const { data, error } = await supabase.rpc('procesar_venta', {
                p_cliente_id: selectedCustomer?.id || null,
                p_tipo_venta: paymentMethod,
                p_items: payload,
                p_usuario_id: user?.id,
                p_force_credit: creditExceeded
            });

            if (error) {
                const details = (error as { message?: string; details?: string; hint?: string }).details || '';
                const hint = (error as { hint?: string }).hint || '';
                throw new Error(`${(error as { message?: string }).message || 'Error'}\n${details}\n${hint}`.trim());
            }

            if (voucherNumber.trim()) {
                const { error: boletaError } = await supabase.rpc('actualizar_nro_boleta', {
                    p_venta_id: data,
                    p_nro_boleta: voucherNumber.trim()
                });
                if (boletaError) {
                    throw boletaError;
                }
            }

            const receiptData: ReceiptData = {
                folio: data,
                fecha: new Date(),
                total: cartTotal,
                items: cart.map(i => ({
                    nombre: i.es_presentacion && i.nombre_presentacion
                        ? `${i.maestro_producto.nombre} (${i.nombre_presentacion})`
                        : i.maestro_producto.nombre,
                    cantidad: i.quantity,
                    precio: i.maestro_producto.precio_venta,
                    unidad_medida: i.unidad_medida
                })),
                tipo_venta: paymentMethod,
                forma_pago_detalle: voucherNumber.trim() ? (uiPaymentMethod === 'CARD' ? `Transaccion: ${voucherNumber}` : `Boleta N: ${voucherNumber}`) : undefined,
                cliente: selectedCustomer ? {
                    nombre: selectedCustomer.nombre,
                    rut: selectedCustomer.rut,
                    saldo_actual: selectedCustomer.saldo_actual,
                    giro: selectedCustomer.giro,
                    direccion: selectedCustomer.direccion
                } : undefined,
                usuario: user?.email,
                ...(uiPaymentMethod === 'CASH' ? {
                    efectivo_recibido: cashReceivedNum,
                    vuelto: changeAmount
                } : {}),
                ...(paymentMethod === 'FIADO' && selectedCustomer ? {
                    saldo_anterior: selectedCustomer.saldo_actual,
                    nuevo_saldo: selectedCustomer.saldo_actual + cartTotal
                } : {})
            };

            setLastTransaction(receiptData);

            if (preVentaIdCargada) {
                try {
                    const { error: preVentaError } = await supabase.rpc('confirmar_preventa', {
                        p_preventa_id: preVentaIdCargada,
                        p_cajero_id: user?.id,
                        p_notas_cajero: `Venta procesada - Folio: ${data}`
                    });

                    if (preVentaError) {
                        toast.error('Venta procesada pero error al confirmar pre-venta');
                    } else {
                        toast.success('Pre-venta confirmada automaticamente', { duration: 2000 });
                    }
                } catch {
                    toast.error('Venta procesada pero error al confirmar pre-venta');
                }

                setPreVentaIdCargada(null);
            }

            setCart([]);
            setIsCheckoutOpen(false);
            setSelectedCustomer(null);
            setCustomerSearch('');
            fetchProducts();
            toast.success('Venta registrada correctamente');

        } catch (err: unknown) {
            const message = err instanceof Error ? err.message : 'Error en la venta';
            toast.error(message);
        } finally {
            setProcessing(false);
            processingLockRef.current = false;
        }
    };


    return (
        <>
            {isOffline && (
                <div className={`px-4 py-2 flex items-center justify-between gap-3 shrink-0 text-sm font-semibold ${
                    cacheMinutesOld === null ? 'bg-amber-500 text-amber-900' :
                    cacheMinutesOld > 10 ? 'bg-red-500 text-red-900' :
                    cacheMinutesOld > 5 ? 'bg-orange-500 text-orange-900' :
                    'bg-amber-500 text-amber-900'
                }`}>
                    <div className="flex items-center gap-2">
                        <WifiOff size={16} />
                        <span>SIN CONEXION - Modo offline</span>
                        {cacheMinutesOld !== null && (
                            <span className="text-xs opacity-80">
                                (cache: hace {cacheMinutesOld} min)
                            </span>
                        )}
                    </div>
                    <div className="flex items-center gap-4 text-xs">
                        <span className="flex items-center gap-1">
                            <Database size={14} />
                            Pendientes: {pendingSales}
                        </span>
                        <button
                            onClick={syncPendingSales}
                            className="px-3 py-1 bg-amber-600 hover:bg-amber-700 text-white rounded-lg font-bold transition-colors"
                        >
                            Sincronizar ahora
                        </button>
                    </div>
                </div>
            )}

            {!isOffline && failedSales > 0 && (
                <div className="bg-red-600 text-white px-4 py-2 flex items-center justify-between gap-3 shrink-0 text-sm font-semibold">
                    <div className="flex items-center gap-2">
                        <AlertTriangle size={16} />
                        <span>{failedSales} venta(s) no sincronizadas (stock insuficiente)</span>
                    </div>
                    <button
                        onClick={syncPendingSales}
                        className="px-3 py-1 bg-white/20 hover:bg-white/30 rounded-lg font-bold transition-colors flex items-center gap-1 text-xs"
                    >
                        <RefreshCw size={14} />
                        Reintentar
                    </button>
                </div>
            )}

            <div className="flex flex-col h-screen bg-slate-100 overflow-hidden">
                {/* ========== TOP BAR ========== */}
                <header className="h-12 bg-white border-b border-slate-200 flex items-center justify-between px-4 shrink-0 z-10">
                    <div className="flex items-center gap-3">
                        <div className="flex items-center gap-2">
                            <div className="w-7 h-7 bg-slate-800 rounded-lg flex items-center justify-center">
                                <ShoppingBag size={14} className="text-white" />
                            </div>
                            <span className="text-sm font-black text-slate-800 tracking-tight">GESTION</span>
                            <span className="text-sm font-black text-emerald-600 tracking-tight">PRO</span>
                        </div>
                        <span className="text-[10px] font-bold uppercase text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md whitespace-nowrap tracking-wide">
                            Bodega Venta
                        </span>
                    </div>
                    <div className="flex items-center gap-3">
                        <div className="flex items-center gap-1.5 text-xs text-slate-500">
                            <div className="w-5 h-5 bg-slate-700 rounded-full flex items-center justify-center text-white text-[10px] font-bold">
                                {user?.name?.charAt(0).toUpperCase()}
                            </div>
                            <span className="font-medium text-slate-600 max-w-[100px] truncate">{user?.name}</span>
                        </div>
                        <button
                            onClick={logout}
                            className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                            title="Cerrar sesion"
                        >
                            <LogOut size={15} />
                        </button>
                    </div>
                </header>

                {/* ========== MAIN CONTENT ========== */}
                <div className="flex flex-1 overflow-hidden">
                    {/* ---- LEFT PANEL: Products ---- */}
                    <div className="w-[35%] min-w-[340px] flex flex-col bg-white border-r border-slate-200">
                        {/* Search Bar */}
                        <div className="p-3 pb-2">
                            <div className="relative">
                                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={17} />
                                <input
                                    ref={searchInputRef}
                                    type="text"
                                    placeholder="Buscar o escanear producto..."
                                    className="w-full pl-9 pr-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 focus:bg-white focus:border-blue-400 focus:ring-2 focus:ring-blue-100 transition-all text-sm font-medium outline-none"
                                    value={searchTerm}
                                    onChange={handleSearchChange}
                                    onKeyDown={handleKeyDown}
                                    autoFocus
                                />
                            </div>
                        </div>

                        {/* Scan Error */}
                        {scanError && (
                            <div className="mx-3 mb-2 p-3 bg-rose-50 border-2 border-rose-200 rounded-xl flex items-center gap-2 animate-in fade-in slide-in-from-top-2 duration-200">
                                <AlertTriangle size={16} className="text-rose-500 shrink-0" />
                                <div>
                                    <p className="text-xs font-bold text-rose-700">Producto sin stock disponible</p>
                                    <p className="text-[11px] text-rose-500 truncate">{scanError}</p>
                                </div>
                                <button onClick={() => setScanError(null)} className="ml-auto p-1 text-rose-400 hover:text-rose-600">
                                    <X size={14} />
                                </button>
                            </div>
                        )}

                        {/* Quick Actions - Large Buttons */}
                        <div className="px-3 pb-2">
                            <div className="grid grid-cols-2 gap-2">
                                <button
                                    onClick={() => { setCart([]); playRemoveSound(); toast.success('Carrito vaciado'); }}
                                    disabled={cart.length === 0}
                                    className="p-4 rounded-2xl border-2 border-rose-200 bg-rose-50 hover:bg-rose-100 hover:shadow-lg transition-all flex flex-col items-center justify-center gap-1.5 disabled:opacity-30 disabled:cursor-not-allowed group"
                                >
                                    <div className="p-2 bg-rose-200 rounded-full">
                                        <Trash2 className="text-rose-600" size={22} />
                                    </div>
                                    <div className="text-center">
                                        <p className="text-base font-black text-rose-800">F2</p>
                                        <p className="text-[10px] font-bold text-rose-600">Vaciar Carrito</p>
                                    </div>
                                </button>

                                <button
                                    onClick={() => setIsPriceCheckerOpen(true)}
                                    className="p-4 rounded-2xl border-2 border-blue-200 bg-blue-50 hover:bg-blue-100 hover:shadow-lg transition-all flex flex-col items-center justify-center gap-1.5 group"
                                >
                                    <div className="p-2 bg-blue-200 rounded-full">
                                        <ScanLine className="text-blue-600" size={22} />
                                    </div>
                                    <div className="text-center">
                                        <p className="text-base font-black text-blue-800">F3</p>
                                        <p className="text-[10px] font-bold text-blue-600">Consultar Precio</p>
                                    </div>
                                </button>

                                <button
                                    onClick={() => { if (cart.length > 0) { setIsCheckoutOpen(true); playCheckoutSound(); } }}
                                    disabled={cart.length === 0}
                                    className="p-4 rounded-2xl border-2 border-emerald-200 bg-emerald-50 hover:bg-emerald-100 hover:shadow-lg transition-all flex flex-col items-center justify-center gap-1.5 disabled:opacity-30 disabled:cursor-not-allowed group"
                                >
                                    <div className="p-2 bg-emerald-200 rounded-full">
                                        <Receipt className="text-emerald-600" size={22} />
                                    </div>
                                    <div className="text-center">
                                        <p className="text-base font-black text-emerald-800">F4</p>
                                        <p className="text-[10px] font-bold text-emerald-600">Cobrar</p>
                                    </div>
                                </button>

                                <div className="p-4 rounded-2xl bg-gradient-to-br from-slate-700 to-slate-900 shadow-lg flex flex-col items-center justify-center gap-1.5">
                                    <div className="p-2 bg-white/15 rounded-full">
                                        <ShoppingBag className="text-white" size={22} />
                                    </div>
                                    <div className="text-center">
                                        <p className="text-sm font-black text-white tracking-wider">GESTION PRO</p>
                                        <p className="text-[10px] font-medium text-white/60">POS System</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* Espacio libre */}
                        <div className="flex-1" />
                    </div>

                    {/* ---- RIGHT PANEL: Cart ---- */}
                    <div className="w-[65%] flex flex-col bg-slate-50">
                        {/* Cart Header */}
                        <div className="px-5 py-3 border-b border-slate-200 bg-white flex items-center justify-between shrink-0">
                            <div className="flex items-center gap-2.5">
                                <div className="p-1.5 bg-slate-800 rounded-lg">
                                    <ShoppingCart size={16} className="text-white" />
                                </div>
                                <div>
                                    <h2 className="font-bold text-sm text-slate-800">Venta Actual</h2>
                                    <p className="text-[11px] text-slate-400">{cart.length} producto{cart.length !== 1 ? 's' : ''}</p>
                                </div>
                            </div>
                            <span className="text-[10px] text-slate-400 flex items-center gap-1">
                                <Keyboard size={11} /> F4 Cobrar
                            </span>
                        </div>

                        {/* Cart Items */}
                        <div className="flex-1 overflow-y-auto p-4 space-y-2">
                            {cart.map(item => (
                                <div
                                    key={item.cartItemId}
                                    className="bg-white rounded-xl p-3 border border-slate-100 hover:border-slate-200 transition-colors group"
                                >
                                    <div className="flex items-center gap-3">
                                        {/* Qty Controls */}
                                        <div className="flex items-center bg-slate-100 rounded-lg shrink-0">
                                            <button
                                                onClick={() => handleQuantityChange(item.cartItemId, -1)}
                                                className="w-7 h-7 flex items-center justify-center text-slate-500 hover:text-slate-700 hover:bg-slate-200 rounded-l-lg transition-colors"
                                            >
                                                <Minus size={13} />
                                            </button>
                                            <span className="w-7 text-center text-sm font-bold text-slate-800 select-none">
                                                {item.quantity}
                                            </span>
                                            <button
                                                onClick={() => handleQuantityChange(item.cartItemId, 1)}
                                                className="w-7 h-7 flex items-center justify-center text-emerald-600 hover:bg-emerald-50 rounded-r-lg transition-colors"
                                            >
                                                <Plus size={13} />
                                            </button>
                                        </div>

                                        {/* Item Info */}
                                        <div className="flex-1 min-w-0">
                                            <p className="font-bold text-sm text-slate-800 truncate">
                                                {item.maestro_producto.nombre}
                                            </p>
                                            {item.es_presentacion && (
                                                <span className="text-[10px] text-purple-600">{item.nombre_presentacion}</span>
                                            )}
                                        </div>

                                        {/* Price */}
                                        <div className="text-right shrink-0">
                                            <p className="text-sm font-black text-slate-900">
                                                ${(item.maestro_producto.precio_venta * item.quantity).toLocaleString()}
                                            </p>
                                            <p className="text-[10px] text-slate-400">
                                                ${item.maestro_producto.precio_venta.toLocaleString()} c/u
                                            </p>
                                        </div>

                                        {/* Remove */}
                                        <button
                                            onClick={() => requestRemove(item.cartItemId)}
                                            className="p-1 text-slate-300 hover:text-rose-500 hover:bg-rose-50 rounded-lg transition-colors opacity-0 group-hover:opacity-100"
                                            title="Quitar"
                                        >
                                            <X size={14} />
                                        </button>
                                    </div>
                                </div>
                            ))}

                            {cart.length === 0 && (
                                <div className="flex flex-col items-center justify-center h-full text-slate-300 py-10">
                                    <div className="bg-slate-100 p-5 rounded-full mb-3">
                                        <ShoppingCart size={32} className="opacity-20" />
                                    </div>
                                    <p className="font-medium text-sm text-slate-400">Carrito vacio</p>
                                    <p className="text-xs mt-1 text-slate-300">Escanea un producto para comenzar</p>
                                </div>
                            )}
                        </div>

                        {/* Cart Footer - Totals */}
                        <div className="bg-white border-t border-slate-200 p-4 space-y-3 shrink-0">
                            <div className="space-y-1 text-xs">
                                <div className="flex justify-between text-slate-500">
                                    <span>Subtotal</span>
                                    <span className="font-medium">${neto.toLocaleString()}</span>
                                </div>
                                <div className="flex justify-between text-slate-500">
                                    <span>IVA (19%)</span>
                                    <span className="font-medium">${ivaAmount.toLocaleString()}</span>
                                </div>
                                <div className="flex justify-between pt-2 border-t border-slate-100">
                                    <span className="text-sm font-bold text-slate-700">TOTAL</span>
                                    <span className="text-lg font-black text-slate-900">${cartTotal.toLocaleString()}</span>
                                </div>
                            </div>
                            <button
                                onClick={() => { setIsCheckoutOpen(true); playCheckoutSound(); }}
                                disabled={cart.length === 0}
                                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 disabled:bg-slate-200 disabled:text-slate-400 text-white rounded-xl font-bold text-sm shadow-lg shadow-emerald-600/20 active:scale-[0.98] transition-all flex items-center justify-center gap-2"
                            >
                                Cobrar F4
                                <Receipt size={16} />
                                {cart.length > 0 && (
                                    <span className="absolute -top-1.5 -right-1.5 bg-slate-800 text-white text-[10px] font-black w-5 h-5 rounded-full flex items-center justify-center shadow">
                                        {cart.length}
                                    </span>
                                )}
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            {/* ========== RECEIPT MODAL ========== */}
            {lastTransaction && (
                <TransactionReceipt
                    isOpen={!!lastTransaction}
                    onClose={() => setLastTransaction(null)}
                    data={lastTransaction}
                />
            )}

            {/* ========== CHECKOUT MODAL ========== */}
            <Modal isOpen={isCheckoutOpen} onClose={() => setIsCheckoutOpen(false)} title="Finalizar Venta" size="lg">
                <div className="space-y-5 overflow-y-auto flex-1">
                    {/* Total */}
                    <div className="bg-slate-800 p-5 rounded-2xl text-center text-white">
                        <p className="text-xs text-slate-400 mb-1 font-medium uppercase tracking-wider">Total a Pagar</p>
                        <p className="text-4xl font-black">${cartTotal.toLocaleString()}</p>
                        <div className="flex justify-center gap-4 mt-2 text-[11px] text-slate-400">
                            <span>Neto: ${neto.toLocaleString()}</span>
                            <span>IVA: ${ivaAmount.toLocaleString()}</span>
                        </div>
                    </div>

                    {/* 1. Payment Method */}
                    <div>
                        <label className="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">1. Metodo de Pago</label>
                        <div className="grid grid-cols-4 gap-2">
                            {[
                                { id: 'CASH', label: 'Efectivo', icon: Banknote, color: 'emerald' },
                                { id: 'CARD', label: 'Tarjeta', icon: CreditCard, color: 'indigo' },
                                { id: 'TRANSFER', label: 'Transfer.', icon: ArrowRightLeft, color: 'blue' },
                                { id: 'CREDIT', label: 'Fiado', icon: User, color: 'purple' }
                            ].map(m => {
                                const isActive = uiPaymentMethod === m.id;
                                const colorMap: Record<string, { bg: string; text: string; border: string; activeBg: string }> = {
                                    emerald: { bg: 'bg-emerald-50', text: 'text-emerald-700', border: 'border-emerald-200', activeBg: 'bg-emerald-100' },
                                    indigo: { bg: 'bg-indigo-50', text: 'text-indigo-700', border: 'border-indigo-200', activeBg: 'bg-indigo-100' },
                                    blue: { bg: 'bg-blue-50', text: 'text-blue-700', border: 'border-blue-200', activeBg: 'bg-blue-100' },
                                    purple: { bg: 'bg-purple-50', text: 'text-purple-700', border: 'border-purple-200', activeBg: 'bg-purple-100' }
                                };
                                const c = colorMap[m.color];
                                return (
                                    <button
                                        key={m.id}
                                        onClick={() => {
                                            setUiPaymentMethod(m.id as MetodoPago);
                                            if (m.id === 'CREDIT') {
                                                setSelectedCustomer(null);
                                            } else {
                                                setUiDocumentType('BOLETA');
                                                setSelectedCustomer(null);
                                            }
                                        }}
                                        className={`p-3 rounded-xl border-2 flex flex-col items-center gap-1.5 transition-all ${isActive
                                            ? `${c.activeBg} ${c.border} ${c.text}`
                                            : 'border-slate-100 hover:border-slate-200 text-slate-500 bg-white'
                                            }`}
                                    >
                                        <m.icon size={22} />
                                        <span className="text-[11px] font-bold">{m.label}</span>
                                    </button>
                                );
                            })}
                        </div>
                    </div>

                    {/* CASH: Efectivo Recibido */}
                    {uiPaymentMethod === 'CASH' && (
                        <div className="bg-emerald-50 border-2 border-emerald-200 rounded-2xl p-4">
                            <label className="block text-xs font-bold text-emerald-800 mb-2 uppercase tracking-wider">
                                Efectivo Recibido
                            </label>
                            <div className="flex gap-2">
                                <span className="flex items-center justify-center w-10 bg-white border border-emerald-200 rounded-xl text-emerald-600 font-bold text-lg">$</span>
                                <input
                                    type="number"
                                    value={cashReceived}
                                    onChange={(e) => setCashReceived(e.target.value)}
                                    placeholder="Monto con que paga el cliente..."
                                    className="flex-1 p-3 border border-emerald-200 rounded-xl focus:ring-2 focus:ring-emerald-400 outline-none font-bold text-lg bg-white"
                                    autoFocus
                                    min="0"
                                />
                            </div>
                            {cashReceivedNum > 0 && (
                                <div className={`mt-3 p-3 rounded-xl text-center font-black text-xl transition-all ${changeAmount >= 0 ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'}`}>
                                    {changeAmount >= 0
                                        ? `Vuelto: $${changeAmount.toLocaleString()}`
                                        : `Faltan: $${Math.abs(changeAmount).toLocaleString()}`}
                                </div>
                            )}
                        </div>
                    )}

                    {/* CARD / TRANSFER: Voucher Number */}
                    {(uiPaymentMethod === 'CARD' || uiPaymentMethod === 'TRANSFER') && (
                        <div className="bg-indigo-50 border-2 border-dashed border-indigo-200 rounded-2xl p-4">
                            <label className="block text-xs font-bold text-indigo-800 mb-2 uppercase tracking-wider">
                                Numero de Transaccion
                            </label>
                            <div className="flex gap-2">
                                <span className="flex items-center justify-center w-10 bg-white border border-indigo-200 rounded-xl text-indigo-400 font-bold"><Hash size={16} /></span>
                                <input
                                    type="text"
                                    value={voucherNumber}
                                    onChange={(e) => setVoucherNumber(e.target.value)}
                                    placeholder={uiPaymentMethod === 'CARD' ? 'N de transaccion GETNET...' : 'N de transferencia...'}
                                    className="flex-1 p-3 border border-indigo-200 rounded-xl focus:ring-2 focus:ring-indigo-400 outline-none font-bold text-lg bg-white"
                                    autoFocus
                                />
                            </div>
                            <p className="text-[10px] text-indigo-600 mt-2">
                                {uiPaymentMethod === 'CARD'
                                    ? 'Ingrese el numero del voucher de la maquina de pago.'
                                    : 'Ingrese el numero de comprobante de la transferencia.'}
                            </p>
                        </div>
                    )}

                    {/* 2. Document Type (non-CREDIT) */}
                    {uiPaymentMethod !== 'CREDIT' && (
                        <div>
                            <label className="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">2. Tipo de Documento</label>
                            <div className="flex gap-2">
                                {[
                                    { id: 'BOLETA', label: 'Boleta', icon: Receipt },
                                    { id: 'FACTURA', label: 'Factura', icon: FileText }
                                ].map(d => (
                                    <button
                                        key={d.id}
                                        onClick={() => {
                                            setUiDocumentType(d.id as TipoDocumento);
                                            setSelectedCustomer(null);
                                        }}
                                        className={`flex-1 p-3 rounded-xl border-2 flex items-center justify-center gap-2 transition-all ${uiDocumentType === d.id
                                            ? 'border-slate-800 bg-slate-800 text-white'
                                            : 'border-slate-100 hover:border-slate-200 text-slate-500'
                                            }`}
                                    >
                                        <d.icon size={18} />
                                        <span className="text-sm font-bold">{d.label}</span>
                                    </button>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* CREDIT / FACTURA: Customer Selection */}
                    {(paymentMethod === 'FIADO' || paymentMethod === 'FACTURA') && (
                        <div>
                            <label className="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">
                                {paymentMethod === 'FIADO' ? '3. Datos del Cliente' : '2. Datos del Cliente'}
                            </label>
                            {!selectedCustomer ? (
                                <div className="space-y-2">
                                    <div className="flex gap-2">
                                        <div className="relative flex-1">
                                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={15} />
                                            <input
                                                type="text"
                                                placeholder="Buscar cliente por nombre..."
                                                className="w-full pl-9 p-2.5 rounded-xl border border-slate-200 focus:ring-2 focus:ring-blue-400 outline-none text-sm"
                                                value={customerSearch}
                                                onChange={e => setCustomerSearch(e.target.value)}
                                                autoFocus
                                            />
                                        </div>
                                    </div>
                                    <div className="space-y-1 max-h-40 overflow-y-auto">
                                        {customers.map(c => (
                                            <button
                                                key={c.id}
                                                onClick={() => setSelectedCustomer(c)}
                                                className="w-full p-3 text-left hover:bg-slate-50 rounded-xl flex justify-between items-center border border-slate-100"
                                            >
                                                <div>
                                                    <div className="font-bold text-slate-800 text-sm">{c.nombre}</div>
                                                    <div className="text-[10px] text-slate-400">RUT: {c.rut}</div>
                                                </div>
                                                <div className="text-right">
                                                    <div className={`font-bold text-sm ${paymentMethod === 'FIADO' && (c.cupo_credito - c.saldo_actual) < cartTotal ? 'text-red-500' : 'text-slate-700'}`}>
                                                        {paymentMethod === 'FIADO'
                                                            ? `$${(c.cupo_credito - c.saldo_actual).toLocaleString()}`
                                                            : (c.giro || 'N/A')}
                                                    </div>
                                                    <div className="text-[10px] text-slate-400">
                                                        {paymentMethod === 'FIADO' ? 'Cupo Disponible' : 'Giro'}
                                                    </div>
                                                </div>
                                            </button>
                                        ))}
                                    </div>
                                </div>
                            ) : (
                                <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200 relative">
                                    <button
                                        onClick={() => setSelectedCustomer(null)}
                                        className="absolute top-2 right-2 p-1 hover:bg-slate-200 rounded-full text-slate-400 hover:text-red-500"
                                    >
                                        <X size={14} />
                                    </button>
                                    <div className="flex items-center gap-3 mb-3">
                                        <div className="w-9 h-9 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center font-bold text-sm">
                                            {selectedCustomer.nombre.charAt(0)}
                                        </div>
                                        <div>
                                            <div className="font-bold text-slate-900 text-sm">{selectedCustomer.nombre}</div>
                                            <div className="text-[10px] text-slate-400">{selectedCustomer.rut}</div>
                                        </div>
                                    </div>
                                    {paymentMethod === 'FIADO' && (
                                        <>
                                            <div className="h-2 w-full bg-slate-200 rounded-full overflow-hidden">
                                                <div
                                                    className={`h-full transition-all ${((selectedCustomer.saldo_actual + cartTotal) / selectedCustomer.cupo_credito) > 1 ? 'bg-red-500' : 'bg-blue-500'}`}
                                                    style={{ width: `${Math.min(((selectedCustomer.saldo_actual + cartTotal) / selectedCustomer.cupo_credito) * 100, 100)}%` }}
                                                />
                                            </div>
                                            <div className="flex justify-between mt-2 text-[11px]">
                                                <span className="text-slate-500">Deuda: ${selectedCustomer.saldo_actual.toLocaleString()}</span>
                                                <span className="text-slate-500">Cupo: ${selectedCustomer.cupo_credito.toLocaleString()}</span>
                                            </div>
                                        </>
                                    )}
                                </div>
                            )}
                        </div>
                    )}
                </div>

                {/* Confirm Button */}
                <div className="pt-4">
                    <button
                        onClick={handleCheckout}
                        disabled={processing || (paymentMethod === 'FIADO' && !selectedCustomer) || cashInsufficient || (creditExceeded && !isAdmin)}
                        className={`w-full py-4 rounded-xl font-bold shadow-lg disabled:opacity-40 disabled:cursor-not-allowed transition-all text-white ${creditExceeded && isAdmin ? 'bg-red-600 hover:bg-red-700' : 'bg-emerald-600 hover:bg-emerald-700 shadow-emerald-600/20'}`}
                    >
                        {processing ? 'Procesando...' : (creditExceeded && isAdmin ? 'Forzar Venta (Admin)' : `Confirmar Venta - $${cartTotal.toLocaleString()}`)}
                    </button>
                </div>
            </Modal>

            {/* ========== PRICE CHECKER MODAL ========== */}
            <PriceCheckerModal isOpen={isPriceCheckerOpen} onClose={() => setIsPriceCheckerOpen(false)} />

            {/* ========== CONFIRM MODAL ========== */}
            {confirmModal && (
                <ConfirmModal
                    isOpen={confirmModal.isOpen}
                    onClose={() => setConfirmModal(null)}
                    onConfirm={confirmModal.onConfirm}
                    title="Confirmar Accion"
                    message={confirmModal.message}
                    confirmText="Forzar Venta"
                    variant="danger"
                />
            )}

            {/* ========== PRE-VENTA MODAL ========== */}
            <Modal
                isOpen={preVentaModal.isOpen && !!preVentaModal.data}
                onClose={() => { setPreVentaModal({ isOpen: false, data: null }); setSearchTerm(''); }}
                title="Pre-Venta Encontrada"
                size="xl"
            >
                {preVentaModal.data && (
                    <div className="space-y-6">
                        <p className="text-blue-600 font-medium">Codigo: {preVentaModal.data.codigo_preventa}</p>

                        <div className="grid grid-cols-2 gap-4">
                            <div className="bg-slate-50 p-4 rounded-xl">
                                <p className="text-xs text-slate-500 mb-1">Vendedor</p>
                                <p className="font-bold text-slate-900">{preVentaModal.data.vendedor_nombre}</p>
                            </div>
                            <div className="bg-slate-50 p-4 rounded-xl">
                                <p className="text-xs text-slate-500 mb-1">Cliente</p>
                                <p className="font-bold text-slate-900">{preVentaModal.data.cliente_nombre || 'Sin cliente'}</p>
                            </div>
                        </div>

                        <div>
                            <h4 className="font-bold text-slate-700 mb-3 flex items-center gap-2">
                                <ShoppingCart size={18} />
                                Productos ({preVentaModal.data.items.length})
                            </h4>
                            <div className="max-h-60 overflow-y-auto space-y-2 bg-slate-50 p-4 rounded-xl">
                                {preVentaModal.data.items.map((item: PreVentaItem, idx: number) => (
                                    <div key={idx} className="flex justify-between items-center py-2 border-b border-slate-200 last:border-0">
                                        <div>
                                            <p className="font-semibold text-slate-800">{item.nombre}</p>
                                            <p className="text-xs text-slate-500">Cantidad: {item.cantidad} {item.unidad_medida || 'UN'}</p>
                                        </div>
                                        <p className="font-bold text-slate-900">${(item.cantidad * item.precio).toLocaleString()}</p>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="bg-gradient-to-r from-emerald-50 to-green-50 p-6 rounded-2xl border-2 border-emerald-200">
                            <p className="text-sm text-emerald-700 mb-1">Total a Cobrar</p>
                            <p className="text-4xl font-black text-emerald-800">${preVentaModal.data.total.toLocaleString()}</p>
                        </div>

                        {preVentaModal.data.notas_vendedor && (
                            <div className="bg-amber-50 p-4 rounded-xl border border-amber-200">
                                <p className="text-xs text-amber-700 font-semibold mb-1">Nota del Vendedor:</p>
                                <p className="text-sm text-amber-900">{preVentaModal.data.notas_vendedor}</p>
                            </div>
                        )}

                        <div className="flex gap-3 pt-2">
                            <button
                                onClick={() => {
                                    setPreVentaModal({ isOpen: false, data: null });
                                    setSearchTerm('');
                                }}
                                className="flex-1 py-3 px-6 bg-white border-2 border-slate-300 text-slate-700 rounded-xl font-bold hover:bg-slate-50 transition-colors"
                            >
                                Cancelar
                            </button>
                            <button
                                onClick={confirmarCargaPreVenta}
                                className="flex-1 py-3 px-6 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl font-bold hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg shadow-blue-600/20 flex items-center justify-center gap-2"
                            >
                                <ShoppingCart size={20} />
                                Cargar al Carrito
                            </button>
                        </div>
                    </div>
                )}
            </Modal>

        </>
    );
}

function PriceCheckerModal({ isOpen, onClose }: { isOpen: boolean, onClose: () => void }) {
    const [query, setQuery] = useState('');
    const [result, setResult] = useState<Record<string, unknown> | 'NOT_FOUND' | null>(null);
    const [loading, setLoading] = useState(false);
    const inputRef = useRef<HTMLInputElement>(null);

    useEffect(() => {
        if (isOpen) {
            setTimeout(() => inputRef.current?.focus(), 100);
            setResult(null);
            setQuery('');
        }
    }, [isOpen]);

    const handleSearch = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!query) return;
        setLoading(true);
        try {
            const { data, error } = await supabase.rpc('search_products_pos_bodega', { p_query: query });
            if (error) throw error;
            if (data && data.length > 0) {
                setResult(data[0]);
            } else {
                setResult('NOT_FOUND');
            }
        } catch {
            toast.error('Error en busqueda');
        } finally {
            setLoading(false);
            setQuery('');
        }
    };

    return (
        <Modal isOpen={isOpen} onClose={onClose} title="Visor de Precios" size="md">
            <div className="space-y-6 py-2">
                <form onSubmit={handleSearch} className="relative">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" />
                    <input
                        ref={inputRef}
                        type="text"
                        placeholder="Escanea o escribe codigo..."
                        className="w-full pl-11 pr-4 py-3.5 rounded-xl bg-slate-50 border-2 border-slate-100 focus:bg-white focus:border-blue-400 focus:ring-2 focus:ring-blue-100 transition-all font-bold text-base outline-none"
                        value={query}
                        onChange={e => setQuery(e.target.value)}
                    />
                </form>

                {loading && (
                    <div className="py-12 text-center">
                        <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-500 mx-auto"></div>
                    </div>
                )}

                {result === 'NOT_FOUND' && (
                    <div className="py-12 text-center">
                        <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                            <X className="w-8 h-8 text-red-400" />
                        </div>
                        <h3 className="text-lg font-bold text-slate-700">Producto no encontrado</h3>
                        <p className="text-slate-400 text-sm">Verifique el codigo e intente nuevamente.</p>
                    </div>
                )}

                {result && result !== 'NOT_FOUND' && (
                    <div className="bg-gradient-to-br from-slate-800 to-slate-900 p-8 rounded-3xl text-white shadow-xl">
                        <div className="flex justify-between items-start mb-6">
                            <div>
                                <p className="text-slate-400 text-xs font-medium uppercase tracking-wider mb-1">Nombre del Producto</p>
                                <h2 className="text-2xl font-black leading-tight">{result.nombre_producto}</h2>
                                {result.es_presentacion && (
                                    <span className="inline-block mt-2 px-3 py-1 bg-white/20 rounded-lg text-xs font-bold uppercase">
                                        Pack: {result.nombre_presentacion}
                                    </span>
                                )}
                            </div>
                            <div className="bg-white/10 p-3 rounded-2xl">
                                <Info size={28} />
                            </div>
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <div className="bg-white/10 p-4 rounded-2xl">
                                <p className="text-slate-400 text-xs font-medium mb-1">Precio de Venta</p>
                                <p className="text-3xl font-black">${result.precio_venta.toLocaleString()}</p>
                            </div>
                            <div className="bg-white/10 p-4 rounded-2xl">
                                <p className="text-slate-400 text-xs font-medium mb-1">Stock Disponible</p>
                                <p className="text-3xl font-black">
                                    {result.stock_actual}
                                    <span className="text-sm font-normal ml-1 text-slate-400">unid.</span>
                                </p>
                            </div>
                        </div>

                        <div className="mt-6 pt-6 border-t border-white/10 flex justify-between items-center text-sm">
                            <p className="text-slate-400">Codigo: {result.codigo_barra}</p>
                            <p className="bg-emerald-400/20 text-emerald-300 px-3 py-1 rounded-full font-bold text-xs">Precio Actualizado</p>
                        </div>
                    </div>
                )}
            </div>
            <div className="flex justify-center mt-4 text-slate-400 text-xs">
                <p>Presione ESC para cerrar</p>
            </div>
        </Modal>
    );
}
