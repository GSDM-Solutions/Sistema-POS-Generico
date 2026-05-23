import React from 'react';
import { Trophy } from 'lucide-react';

interface TopProduct {
    nombre: string;
    total_vendido: number;
    total_ingreso: number;
}

interface TopProductsListProps {
    products: TopProduct[];
}

export function TopProductsList({ products }: TopProductsListProps) {
    if (!products || products.length === 0) {
        return (
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 h-full flex flex-col justify-center items-center text-gray-400">
                <Trophy size={48} className="mb-3 opacity-20" />
                <p>No hay datos de ventas este mes</p>
            </div>
        );
    }

    return (
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
            <h3 className="font-bold text-gray-800 mb-6 flex items-center gap-2">
                <div className="p-2 bg-yellow-100 text-yellow-600 rounded-lg">
                    <Trophy size={20} />
                </div>
                Top Ventas (Mes Actual)
            </h3>
            <div className="space-y-4">
                {products.map((product, index) => (
                    <div key={index} className="flex items-center justify-between p-3 hover:bg-gray-50 rounded-xl transition-colors">
                        <div className="flex items-center gap-4">
                            <span className={`
                flex items-center justify-center w-8 h-8 rounded-full font-bold text-sm
                ${index === 0 ? 'bg-yellow-100 text-yellow-700' :
                                    index === 1 ? 'bg-gray-100 text-gray-700' :
                                        index === 2 ? 'bg-orange-100 text-orange-700' : 'bg-slate-50 text-slate-500'}
              `}>
                                {index + 1}
                            </span>
                            <div>
                                <p className="font-semibold text-gray-800 text-sm">{product.nombre}</p>
                                <p className="text-xs text-gray-500 flex items-center gap-1">
                                    {product.total_vendido} unidades
                                </p>
                            </div>
                        </div>
                        <div className="text-right">
                            <p className="font-bold text-emerald-600 text-sm">
                                ${product.total_ingreso.toLocaleString()}
                            </p>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}
