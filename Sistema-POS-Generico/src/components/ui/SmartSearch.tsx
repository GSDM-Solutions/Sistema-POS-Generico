import { Search, X, Package, Barcode } from 'lucide-react';
import { useState, useRef, useEffect } from 'react';

interface SearchResult {
    id: string;
    nombre: string;
    codigo_barra: string | null;
    precio: number;
    stock: number;
    unidad: string;
}

interface SmartSearchProps {
    onSearch: (query: string) => void;
    onSelect?: (result: SearchResult) => void;
    results?: SearchResult[];
    placeholder?: string;
    autoFocus?: boolean;
}

export function SmartSearch({
    onSearch,
    onSelect,
    results = [],
    placeholder = 'Buscar producto por nombre o código...',
    autoFocus = false
}: SmartSearchProps) {
    const [query, setQuery] = useState('');
    const [showSuggestions, setShowSuggestions] = useState(false);
    const [selectedIndex, setSelectedIndex] = useState(-1);
    const inputRef = useRef<HTMLInputElement>(null);
    const suggestionsRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (autoFocus && inputRef.current) {
            inputRef.current.focus();
        }
    }, [autoFocus]);

    useEffect(() => {
        const timer = setTimeout(() => {
            if (query.length > 0) {
                onSearch(query);
                setShowSuggestions(true);
            } else {
                setShowSuggestions(false);
            }
        }, 300);

        return () => clearTimeout(timer);
    }, [query, onSearch]);

    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (!showSuggestions || results.length === 0) return;

        switch (e.key) {
            case 'ArrowDown':
                e.preventDefault();
                setSelectedIndex(prev =>
                    prev < results.length - 1 ? prev + 1 : prev
                );
                break;
            case 'ArrowUp':
                e.preventDefault();
                setSelectedIndex(prev => prev > 0 ? prev - 1 : -1);
                break;
            case 'Enter':
                e.preventDefault();
                if (selectedIndex >= 0 && results[selectedIndex]) {
                    handleSelect(results[selectedIndex]);
                }
                break;
            case 'Escape':
                setShowSuggestions(false);
                setSelectedIndex(-1);
                break;
        }
    };

    const handleSelect = (result: SearchResult) => {
        if (onSelect) {
            onSelect(result);
        }
        setQuery('');
        setShowSuggestions(false);
        setSelectedIndex(-1);
        inputRef.current?.focus();
    };

    const highlightMatch = (text: string, query: string) => {
        if (!query) return text;

        const parts = text.split(new RegExp(`(${query})`, 'gi'));
        return parts.map((part, i) =>
            part.toLowerCase() === query.toLowerCase()
                ? <mark key={i} className="bg-yellow-200 text-gray-900 font-bold">{part}</mark>
                : part
        );
    };

    return (
        <div className="relative">
            {/* Input de Búsqueda */}
            <div className="relative">
                <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
                <input
                    ref={inputRef}
                    type="text"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    onKeyDown={handleKeyDown}
                    onFocus={() => query && setShowSuggestions(true)}
                    placeholder={placeholder}
                    className="w-full pl-12 pr-10 py-3 rounded-xl bg-gray-50 border-2 border-transparent focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10 transition-all font-medium text-gray-900 placeholder-gray-400"
                />
                {query && (
                    <button
                        onClick={() => {
                            setQuery('');
                            setShowSuggestions(false);
                            inputRef.current?.focus();
                        }}
                        className="absolute right-3 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-200 rounded-full transition-colors"
                    >
                        <X size={16} className="text-gray-500" />
                    </button>
                )}
            </div>

            {/* Sugerencias */}
            {showSuggestions && results.length > 0 && (
                <div
                    ref={suggestionsRef}
                    className="absolute top-full left-0 right-0 mt-2 bg-white border-2 border-gray-200 rounded-xl shadow-2xl max-h-96 overflow-y-auto z-50"
                >
                    <div className="p-2 space-y-1">
                        {results.map((result, index) => (
                            <button
                                key={result.id}
                                onClick={() => handleSelect(result)}
                                className={`w-full p-3 rounded-lg text-left transition-all ${index === selectedIndex
                                        ? 'bg-blue-100 border-2 border-blue-300'
                                        : 'hover:bg-gray-50 border-2 border-transparent'
                                    }`}
                            >
                                <div className="flex items-start justify-between gap-3">
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-2 mb-1">
                                            <Package size={16} className="text-gray-400 flex-shrink-0" />
                                            <h4 className="font-bold text-gray-900 truncate">
                                                {highlightMatch(result.nombre, query)}
                                            </h4>
                                        </div>
                                        {result.codigo_barra && (
                                            <div className="flex items-center gap-1 text-xs text-gray-500">
                                                <Barcode size={12} />
                                                <span className="font-mono">
                                                    {highlightMatch(result.codigo_barra, query)}
                                                </span>
                                            </div>
                                        )}
                                    </div>
                                    <div className="text-right flex-shrink-0">
                                        <div className="font-black text-gray-900">
                                            ${result.precio.toLocaleString()}
                                        </div>
                                        <div className="text-xs text-gray-500">
                                            Stock: {result.stock} {result.unidad}
                                        </div>
                                    </div>
                                </div>
                            </button>
                        ))}
                    </div>

                    {/* Footer con tips */}
                    <div className="border-t border-gray-200 p-2 bg-gray-50 text-xs text-gray-500 flex items-center justify-between">
                        <span>💡 Usa ↑↓ para navegar, Enter para seleccionar</span>
                        <span className="font-mono">{results.length} resultados</span>
                    </div>
                </div>
            )}

            {/* Sin resultados */}
            {showSuggestions && query && results.length === 0 && (
                <div className="absolute top-full left-0 right-0 mt-2 bg-white border-2 border-gray-200 rounded-xl shadow-xl p-6 text-center z-50">
                    <Search size={32} className="mx-auto mb-2 text-gray-300" />
                    <p className="text-gray-600 font-medium">No se encontraron productos</p>
                    <p className="text-sm text-gray-400 mt-1">Intenta con otro término de búsqueda</p>
                </div>
            )}
        </div>
    );
}
