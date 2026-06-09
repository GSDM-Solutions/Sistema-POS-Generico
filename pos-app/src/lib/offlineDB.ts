import { openDB, DBSchema, IDBPDatabase } from 'idb';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from './supabase';

// Schema para IndexedDB
interface POSDBSchema extends DBSchema {
    products: {
        key: string;
        value: {
            id: string;
            maestro_producto: {
                nombre: string;
                codigo_barra: string | null;
                precio_venta: number;
            };
            stock_actual: number;
            factor_conversion: number;
            es_presentacion: boolean;
            nombre_presentacion: string | null;
            unidad_medida: string;
            controla_stock: boolean;
            cached_at: number;
        };
        indexes: { 'by-barcode': string };
    };
    sales: {
        key: string;
        value: {
            id: string;
            local_id: string;
            items: any[];
            total: number;
            payment_method: string;
            customer_id: string | null;
            created_at: number;
            synced: boolean;
        };
    };
    settings: {
        key: string;
        value: {
            key: string;
            value: any;
        };
    };
}

let dbPromise: Promise<IDBPDatabase<POSDBSchema>> | null = null;

export function initDB() {
    if (!dbPromise) {
        dbPromise = openDB<POSDBSchema>('pos-db', 1, {
            upgrade(db) {
                // Store de productos
                const productStore = db.createObjectStore('products', { keyPath: 'id' });
                productStore.createIndex('by-barcode', 'maestro_producto.codigo_barra');

                // Store de ventas offline
                db.createObjectStore('sales', { keyPath: 'local_id' });

                // Store de configuración
                db.createObjectStore('settings', { keyPath: 'key' });
            },
        });
    }
    return dbPromise;
}

// CRUD Productos
export async function cacheProducts(products: any[]) {
    const db = await initDB();
    const tx = db.transaction('products', 'readwrite');
    
    // Limpiar productos anteriores
    await tx.objectStore('products').clear();
    
    // Guardar nuevos con timestamp
    const productsWithTimestamp = products.map(p => ({
        ...p,
        cached_at: Date.now()
    }));
    
    await Promise.all(
        productsWithTimestamp.map(p => tx.objectStore('products').put(p))
    );
    
    await tx.done();
}

export async function getCachedProducts() {
    const db = await initDB();
    const products = await db.getAll('products');
    
    // Filtrar productos cacheados hace menos de 24 horas
    const fifteenMinutes = 15 * 60 * 1000;
    const now = Date.now();
    
    return products.filter(p => (now - p.cached_at) < fifteenMinutes);
}

export async function getProductByBarcode(barcode: string) {
    const db = await initDB();
    const index = db.transaction('products').store.index('by-barcode');
    return index.get(barcode);
}

