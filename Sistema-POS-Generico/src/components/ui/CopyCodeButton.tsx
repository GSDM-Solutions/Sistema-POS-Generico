import { Copy, Check } from 'lucide-react';
import { useState } from 'react';
import toast from 'react-hot-toast';

interface CopyCodeButtonProps {
    code: string;
    className?: string;
}

export function CopyCodeButton({ code, className = '' }: CopyCodeButtonProps) {
    const [copied, setCopied] = useState(false);

    const handleCopy = async () => {
        try {
            await navigator.clipboard.writeText(code);
            setCopied(true);
            toast.success('¡Código copiado!', { icon: '📋', duration: 2000 });

            setTimeout(() => {
                setCopied(false);
            }, 2000);
        } catch {
            toast.error('Error al copiar');
        }
    };

    return (
        <button
            onClick={handleCopy}
            className={`flex items-center gap-2 px-3 py-2 rounded-lg font-mono font-bold text-sm transition-all ${copied
                    ? 'bg-green-100 text-green-700 border-2 border-green-300'
                    : 'bg-blue-50 hover:bg-blue-100 text-blue-700 border-2 border-blue-200 hover:border-blue-300'
                } ${className}`}
        >
            <span>{code}</span>
            {copied ? (
                <Check size={16} className="text-green-600" />
            ) : (
                <Copy size={16} />
            )}
        </button>
    );
}
