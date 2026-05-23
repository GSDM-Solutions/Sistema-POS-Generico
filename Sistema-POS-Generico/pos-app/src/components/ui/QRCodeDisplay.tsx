import { QRCodeSVG } from 'qrcode.react';
import { Download, Printer } from 'lucide-react';

interface QRCodeDisplayProps {
    value: string;
    size?: number;
    title?: string;
    subtitle?: string;
    showDownload?: boolean;
    showPrint?: boolean;
    showValue?: boolean;
}

export function QRCodeDisplay({
    value,
    size = 200,
    title,
    subtitle,
    showDownload = true,
    showPrint = true,
    showValue = true
}: QRCodeDisplayProps) {
    const handleDownload = () => {
        const svg = document.getElementById('qr-code-svg');
        if (!svg) return;

        const svgData = new XMLSerializer().serializeToString(svg);
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        const img = new Image();

        canvas.width = size;
        canvas.height = size;

        img.onload = () => {
            ctx?.drawImage(img, 0, 0);
            const pngFile = canvas.toDataURL('image/png');

            const downloadLink = document.createElement('a');
            downloadLink.download = `QR-${value}.png`;
            downloadLink.href = pngFile;
            downloadLink.click();
        };

        img.src = 'data:image/svg+xml;base64,' + btoa(svgData);
    };

    const handlePrint = () => {
        const printWindow = window.open('', '_blank');
        if (!printWindow) return;

        const svg = document.getElementById('qr-code-svg');
        if (!svg) return;

        printWindow.document.write(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Imprimir QR - ${value}</title>
                <style>
                    body {
                        display: flex;
                        flex-direction: column;
                        align-items: center;
                        justify-content: center;
                        min-height: 100vh;
                        margin: 0;
                        font-family: system-ui, -apple-system, sans-serif;
                    }
                    .container {
                        text-align: center;
                        padding: 40px;
                    }
                    h1 {
                        font-size: 24px;
                        margin-bottom: 8px;
                        color: #1f2937;
                    }
                    p {
                        font-size: 16px;
                        color: #6b7280;
                        margin-bottom: 24px;
                    }
                    .qr-container {
                        display: inline-block;
                        padding: 20px;
                        background: white;
                        border: 2px solid #e5e7eb;
                        border-radius: 12px;
                    }
                    @media print {
                        @page {
                            margin: 20mm;
                        }
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    ${title ? `<h1>${title}</h1>` : ''}
                    ${subtitle ? `<p>${subtitle}</p>` : ''}
                    <div class="qr-container">
                        ${svg.outerHTML}
                    </div>
                    <p style="margin-top: 24px; font-family: monospace; font-weight: bold; font-size: 18px;">
                        ${value}
                    </p>
                </div>
            </body>
            </html>
        `);

        printWindow.document.close();
        setTimeout(() => {
            printWindow.print();
        }, 250);
    };

    return (
        <div className="flex flex-col items-center gap-4 p-6 bg-white rounded-2xl border-2 border-gray-200">
            {title && (
                <div className="text-center">
                    <h3 className="text-xl font-bold text-gray-900">{title}</h3>
                    {subtitle && <p className="text-sm text-gray-600 mt-1">{subtitle}</p>}
                </div>
            )}

            <div className="p-4 bg-white border-2 border-gray-300 rounded-xl">
                <QRCodeSVG
                    id="qr-code-svg"
                    value={value}
                    size={size}
                    level="H"
                    includeMargin
                />
            </div>

            {showValue && (
                <div className="text-center">
                    <p className="font-mono font-bold text-lg text-gray-900">{value}</p>
                </div>
            )}

            {(showDownload || showPrint) && (
                <div className="flex gap-2">
                    {showDownload && (
                        <button
                            onClick={handleDownload}
                            className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
                        >
                            <Download size={16} />
                            Descargar
                        </button>
                    )}
                    {showPrint && (
                        <button
                            onClick={handlePrint}
                            className="flex items-center gap-2 px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg font-semibold transition-colors"
                        >
                            <Printer size={16} />
                            Imprimir
                        </button>
                    )}
                </div>
            )}
        </div>
    );
}