// CRUD Ventas Offline
export async function saveOfflineSale(sale: any) {
    const db = await initDB();
    const localId = `local_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    await db.add('sales', {
        ...sale,
        local_id: localId,
        synced: false,
        created_at: Date.now()
    });
    
    return localId;
}

export async function getPendingSales() {
    const db = await initDB();
    const sales = await db.getAll('sales');
    return sales.filter(s => !s.synced);
}

export async function markSaleAsSynced(localId: string) {
    const db = await initDB();
    const sale = await db.get('sales', localId);
    if (sale) {
        await db.put('sales', { ...sale, synced: true });
    }
}

export async function deleteSyncedSales() {
    const db = await initDB();
    const sales = await db.getAll('sales');
    const tx = db.transaction('sales', 'readwrite');
    
    for (const sale of sales) {
        if (sale.synced) {
            await tx.objectStore('sales').delete(sale.local_id);
        }
    }
    
    await tx.done();
}

// Stock cache: track local deductions (cart + pending sales)
export async function trackLocalStockUsage(productId: string, qty: number) {
    const db = await initDB();
    const key = `stock_usage_${productId}`;
    const current = await db.get('settings', key);
    const newUsage = (current?.value || 0) + qty;
    await db.put('settings', { key, value: newUsage });
    return newUsage;
}

export async function getLocalStockUsage(productId: string): Promise<number> {
    const db = await initDB();
    const entry = await db.get('settings', `stock_usage_${productId}`);
    return entry?.value || 0;
}

export async function clearLocalStockUsage() {
    const db = await initDB();
    const all = await db.getAll('settings');
    const tx = db.transaction('settings', 'readwrite');
    for (const s of all) {
        if (s.key.startsWith('stock_usage_')) {
            await tx.objectStore('settings').delete(s.key);
        }
    }
    await tx.done();
}

// Settings
export async function saveSetting(key: string, value: any) {
    const db = await initDB();
    await db.put('settings', { key, value });
}

export async function getSetting(key: string) {
    const db = await initDB();
    const setting = await db.get('settings', key);
    return setting?.value;
}

// Utilidad: Verificar si hay conexión
export function isOnline() {
    return navigator.onLine;
}

// Hook personalizado para React
import { useState, useEffect, useCallback } from 'react';

export function useOfflinePOS() {
    const [isOffline, setIsOffline] = useState(!navigator.onLine);
    const [pendingSales, setPendingSales] = useState<number>(0);
    const [failedSales, setFailedSales] = useState<number>(0);

    useEffect(() => {
        const handleOnline = () => {
            setIsOffline(false);
            syncPendingSales();
        };
        const handleOffline = () => setIsOffline(true);

        window.addEventListener('online', handleOnline);
        window.addEventListener('offline', handleOffline);

        return () => {
            window.removeEventListener('online', handleOnline);
            window.removeEventListener('offline', handleOffline);
        };
    }, []);

    useEffect(() => {
        loadPendingSales();
        
        // Actualizar contador cada 5 segundos
        const interval = setInterval(loadPendingSales, 5000);
        return () => clearInterval(interval);
    }, []);

    const loadPendingSales = async () => {
        const pending = await getPendingSales();
        setPendingSales(pending.length);
    };

    const syncPendingSales = useCallback(async () => {
        const pending = await getPendingSales();
        
        if (pending.length === 0) return;

        console.log(`Sincronizando ${pending.length} ventas pendientes...`);
        
        // Refrescar productos antes de sincronizar (asegura stock real)
        try {
            const { data: freshProducts } = await supabase.rpc('search_products_pos_bodega', {
                p_query: ''
            });
            if (freshProducts?.length > 0) {
                await cacheProducts(freshProducts);
            }
        } catch {
            // Si falla el refresh, continuamos con lo que haya
        }
        
        let synced = 0;
        let failed = 0;
        for (const sale of pending) {
            try {
                const { data, error } = await supabase.rpc('procesar_venta', {
                    p_cliente_id: sale.customer_id || null,
                    p_tipo_venta: sale.payment_method,
                    p_items: sale.items.map((i: any) => ({
                        producto_id: i.producto_id,
                        cantidad: i.cantidad,
                        precio: i.precio,
                        factor: i.factor || 1
                    })),
                    p_usuario_id: sale.usuario_id,
                    p_force_credit: false
                });

                if (error) {
                    console.error(`Venta ${sale.local_id}: ${error.message}`);
                    failed++;
                } else {
                    await markSaleAsSynced(sale.local_id);
                    synced++;
                }
            } catch (error: any) {
                console.error(`Venta ${sale.local_id}: ${error?.message || error}`);
                failed++;
            }
        }

        await deleteSyncedSales();
        await clearLocalStockUsage();
        loadPendingSales();
        
        if (synced > 0) {
            console.log(`${synced} ventas sincronizadas con Supabase`);
        }
        if (failed > 0) {
            console.warn(`${failed} ventas pendientes por reintentar (posible stock insuficiente)`);
        }
        
        setFailedSales(failed);
        return { synced, failed };
    }, []);

    // Auto-sync cada 30 segundos cuando hay conexion
    useEffect(() => {
        if (isOffline) return;
        
        const interval = setInterval(() => {
            syncPendingSales();
        }, 30000);
        
        return () => clearInterval(interval);
    }, [isOffline, syncPendingSales]);

    return {
        isOffline,
        pendingSales,
        failedSales,
        syncPendingSales
    };
}
