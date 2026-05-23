import { Sun, Moon, Monitor } from 'lucide-react';
import { useTheme } from '../../contexts/ThemeContext';

export function ThemeToggle() {
    const { theme, setTheme } = useTheme();

    const themes = [
        { value: 'light' as const, icon: Sun, label: 'Claro' },
        { value: 'dark' as const, icon: Moon, label: 'Oscuro' },
        { value: 'system' as const, icon: Monitor, label: 'Sistema' }
    ];

    return (
        <div className="flex items-center gap-1 p-1 bg-gray-100 dark:bg-gray-800 rounded-lg">
            {themes.map(({ value, icon: Icon, label }) => (
                <button
                    key={value}
                    onClick={() => setTheme(value)}
                    className={`flex items-center gap-2 px-3 py-2 rounded-md font-medium text-sm transition-all ${theme === value
                            ? 'bg-white dark:bg-gray-700 text-blue-600 dark:text-blue-400 shadow-sm'
                            : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                        }`}
                    title={label}
                >
                    <Icon size={16} />
                    <span className="hidden sm:inline">{label}</span>
                </button>
            ))}
        </div>
    );
}

// Versión compacta (solo icono)
export function ThemeToggleCompact() {
    const { actualTheme, toggleTheme } = useTheme();

    return (
        <button
            onClick={toggleTheme}
            className="p-2 rounded-lg bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
            title={`Cambiar a tema ${actualTheme === 'light' ? 'oscuro' : 'claro'}`}
        >
            {actualTheme === 'light' ? (
                <Moon size={20} className="text-gray-700 dark:text-gray-300" />
            ) : (
                <Sun size={20} className="text-yellow-500" />
            )}
        </button>
    );
}
