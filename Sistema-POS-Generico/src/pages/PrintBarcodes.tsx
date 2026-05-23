import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { toast } from 'react-hot-toast';
import { Search, Printer, BarChart3 } from 'lucide-react';
import { Modal } from '../components/ui/Modal';

interface Producto {
    id: string;
    nombre: string;
    codigo_barra: string | null;
    precio_venta: number;
}

export function PrintBarcodes() {
    const [searchTerm, setSearchTerm] = useState('');
    const [products, setProducts] = useState<Producto[]>([]);
    const [loading, setLoading] = useState(false);
    const [selectedProducts, setSelectedProducts] = useState<Producto[]>([]);
    const [isPrintModalOpen, setIsPrintModalOpen] = useState(false);
    const [copiesPerProduct, setCopiesPerProduct] = useState(1);
    useEffect(() => {
        const timer = setTimeout(() => {
            fetchProducts();
        }, 500);
        return () => clearTimeout(timer);
    }, [searchTerm]);

    const fetchProducts = async () => {
        try {
            setLoading(true);
            let query = supabase
                .from('maestro_productos')
                .select('id, nombre, codigo_barra, precio_venta')
                .ilike('nombre', `%${searchTerm}%`)
                .limit(100);

            if (searchTerm.length >= 3) {
                query = query.or(`codigo_barra.ilike.%${searchTerm}%`);
            }

            const { data, error } = await query;

            if (error) throw error;
            setProducts(data || []);
        } catch {
            toast.error('Error al cargar productos');
            setProducts([]);
        } finally {
            setLoading(false);
        }
    };

    const toggleSelectProduct = (product: Producto) => {
        setSelectedProducts(prev => {
            const exists = prev.find(p => p.id === product.id);
            if (exists) {
                return prev.filter(p => p.id !== product.id);
            }
            return [...prev, product];
        });
    };

    const handlePrint = () => {
        if (selectedProducts.length === 0) {
            toast.error('Selecciona al menos un producto');
            return;
        }
        setIsPrintModalOpen(true);
    };

    const printLabels = () => {
        const printWindow = window.open('', '_blank');
        if (!printWindow) {
            toast.error('Permite las ventanas emergentes para imprimir');
            return;
        }

        let labelsHTML = '';
        selectedProducts.forEach(product => {
            for (let i = 0; i < copiesPerProduct; i++) {
                labelsHTML += `
                    <div class="label">
                        <div class="product-name">${product.nombre}</div>
                        <div class="barcode">${product.codigo_barra || 'S/C'}</div>
                        <div class="price">$${product.precio_venta.toLocaleString()}</div>
                        <div class="barcode-barcode">||| |||| || ||||| |||</div>
                    </div>
                `;
            }
        });

        printWindow.document.write(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Etiquetas de Códigos de Barra</title>
                <style>
                    @page {
                        size: auto;
                        margin: 10mm;
                    }
                    body {
                        font-family: Arial, sans-serif;
                        margin: 0;
                        padding: 0;
                    }
                    .container {
                        display: grid;
                        grid-template-columns: repeat(3, 1fr);
                        gap: 10px;
                        padding: 10px;
                    }
                    .label {
                        border: 1px solid #000;
                        padding: 10px;
                        text-align: center;
                        page-break-inside: avoid;
                    }
                    .product-name {
                        font-size: 12px;
                        font-weight: bold;
                        margin-bottom: 8px;
                        overflow: hidden;
                        text-overflow: ellipsis;
                        white-space: nowrap;
                    }
                    .barcode {
                        font-size: 14px;
                        font-family: 'Courier New', monospace;
                        font-weight: bold;
                        margin: 5px 0;
                        letter-spacing: 2px;
                    }
                    .price {
                        font-size: 16px;
                        font-weight: bold;
                        color: #000;
                        margin: 5px 0;
                    }
                    .barcode-barcode {
                        font-family: 'Libre Barcode 39', cursive;
                        font-size: 24px;
                        margin-top: 5px;
                    }
                    @media print {
                        body { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
                    }
                </style>
                <link href="https://fonts.googleapis.com/css2?family=Libre+Barcode+39&display=swap" rel="stylesheet">
            </head>
            <body>
                <div class="container">
                    ${labelsHTML}
                </div>
                <script>
                    window.onload = function() {
                        window.print();
                        window.close();
                    };
                </script>
            </body>
            </html>
        `);

        printWindow.document.close();
        toast.success('Enviando a impresión...');
        setIsPrintModalOpen(false);
    };

    return (
        <div className="p-6 bg-gray-50 min-h-screen">
            {/* Header */}
            <div className="mb-6 flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Imprimir Códigos de Barra</h1>
                    <p className="text-sm text-gray-500 mt-1">Selecciona productos e imprime etiquetas</p>
                </div>
                <button
                    onClick={handlePrint}
                    disabled={selectedProducts.length === 0}
                    className="flex items-center gap-2 px-6 py-3 bg-blue-600 text-white rounded-xl font-bold hover:bg-blue-700 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
                >
                    <Printer size={20} />
                    Imprimir ({selectedProducts.length})
                </button>
            </div>

            {/* Search */}
            <div className="mb-6">
                <div className="relative max-w-2xl">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
                    <input
                        type="text"
                        placeholder="Buscar producto por nombre o código..."
                        className="w-full pl-12 pr-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-blue-500 outline-none font-medium"
                        value={searchTerm}
                        onChange={e => setSearchTerm(e.target.value)}
                        autoFocus
                    />
                </div>
            </div>

            {/* Products Table */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
                <table className="w-full">
                    <thead className="bg-gray-50 border-b border-gray-200">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider w-12">
                                <input
                                    type="checkbox"
                                    checked={selectedProducts.length === products.length && products.length > 0}
                                    onChange={() => {
                                        if (selectedProducts.length === products.length) {
                                            setSelectedProducts([]);
                                        } else {
                                            setSelectedProducts(products);
                                        }
                                    }}
                                    className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                                />
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">
                                Producto
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">
                                Código de Barra
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">
                                Precio
                            </th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                        {products.map(product => (
                            <tr
                                key={product.id}
                                className={`hover:bg-gray-50 transition-colors ${
                                    selectedProducts.find(p => p.id === product.id) ? 'bg-blue-50' : ''
                                }`}
                            >
                                <td className="px-6 py-4">
                                    <input
                                        type="checkbox"
                                        checked={selectedProducts.find(p => p.id === product.id) !== undefined}
                                        onChange={() => toggleSelectProduct(product)}
                                        className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                                    />
                                </td>
                                <td className="px-6 py-4">
                                    <span className="text-sm font-medium text-gray-900">{product.nombre}</span>
                                </td>
                                <td className="px-6 py-4">
                                    <span className="text-sm font-mono text-gray-600">
                                        {product.codigo_barra || 'Sin código'}
                                    </span>
                                </td>
                                <td className="px-6 py-4">
                                    <span className="text-sm font-bold text-gray-900">
                                        ${product.precio_venta.toLocaleString()}
                                    </span>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>

                {products.length === 0 && !loading && (
                    <div className="text-center py-20 text-gray-400">
                        <BarChart3 size={48} className="mx-auto mb-4 opacity-30" />
                        <p className="font-medium">Busca productos para imprimir</p>
                    </div>
                )}
            </div>

            {/* Print Modal */}
            <Modal
                isOpen={isPrintModalOpen}
                onClose={() => setIsPrintModalOpen(false)}
                title="Configurar Impresión"
                size="md"
            >
                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-bold text-gray-700 mb-2">
                            Copias por producto
                        </label>
                        <input
                            type="number"
                            min="1"
                            max="10"
                            value={copiesPerProduct}
                            onChange={e => setCopiesPerProduct(parseInt(e.target.value) || 1)}
                            className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-blue-500 outline-none font-bold text-lg"
                        />
                    </div>

                    <div className="bg-gray-50 p-4 rounded-xl">
                        <p className="text-sm font-medium text-gray-700 mb-2">Resumen:</p>
                        <ul className="space-y-1 text-sm text-gray-600">
                            <li>Productos: {selectedProducts.length}</li>
                            <li>Copias por producto: {copiesPerProduct}</li>
                            <li className="font-bold text-gray-900">Total etiquetas: {selectedProducts.length * copiesPerProduct}</li>
                        </ul>
                    </div>

                    <div className="flex gap-3 pt-4">
                        <button
                            onClick={() => setIsPrintModalOpen(false)}
                            className="flex-1 px-4 py-3 bg-gray-100 text-gray-700 rounded-xl font-bold hover:bg-gray-200 transition-colors"
                        >
                            Cancelar
                        </button>
                        <button
                            onClick={printLabels}
                            className="flex-1 px-4 py-3 bg-blue-600 text-white rounded-xl font-bold hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                        >
                            <Printer size={18} />
                            Imprimir
                        </button>
                    </div>
                </div>
            </Modal>
        </div>
    );
}
