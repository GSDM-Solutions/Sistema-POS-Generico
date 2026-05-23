import React, { useEffect, useRef } from 'react';
import JsBarcode from 'jsbarcode';
import toast from 'react-hot-toast';
import { X, Printer } from 'lucide-react';
import { Button } from '../ui/Button';
import { openPrintWindow } from '../../lib/printUtils';

interface LabelItem {
    id: string;
    nombre: string;
    lote: string;
    vencimiento: string;
    codigo_barra?: string;
    cantidad: number; // Number of labels to print
}

interface LabelPrinterProps {
    items: LabelItem[];
    isOpen: boolean;
    onClose: () => void;
}

export function LabelPrinter({ items, isOpen, onClose }: LabelPrinterProps) {
    const componentRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (isOpen && items.length > 0) {
            // Generate barcodes after render
            items.forEach(item => {
                try {
                    const selector = `#barcode-${item.id}`;
                    const element = document.querySelector(selector);
                    if (element && item.lote) { // Use Lote as barcode for internal tracking, or product barcode? 
                        // Usually internal tracking uses Lote or a specific ID. 
                        // If we have a product barcode, we print that. If not, we generate one for the Lote.
                        // Let's use Lote for now as it's the unique internal identifier for this batch.
                        JsBarcode(selector, item.lote, {
                            format: "CODE128",
                            width: 1.5,
                            height: 40,
                            displayValue: true,
                            fontSize: 12
                        });
                    }
                } catch {
                    toast.error("Error al generar el código de barras");
                }
            });
        }
    }, [isOpen, items]);

    if (!isOpen) return null;

    const handlePrint = () => {
        const printContent = componentRef.current;
        if (!printContent) return;

        const printHTML = `
            <html>
            <head>
                <title>Imprimir Etiquetas</title>
                <style>
                    body { font-family: sans-serif; }
                    .label-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
                    .label-card { border: 1px dashed #ccc; padding: 10px; text-align: center; page-break-inside: avoid; }
                    .label-name { font-size: 12px; font-weight: bold; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
                    .label-meta { font-size: 10px; color: #666; }
                    @media print {
                        .label-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
                        .label-card { border: 1px solid #000; }
                    }
                </style>
            </head>
            <body>
                ${printContent.innerHTML}
            </body>
            </html>
        `;

        openPrintWindow(printHTML);
    };

    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-4xl flex flex-col max-h-[90vh]">
                <div className="p-4 border-b border-gray-100 flex justify-between items-center">
                    <h3 className="font-bold text-lg">Vista Previa de Etiquetas</h3>
                    <button onClick={onClose}><X size={20} /></button>
                </div>

                <div className="flex-1 overflow-y-auto p-6 bg-gray-50" ref={componentRef}>
                    <div className="label-grid grid grid-cols-3 gap-4">
                        {items.flatMap(item =>
                            Array.from({ length: item.cantidad }).map((_, idx) => (
                                <div key={`${item.id}-${idx}`} className="label-card bg-white p-4 rounded-lg shadow-sm border border-gray-200 flex flex-col items-center justify-center h-48">
                                    <div className="label-name mb-2 w-full text-center">{item.nombre}</div>
                                    <svg id={`barcode-${item.id}`} className="mb-2"></svg>
                                    <div className="label-meta">
                                        <div>Lote: {item.lote}</div>
                                        <div>Venc: {item.vencimiento}</div>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>

                <div className="p-4 border-t border-gray-100 flex justify-end gap-3">
                    <Button variant="secondary" onClick={onClose}>Cerrar</Button>
                    <Button onClick={handlePrint}>
                        <Printer size={18} className="mr-2" />
                        Imprimir
                    </Button>
                </div>
            </div>
        </div>
    );
}
