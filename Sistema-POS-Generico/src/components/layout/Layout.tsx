import React from 'react';
import { Navbar } from './Navbar';
import { Sidebar } from './Sidebar';
import { useLayout } from '../../contexts/LayoutContext';

interface LayoutProps {
  children: React.ReactNode;
}

export function Layout({ children }: LayoutProps) {
  const { layout } = useLayout();

  if (layout === 'sidebar') {
    return (
      <div className="flex h-screen bg-gray-50">
        <Sidebar />
        <main className="flex-1 overflow-y-auto custom-scrollbar">
          <div className="p-8">
            {children}
          </div>
        </main>
      </div>
    );
  }

  if (layout === 'pos-only') {
    return (
      <div className="h-screen bg-gray-50 overflow-hidden">
        {children}
      </div>
    );
  }

  // Navbar Mode (Top Navigation)
  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <Navbar />
      <main className="flex-1 w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {children}
      </main>
    </div>
  );
}