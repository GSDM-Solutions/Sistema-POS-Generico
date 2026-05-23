import { AlertTriangle } from 'lucide-react';
import { Modal } from './Modal';
import { Button } from './Button';

interface ConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  variant?: 'danger' | 'warning' | 'info';
  isLoading?: boolean;
}

const variantStyles = {
  danger: {
    icon: 'text-red-600 bg-red-100',
    button: 'bg-red-600 hover:bg-red-700 focus:ring-red-500',
  },
  warning: {
    icon: 'text-yellow-600 bg-yellow-100',
    button: 'bg-yellow-600 hover:bg-yellow-700 focus:ring-yellow-500',
  },
  info: {
    icon: 'text-blue-600 bg-blue-100',
    button: 'bg-blue-600 hover:bg-blue-700 focus:ring-blue-500',
  },
};

export function ConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = 'Confirmar',
  cancelText = 'Cancelar',
  variant = 'warning',
  isLoading = false,
}: ConfirmModalProps) {
  const styles = variantStyles[variant];

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={title} size="sm">
      <div className="space-y-4">
        <div className="flex items-start gap-3">
          <div className={`p-2 rounded-full flex-shrink-0 ${styles.icon}`}>
            <AlertTriangle className="h-5 w-5" />
          </div>
          <p className="text-sm text-gray-600">{message}</p>
        </div>

        <div className="flex justify-end gap-3 pt-2">
          <Button
            variant="secondary"
            onClick={onClose}
            disabled={isLoading}
          >
            {cancelText}
          </Button>
          <Button
            onClick={onConfirm}
            isLoading={isLoading}
            className={styles.button}
          >
            {confirmText}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
