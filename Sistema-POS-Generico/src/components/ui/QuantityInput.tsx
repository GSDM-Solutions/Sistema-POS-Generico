import { Minus, Plus, Scale, Package, Ruler, Droplet } from 'lucide-react';

interface QuantityInputProps {
    value: number;
    unidad: string;
    onChange: (value: number) => void;
    onIncrement: () => void;
    onDecrement: () => void;
    min?: number;
    className?: string;
}

const UNIDAD_CONFIG: Record<string, { icon: React.ComponentType<{ size?: number }>; color: string; label: string }> = {
    UN: { icon: Package, color: 'bg-blue-100 text-blue-700 border-blue-200', label: 'Unidad' },
    KG: { icon: Scale, color: 'bg-green-100 text-green-700 border-green-200', label: 'Kilogramo' },
    MTRS: { icon: Ruler, color: 'bg-purple-100 text-purple-700 border-purple-200', label: 'Metro' },
    LTS: { icon: Droplet, color: 'bg-cyan-100 text-cyan-700 border-cyan-200', label: 'Litro' },
    GR: { icon: Scale, color: 'bg-emerald-100 text-emerald-700 border-emerald-200', label: 'Gramo' },
    ML: { icon: Droplet, color: 'bg-teal-100 text-teal-700 border-teal-200', label: 'Mililitro' }
};

export function QuantityInput({
    value,
    unidad,
    onChange,
    onIncrement,
    onDecrement,
    min,
    className = ''
}: QuantityInputProps) {
    const config = UNIDAD_CONFIG[unidad] || UNIDAD_CONFIG.UN;
    const Icon = config.icon;
    const permiteDecimales = unidad !== 'UN';

    const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        let val = parseFloat(e.target.value) || 0;

        if (!permiteDecimales) {
            val = Math.floor(val);
            if (val < 1) val = 1;
        } else {
            val = Math.round(val * 100) / 100;
            if (val < 0.01) val = 0.01;
        }

        onChange(val);
    };

    const handleBlur = (e: React.FocusEvent<HTMLInputElement>) => {
        let val = parseFloat(e.target.value) || 0;
        if (!permiteDecimales) {
            val = Math.max(min || 1, Math.floor(val));
        } else {
            val = Math.max(min || 0.01, Math.round(val * 100) / 100);
        }
        onChange(val);
    };

    return (
        <div className={`flex items-center gap-2 ${className}`}>
            {/* Botón Decrementar */}
            <button
                type="button"
                onClick={onDecrement}
                className="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors border border-gray-200"
            >
                <Minus size={16} />
            </button>

            {/* Input + Badge de Unidad */}
            <div className="flex items-center bg-white border-2 border-gray-200 rounded-lg overflow-hidden focus-within:border-blue-500 transition-colors">
                <input
                    type="number"
                    step={permiteDecimales ? '0.01' : '1'}
                    min={permiteDecimales ? '0.01' : '1'}
                    value={value}
                    onChange={handleChange}
                    onBlur={handleBlur}
                    className="w-16 px-3 py-2 text-center font-bold text-gray-900 border-none outline-none [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                />
                <div className={`flex items-center gap-1 px-2 py-2 border-l-2 ${config.color}`}>
                    <Icon size={14} />
                    <span className="font-bold text-xs">{unidad}</span>
                </div>
            </div>

            {/* Botón Incrementar */}
            <button
                type="button"
                onClick={onIncrement}
                className="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-blue-500 hover:bg-blue-50 rounded-lg transition-colors border border-gray-200"
            >
                <Plus size={16} />
            </button>
        </div>
    );
}
