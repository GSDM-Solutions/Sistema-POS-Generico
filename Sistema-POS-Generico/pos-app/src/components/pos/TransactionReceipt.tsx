import { useRef, useMemo } from 'react';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';
import { Printer, X, FileText } from 'lucide-react';
import { Button } from '../ui/Button';
import bwipjs from 'bwip-js';
import { openPrintWindow } from '../../lib/printUtils';

interface ReceiptItem {
    nombre: string;
    cantidad: number;
    precio: number;
    unidad_medida?: string;
}

interface TransactionReceiptProps {
    isOpen: boolean;
    onClose: () => void;
    data: {
        folio: string;
        fecha: Date;
        total: number;
        items: ReceiptItem[];
        tipo_venta: 'BOLETA' | 'FACTURA' | 'FIADO' | 'TRANSFERENCIA';
        forma_pago_detalle?: string;
        cliente?: {
            nombre: string;
            rut: string;
            saldo_actual: number;
            giro?: string;
            direccion?: string;
        };
        usuario?: string;
        efectivo_recibido?: number;
        vuelto?: number;
        saldo_anterior?: number;
        nuevo_saldo?: number;
    };
}

export function TransactionReceipt({ isOpen, onClose, data }: TransactionReceiptProps) {
    const receiptRef = useRef<HTMLDivElement>(null);

    const barcodeData = useMemo(() => {
        const parts = [
            `FOLIO=${data.folio.slice(0, 8).toUpperCase()}`,
            `FECHA=${format(new Date(data.fecha), 'dd/MM/yyyy HH:mm')}`,
            `TOTAL=${data.total}`,
            data.cliente?.rut ? `RUT=${data.cliente.rut}` : null,
        ].filter(Boolean);
        return parts.join('|');
    }, [data]);

    const barcodeSvg = useMemo(() => {
        try {
            return bwipjs.toSVG({
                bcid: 'pdf417',
                text: barcodeData,
                scale: 2,
                height: 8,
                includetext: false,
                textxalign: 'center',
            });
        } catch {
            return '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="40"></svg>';
        }
    }, [barcodeData]);

    if (!isOpen) return null;

    const dateStr = format(new Date(data.fecha), 'dd/MM/yyyy HH:mm', { locale: es });

    const getTipoComprobante = () => {
        if (data.tipo_venta === 'FIADO') return 'COMPROBANTE DE DEUDA';
        if (data.tipo_venta === 'FACTURA') return 'FACTURA ELECTRONICA';
        return 'BOLETA ELECTRONICA';
    };

    const getFormaPago = () => {
        if (data.tipo_venta === 'FIADO') return 'CREDITO DIRECTO';
        if (data.tipo_venta === 'TRANSFERENCIA') return 'TRANSFERENCIA';
        if (data.efectivo_recibido !== undefined) return 'EFECTIVO';
        return 'TARJETA';
    };

    const neto = Math.round(data.total / 1.19);
    const iva = data.total - neto;

    const handlePrint = () => {
        const itemsHtml = data.items.map(item => `
            <tr>
                <td style="text-align: left; padding: 2px 0;">${item.cantidad}</td>
                <td style="text-align: left; padding: 2px 0;">${item.nombre}</td>
                <td style="text-align: right; padding: 2px 0;">$${(item.cantidad * item.precio).toLocaleString()}</td>
            </tr>
        `).join('');

        const html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Comprobante ${data.folio}</title>
    <style>
        @page {
            margin: 0;
            size: 80mm auto; /* Formato estándar 80mm */
        }
        body {
            font-family: 'Courier New', Courier, monospace;
            font-size: 12px;
            color: #000;
            margin: 0;
            padding: 2mm 5mm; /* Margen para guillotina */
            width: 80mm;
            box-sizing: border-box;
        }
        .text-center { text-align: center; }
        .text-right { text-align: right; }
        .font-bold { font-weight: bold; }
        .header { margin-bottom: 10px; }
        .header h1 { font-size: 16px; margin: 0; font-weight: 900; }
        .header p { font-size: 10px; margin: 0; }
        .divider { border-top: 1px dashed #000; margin: 5px 0; }
        .info { font-size: 11px; margin-bottom: 5px; }
        .info p { margin: 2px 0; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 5px; }
        th { font-size: 10px; border-bottom: 1px dashed #000; padding-bottom: 3px; text-align: left; }
        td { font-size: 11px; vertical-align: top; }
        .total-row { display: flex; justify-content: space-between; font-size: 14px; font-weight: bold; margin-top: 5px; border-top: 1px dashed #000; padding-top: 5px; }
        .footer { text-align: center; font-size: 10px; margin-top: 15px; margin-bottom: 15px; }
        .boleta-box { border: 1px solid #000; padding: 3px; margin: 5px 0; text-align: center; font-size: 11px; font-weight: bold;}
    </style>
</head>
<body>
    <div class="header text-center">
        <h1>GESTIÓN PRO</h1>
        <p>Librería & Ferretería</p>
    </div>
    
    <div class="text-center font-bold" style="margin-bottom: 10px; font-size: 13px;">
        ${getTipoComprobante()}
    </div>
    
    <div class="info">
        <p><strong>Folio:</strong> #${data.folio.slice(0, 8).toUpperCase()}</p>
        <p><strong>Fecha:</strong> ${dateStr}</p>
        ${data.usuario ? `<p><strong>Vendedor:</strong> ${data.usuario.split('@')[0].toUpperCase()}</p>` : ''}
        ${data.cliente ? `
            <div class="divider"></div>
            <p><strong>Cliente:</strong> ${data.cliente.nombre}</p>
            <p><strong>RUT:</strong> ${data.cliente.rut}</p>
        ` : ''}
    </div>

    ${data.forma_pago_detalle ? `
    <div class="boleta-box">
        Doc. Relacionado:<br>
        ${data.forma_pago_detalle}
    </div>
    ` : ''}

    ${data.tipo_venta === 'FIADO' && data.cliente ? `
    <div class="boleta-box">
        <strong>CR&Eacute;DITO DIRECTO</strong><br>
        Cliente: ${data.cliente.nombre}<br>
        RUT: ${data.cliente.rut}<br>
        Saldo Anterior: $${data.saldo_anterior?.toLocaleString() || data.cliente.saldo_actual.toLocaleString()}<br>
        Monto Cargado: $${data.total.toLocaleString()}<br>
        <strong>Nuevo Saldo Deudor:</strong> $${data.nuevo_saldo?.toLocaleString() || (data.cliente.saldo_actual + data.total).toLocaleString()}
    </div>
    ` : ''}

    ${data.efectivo_recibido !== undefined ? `
    <div class="boleta-box">
        FORMA DE PAGO: EFECTIVO<br>
        EFECTIVO RECIBIDO: $${data.efectivo_recibido.toLocaleString()}<br>
        VUELTO: $${(data.vuelto ?? 0).toLocaleString()}
    </div>
    ` : ''}
    
    ${data.tipo_venta === 'TRANSFERENCIA' ? `
    <div class="boleta-box">
        FORMA DE PAGO: TRANSFERENCIA<br>
        ${data.forma_pago_detalle || ''}
    </div>
    ` : ''}
    
    ${data.tipo_venta === 'BOLETA' && data.efectivo_recibido === undefined ? `
    <div class="boleta-box">
        FORMA DE PAGO: TARJETA
    </div>
    ` : ''}

    <div class="divider"></div>
    
    <table>
        <thead>
            <tr>
                <th style="width: 15%;">Cant</th>
                <th style="width: 55%;">Descripción</th>
                <th style="width: 30%; text-align: right;">Total</th>
            </tr>
        </thead>
        <tbody>
            ${itemsHtml}
        </tbody>
    </table>
    
    <div class="total-row">
        <div>
            <div style="display: flex; justify-content: space-between; font-size: 10px; margin-bottom: 2px;">
                <span>Subtotal:</span>
                <span>$${neto.toLocaleString()}</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size: 10px;">
                <span>IVA (19%):</span>
                <span>$${iva.toLocaleString()}</span>
            </div>
        </div>
    </div>
    <div class="total-row">
        <span>TOTAL:</span>
        <span>$${data.total.toLocaleString()}</span>
    </div>

    <div class="footer">
        <div style="margin-top: 10px; display: flex; justify-content: center;">
            ${barcodeSvg.replace(/width="[^"]*"/, 'width="180"').replace(/height="[^"]*"/, 'height="50"')}
        </div>
        <p style="font-size: 8px; font-weight: bold; margin-top: 2px;">Timbre Electronico SII</p>
        <p style="font-size: 8px; margin-top: 0;">Res. N 80 del 2014</p>
        <p style="margin-top: 10px; font-weight: bold;">&iexcl;GRACIAS POR SU COMPRA!</p>
        <p>${data.tipo_venta === 'FIADO' ? 'Reconozco la deuda por el total indicado.' : 'Conserve este ticket para cambios o devoluciones.'}</p>
        ${data.tipo_venta === 'FIADO' ? `
        <p style="margin-top: 20px; padding-top: 5px; border-top: 1px solid #000;">
            Firma Cliente: ____________________________
        </p>
        ` : ''}
    </div>
</body>
</html>
        `;

        openPrintWindow(html);
    };

    return (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 overflow-y-auto">
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm flex flex-col my-auto border border-gray-200">
                
                {/* Header UI */}
                <div className="p-4 border-b border-gray-100 flex justify-between items-center bg-gray-50 rounded-t-2xl">
                    <h3 className="font-bold text-gray-800 flex items-center gap-2">
                        <FileText size={18} className="text-blue-600" />
                        Comprobante Generado
                    </h3>
                    <button onClick={onClose} className="p-1.5 hover:bg-gray-200 rounded-full text-gray-500 transition-colors">
                        <X size={20} />
                    </button>
                </div>

                {/* Body Visual Receipt (80mm simulation) */}
                <div className="p-6 bg-gray-100 flex justify-center">
                    
                    {/* Contenedor simulando el papel de 80mm (aprox 300px ancho) */}
                    <div 
                        className="bg-white shadow-sm font-mono text-black overflow-hidden" 
                        style={{ width: '302px', padding: '15px 10px' }}
                    >
                        <div className="text-center mb-4 border-b-2 border-dashed border-gray-300 pb-3">
                            <h1 className="text-xl font-black">GESTIÓN<span className="text-emerald-600">PRO</span></h1>
                            <p className="text-[10px] text-gray-600">Librería & Ferretería</p>
                        </div>

                        <div className="text-center mb-3">
                            <p className="text-sm font-bold uppercase">{getTipoComprobante()}</p>
                        </div>

                        <div className="text-xs space-y-1 mb-4 leading-tight">
                            <div className="flex justify-between">
                                <span className="font-bold">Folio:</span>
                                <span>#{data.folio.slice(0, 8).toUpperCase()}</span>
                            </div>
                            <div className="flex justify-between">
                                <span className="font-bold">Fecha:</span>
                                <span>{dateStr}</span>
                            </div>
                            {data.usuario && (
                                <div className="flex justify-between">
                                    <span className="font-bold">Vendedor:</span>
                                    <span className="uppercase">{data.usuario.split('@')[0]}</span>
                                </div>
                            )}
                            
                            {data.cliente && (
                                <div className="mt-2 pt-2 border-t border-dashed border-gray-300">
                                    <div className="flex justify-between">
                                        <span className="font-bold">Cliente:</span>
                                        <span className="text-right truncate ml-2">{data.cliente.nombre}</span>
                                    </div>
                                    <div className="flex justify-between">
                                        <span className="font-bold">RUT:</span>
                                        <span>{data.cliente.rut}</span>
                                    </div>
                                </div>
                            )}
                        </div>

                        {data.forma_pago_detalle && (
                            <div className="border-2 border-black p-2 text-center text-xs font-bold mb-4 bg-gray-50">
                                Doc. Relacionado:<br/>
                                {data.forma_pago_detalle}
                            </div>
                        )}

                        {data.tipo_venta === 'FIADO' && data.cliente && (
                            <div className="border-2 border-black p-2 text-center text-xs mb-4 bg-blue-50">
                                <div className="font-bold mb-1">CREDITO DIRECTO</div>
                                <div>Cliente: {data.cliente.nombre}</div>
                                <div>RUT: {data.cliente.rut}</div>
                                <div className="mt-1 pt-1 border-t border-dashed border-gray-400">
                                    Saldo Anterior: ${data.saldo_anterior?.toLocaleString() || data.cliente.saldo_actual.toLocaleString()}
                                </div>
                                <div>Monto Cargado: ${data.total.toLocaleString()}</div>
                                <div className="font-bold">Nuevo Saldo Deudor: ${data.nuevo_saldo?.toLocaleString() || (data.cliente.saldo_actual + data.total).toLocaleString()}</div>
                            </div>
                        )}

                        {data.efectivo_recibido !== undefined && (
                            <div className="border-2 border-black p-2 text-center text-xs mb-4 bg-emerald-50">
                                <div className="font-bold mb-1">FORMA DE PAGO: EFECTIVO</div>
                                <div>Efectivo Recibido: ${data.efectivo_recibido.toLocaleString()}</div>
                                <div className="font-bold">Vuelto: ${(data.vuelto ?? 0).toLocaleString()}</div>
                            </div>
                        )}

                        <div className="border-t border-dashed border-gray-400 mt-2 pt-2 mb-2">
                            <div className="flex text-[10px] font-bold pb-1 border-b border-dashed border-gray-400">
                                <div className="w-8">Cant</div>
                                <div className="flex-1">Desc</div>
                                <div className="w-16 text-right">Total</div>
                            </div>
                            
                            <div className="mt-1 space-y-1">
                                {data.items.map((item, idx) => (
                                    <div key={idx} className="flex text-xs items-start">
                                        <div className="w-8 pt-0.5">{item.cantidad}</div>
                                        <div className="flex-1 pr-1 leading-tight">{item.nombre}</div>
                                        <div className="w-16 text-right pt-0.5">${(item.cantidad * item.precio).toLocaleString()}</div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="border-t-2 border-black mt-3 pt-2 space-y-1">
                            <div className="flex justify-between text-[10px] text-gray-600">
                                <span>Subtotal</span>
                                <span>${neto.toLocaleString()}</span>
                            </div>
                            <div className="flex justify-between text-[10px] text-gray-600">
                                <span>IVA (19%)</span>
                                <span>${iva.toLocaleString()}</span>
                            </div>
                            <div className="flex justify-between items-end pt-1 border-t border-dashed border-gray-300">
                                <span className="text-sm font-bold">TOTAL</span>
                                <span className="text-xl font-black">${data.total.toLocaleString()}</span>
                            </div>
                        </div>

                        {/* Timbre Electronico SII */}
                        <div className="flex flex-col items-center mt-6">
                            <div
                                className="flex justify-center"
                                dangerouslySetInnerHTML={{ __html: barcodeSvg.replace(/width="[^"]*"/, 'width="180"').replace(/height="[^"]*"/, 'height="50"') }}
                            />
                            <p className="text-[9px] font-bold mt-1 uppercase text-black">Timbre Electronico SII</p>
                            <p className="text-[9px] text-black">Res. N 80 del 2014</p>
                        </div>

                        <div className="text-center mt-4 text-[10px] text-gray-500">
                            <p className="font-bold text-black text-xs mb-1">¡GRACIAS POR SU COMPRA!</p>
                            <p>{data.tipo_venta === 'FIADO' ? 'Reconozco la deuda por el total indicado.' : 'Conserve este ticket para cambios o devoluciones.'}</p>
                            {data.tipo_venta === 'FIADO' && (
                                <div className="mt-4 pt-3 border-t border-black">
                                    <p className="text-black font-bold text-[11px]">Firma Cliente: ____________________________</p>
                                </div>
                            )}
                        </div>
                    </div>
                </div>

                {/* Footer UI */}
                <div className="p-4 bg-white rounded-b-2xl flex gap-3">
                    <Button variant="secondary" onClick={onClose} className="flex-1 py-3">Cerrar</Button>
                    <Button onClick={handlePrint} className="flex-1 py-3 bg-blue-600 hover:bg-blue-700">
                        <Printer className="w-5 h-5 mr-2" />
                        Imprimir Ticket
                    </Button>
                </div>
            </div>
        </div>
    );
}
