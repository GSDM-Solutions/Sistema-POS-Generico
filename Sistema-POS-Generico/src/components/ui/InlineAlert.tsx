/* eslint-disable react-refresh/only-export-components */
import { Check, AlertTriangle, Info, X as XIcon } from 'lucide-react';
import { useEffect, useState } from 'react';

interface InlineAlertProps {
    type: 'success' | 'error' | 'warning' | 'info';
    message: string;
    show: boolean;
    onClose?: () => void;
    autoClose?: boolean;
    duration?: number;
}

export function InlineAlert({
    type,
    message,
    show,
    onClose,
    autoClose = true,
    duration = 3000
}: InlineAlertProps) {
    const [visible, setVisible] = useState(show);

    useEffect(() => {
        setVisible(show);

        if (show && autoClose) {
            const timer = setTimeout(() => {
                setVisible(false);
                onClose?.();
            }, duration);

            return () => clearTimeout(timer);
        }
    }, [show, autoClose, duration, onClose]);

    if (!visible) return null;

    const config = {
        success: {
            bg: 'bg-green-50 border-green-200',
            text: 'text-green-800',
            icon: Check,
            iconColor: 'text-green-600'
        },
        error: {
            bg: 'bg-red-50 border-red-200',
            text: 'text-red-800',
            icon: XIcon,
            iconColor: 'text-red-600'
        },
        warning: {
            bg: 'bg-yellow-50 border-yellow-200',
            text: 'text-yellow-800',
            icon: AlertTriangle,
            iconColor: 'text-yellow-600'
        },
        info: {
            bg: 'bg-blue-50 border-blue-200',
            text: 'text-blue-800',
            icon: Info,
            iconColor: 'text-blue-600'
        }
    };

    const { bg, text, icon: Icon, iconColor } = config[type];

    return (
        <div className={`flex items-center gap-3 p-4 rounded-xl border-2 ${bg} ${text} animate-in slide-in-from-top-2 duration-300`}>
            <Icon className={`flex-shrink-0 ${iconColor}`} size={20} />
            <p className="flex-1 font-medium">{message}</p>
            {onClose && (
                <button
                    onClick={() => {
                        setVisible(false);
                        onClose();
                    }}
                    className="flex-shrink-0 p-1 hover:bg-black/10 rounded-full transition-colors"
                >
                    <XIcon size={16} />
                </button>
            )}
        </div>
    );
}

// Hook para manejar alerts inline fácilmente
export function useInlineAlert() {
    const [alert, setAlert] = useState<{
        type: 'success' | 'error' | 'warning' | 'info';
        message: string;
        show: boolean;
    }>({
        type: 'info',
        message: '',
        show: false
    });

    const showAlert = (
        type: 'success' | 'error' | 'warning' | 'info',
        message: string
    ) => {
        setAlert({ type, message, show: true });
    };

    const hideAlert = () => {
        setAlert(prev => ({ ...prev, show: false }));
    };

    return { alert, showAlert, hideAlert };
}
