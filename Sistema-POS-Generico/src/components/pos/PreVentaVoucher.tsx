import { useRef } from 'react';
import { PreVenta } from '../../types/preventas';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';
import { Printer, X } from 'lucide-react';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';
import { QRCodeDisplay } from '../ui/QRCodeDisplay';
import { openPrintWindow } from '../../lib/printUtils';

interface PreVentaVoucherProps {
    preVenta: PreVenta;
    isOpen: boolean;
    onClose: () => void;
}

export function PreVentaVoucher({ preVenta, isOpen, onClose }: PreVentaVoucherProps) {
    const printRef = useRef<HTMLDivElement>(null);

    const handlePrint = () => {
        const printContent = printRef.current;
        if (!printContent) return;

        openPrintWindow(`
      <html>
        <head>
          <title>Pre-Venta ${preVenta.codigo_preventa}</title>
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
              font-family: 'Courier New', monospace;
              padding: 20px;
              font-size: 12px;
            }
            .voucher {
              max-width: 300px;
              margin: 0 auto;
              border: 2px dashed #000;
              padding: 15px;
            }
            .header {
              text-align: center;
              border-bottom: 2px solid #000;
              padding-bottom: 10px;
              margin-bottom: 10px;
            }
            .codigo {
              font-size: 24px;
              font-weight: bold;
              letter-spacing: 2px;
              margin: 10px 0;
            }
            .barcode {
              font-family: 'Libre Barcode 128', cursive;
              font-size: 48px;
              text-align: center;
              margin: 10px 0;
            }
            .info { margin: 5px 0; }
            .items {
              border-top: 1px dashed #000;
              border-bottom: 1px dashed #000;
              padding: 10px 0;
              margin: 10px 0;
            }
            .item {
              display: flex;
              justify-content: space-between;
              margin: 3px 0;
            }
            .total {
              font-size: 18px;
              font-weight: bold;
              text-align: right;
              margin-top: 10px;
            }
            .footer {
              text-align: center;
              margin-top: 15px;
              font-size: 10px;
              border-top: 1px solid #000;
              padding-top: 10px;
            }
            @media print {
              body { padding: 0; }
              .voucher { border: none; }
            }
          </style>
        </head>
        <body>
          ${printContent.innerHTML}
        </body>
      </html>
    `);
    };

    return (
        <Modal isOpen={isOpen} onClose={onClose} title="Voucher de Pre-Venta" size="md">
            <div className="space-y-4">
                {/* Vista Previa */}
                <div ref={printRef} className="bg-white p-6 border-2 border-dashed border-gray-300 rounded-lg">
                    <div className="voucher max-w-sm mx-auto">
                        {/* Header */}
                        <div className="header text-center border-b-2 border-black pb-3 mb-3">
                            <h1 className="text-xl font-bold">GESTIÓN<span className="text-emerald-600">PRO</span></h1>
                            <p className="text-xs text-gray-600">Librería & Ferretería</p>
                        </div>

                        {/* Código */}
                        {/* Código */}
                        <div className="text-center my-4 flex flex-col items-center">
                            <p className="text-sm text-gray-600 mb-2 font-bold uppercase">Escanee en Caja</p>

                            <div className="mb-3">
                                <QRCodeDisplay
                                    value={preVenta.codigo_preventa || ''}
                                    size={150}
                                    showDownload={false}
                                    showPrint={false}
                                />
                            </div>

                            <p className="text-xs text-gray-500 mb-1">O digite el código:</p>
                            <div className="codigo text-3xl font-black tracking-widest my-1 border-2 border-black px-4 py-2 rounded-lg bg-gray-50">
                                {preVenta.codigo_preventa}
                            </div>
                        </div>

                        {/* Info */}
                        <div className="info space-y-1 text-sm">
                            <div className="flex justify-between">
                                <span className="text-gray-600">Fecha:</span>
                                <span className="font-semibold">
                                    {format(new Date(preVenta.created_at), 'dd/MM/yyyy HH:mm', { locale: es })}
                                </span>
                            </div>
                            <div className="flex justify-between">
                                <span className="text-gray-600">Vendedor:</span>
                                <span className="font-semibold">{preVenta.vendedor_nombre}</span>
                            </div>
                            {preVenta.cliente_nombre && (
                                <div className="flex justify-between">
                                    <span className="text-gray-600">Cliente:</span>
                                    <span className="font-semibold">{preVenta.cliente_nombre}</span>
                                </div>
                            )}
                        </div>

                        {/* Items */}
                        <div className="items border-t border-b border-dashed border-gray-400 py-3 my-3">
                            <div className="flex text-[10px] uppercase font-bold text-gray-500 mb-2 pb-1 border-b border-gray-200">
                                <div className="w-10 text-center">Cant</div>
                                <div className="w-10 text-center">Und</div>
                                <div className="flex-1">Descripción</div>
                                <div className="w-16 text-right">Total</div>
                            </div>

                            {preVenta.items.map((item, idx) => (
                                <div key={idx} className="flex text-xs py-1.5 border-b border-gray-100 last:border-0 items-start">
                                    <div className="w-10 text-center font-bold text-gray-900">{item.cantidad}</div>
                                    <div className="w-10 text-center text-[10px] font-medium text-gray-500 mt-0.5">
                                        {item.unidad_medida || 'UN'}
                                    </div>
                                    <div className="flex-1 text-gray-800 leading-tight pr-1">
                                        {item.nombre}
                                    </div>
                                    <div className="w-16 text-right font-bold text-gray-900">
                                        ${(item.cantidad * item.precio).toLocaleString()}
                                    </div>
                                </div>
                            ))}
                        </div>

                        {/* Total */}
                        <div className="total text-right text-2xl font-black">
                            TOTAL: ${preVenta.total.toLocaleString()}
                        </div>

                        {/* Notas */}
                        {preVenta.notas_vendedor && (
                            <div className="mt-3 p-2 bg-gray-100 rounded text-xs">
                                <strong>Nota:</strong> {preVenta.notas_vendedor}
                            </div>
                        )}

                        {/* Footer */}
                        <div className="footer text-center mt-4 pt-3 border-t border-gray-400 text-xs text-gray-600">
                            <p className="font-bold mb-1">PRESENTE ESTE VOUCHER EN CAJA</p>
                            <p>El cajero ingresará el código para procesar su pago</p>
                            <p className="mt-2 text-[10px]">
                                Válido solo para hoy • No es un comprobante de pago
                            </p>
                        </div>
                    </div>
                </div>

                {/* Botones */}
                <div className="flex gap-3">
                    <Button variant="secondary" onClick={onClose} className="flex-1">
                        <X size={16} className="mr-2" />
                        Cerrar
                    </Button>
                    <Button onClick={handlePrint} className="flex-1">
                        <Printer size={16} className="mr-2" />
                        Imprimir Voucher
                    </Button>
                </div>

                {/* Instrucciones */}
                <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                    <p className="text-sm text-blue-900 font-semibold mb-2">📋 Instrucciones:</p>
                    <ol className="text-sm text-blue-800 space-y-1 list-decimal list-inside">
                        <li>Imprime este voucher y entrégalo al cliente</li>
                        <li>El cliente presenta el voucher en caja</li>
                        <li>El cajero ingresa el código <strong>{preVenta.codigo_preventa}</strong> en el POS</li>
                        <li>El sistema carga automáticamente los productos</li>
                        <li>El cajero procesa el pago</li>
                    </ol>
                </div>
            </div>
        </Modal>
    );
}
