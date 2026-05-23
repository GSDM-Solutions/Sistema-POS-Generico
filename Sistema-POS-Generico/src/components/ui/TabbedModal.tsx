import { X } from 'lucide-react';
import { ReactNode, useState } from 'react';

interface Tab {
    id: string;
    label: string;
    icon?: ReactNode;
    content: ReactNode;
}

interface TabbedModalProps {
    isOpen: boolean;
    onClose: () => void;
    title: string;
    tabs: Tab[];
    defaultTab?: string;
    size?: 'sm' | 'md' | 'lg' | 'xl';
}

export function TabbedModal({
    isOpen,
    onClose,
    title,
    tabs,
    defaultTab,
    size = 'lg'
}: TabbedModalProps) {
    const [activeTab, setActiveTab] = useState(defaultTab || tabs[0]?.id);

    if (!isOpen) return null;

    const sizeClasses = {
        sm: 'max-w-md',
        md: 'max-w-2xl',
        lg: 'max-w-4xl',
        xl: 'max-w-6xl'
    };

    const activeTabContent = tabs.find(tab => tab.id === activeTab);

    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className={`bg-white rounded-3xl shadow-2xl w-full ${sizeClasses[size]} max-h-[90vh] flex flex-col overflow-hidden`}>
                {/* Header */}
                <div className="p-6 border-b border-gray-200 bg-gradient-to-r from-blue-600 to-indigo-600 text-white flex-shrink-0">
                    <div className="flex items-center justify-between">
                        <h2 className="text-2xl font-bold">{title}</h2>
                        <button
                            onClick={onClose}
                            className="p-2 hover:bg-white/20 rounded-lg transition-colors"
                        >
                            <X size={24} />
                        </button>
                    </div>

                    {/* Tabs */}
                    <div className="flex gap-2 mt-4 -mb-6">
                        {tabs.map(tab => (
                            <button
                                key={tab.id}
                                onClick={() => setActiveTab(tab.id)}
                                className={`flex items-center gap-2 px-4 py-2 rounded-t-xl font-semibold transition-all ${activeTab === tab.id
                                        ? 'bg-white text-blue-600 shadow-lg'
                                        : 'bg-white/20 text-white hover:bg-white/30'
                                    }`}
                            >
                                {tab.icon}
                                {tab.label}
                            </button>
                        ))}
                    </div>
                </div>

                {/* Content */}
                <div className="flex-1 overflow-y-auto p-6">
                    {activeTabContent?.content}
                </div>

                {/* Footer (opcional) */}
                <div className="p-4 bg-gray-50 border-t border-gray-200 flex justify-end gap-3 flex-shrink-0">
                    <button
                        onClick={onClose}
                        className="px-6 py-2 bg-white border-2 border-gray-300 text-gray-700 rounded-xl font-bold hover:bg-gray-50 transition-colors"
                    >
                        Cerrar
                    </button>
                </div>
            </div>
        </div>
    );
}
