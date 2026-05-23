/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useState, ReactNode } from 'react';

type LayoutType = 'sidebar' | 'topbar' | 'pos-only';

interface LayoutContextType {
    layout: LayoutType;
    setLayout: (layout: LayoutType) => void;
    toggleLayout: () => void;
}

const LayoutContext = createContext<LayoutContextType | undefined>(undefined);

export function LayoutProvider({ children }: { children: ReactNode }) {
    const [layout, setLayoutState] = useState<LayoutType>(() => {
        const saved = localStorage.getItem('layout') as LayoutType;
        return saved || 'sidebar';
    });

    const setLayout = (newLayout: LayoutType) => {
        setLayoutState(newLayout);
        localStorage.setItem('layout', newLayout);
    };

    const toggleLayout = () => {
        setLayout(layout === 'sidebar' ? 'topbar' : 'sidebar');
    };

    return (
        <LayoutContext.Provider value={{ layout, setLayout, toggleLayout }}>
            {children}
        </LayoutContext.Provider>
    );
}

export function useLayout() {
    const context = useContext(LayoutContext);
    if (!context) {
        throw new Error('useLayout must be used within LayoutProvider');
    }
    return context;
}
