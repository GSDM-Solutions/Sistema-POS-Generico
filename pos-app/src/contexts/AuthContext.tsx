/* eslint-disable react-refresh/only-export-components */
import React, { createContext, useContext, useEffect, useState } from 'react';
import { User } from '../types';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  hasPermission: (action: string) => boolean;
  signUp: (email: string, password: string, name: string, role: string) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Sistema de roles:
// 1. Super Admin: Plataforma completa
// 2. Admin: Gerente (acceso total a su empresa)
// 3. Supervisor: Encargado (Operativo + Inventario + Reportes) - NO Ajustes/Usuarios/Historial
// 4. Empleado: Cajero/Vendedor (POS + Clientes + Ver Stock)
const ROLE_PERMISSIONS = {
  superadmin: ['superadmin', 'all'],
  admin: ['all'],
  supervisor: [
    'pos',
    'create_presales',
    'confirm_presales',
    'manage_customers',
    'manage_stock',
    'view_stock',
    'entries',
    'manage_master_products',
    'view_dashboard',
    // EXCLUIDOS: manage_users, manage_adjustments, view_sales, treasury
  ],
  empleado: [ // Cajero/Vendedor
    'pos',
    'create_presales',
    'manage_customers',
    'view_stock',
    // EXCLUIDOS: manage_stock, entries, treasury, master_products, dashboard, users, adjustments
  ]
};

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const handleAuthStateChange = async () => {
      setLoading(true);
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        const { data: userData, error } = await supabase
          .from('users')
          .select('*')
          .eq('id', session.user.id)
          .single();
        if (!error && userData) {
          setUser(userData);
        }
      } else {
        setUser(null);
      }
      setLoading(false);
    };

    handleAuthStateChange(); // Initial check

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        // Fetch user data from 'users' table only if signed in
        supabase
          .from('users')
          .select('*')
          .eq('id', session.user.id)
          .single()
          .then(({ data: userData, error }) => {
            if (!error) {
              setUser(userData || null);
            }
          });
      } else {
        setUser(null);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  // Registro de usuario
  const signUp = async (email: string, password: string, name: string, role: string) => {
    try {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: { name }
        }
      });
      if (error) throw error;
      const userId = data.user?.id;
      if (!userId) throw new Error('No se pudo obtener el id del usuario');
      const { error: errorInsert } = await supabase.from('users').insert([
        {
          id: userId,
          email,
          name,
          role,
          created_at: new Date().toISOString()
        }
      ]);
      if (errorInsert) throw errorInsert;
      toast.success('Usuario registrado correctamente. Revisa tu correo para confirmar la cuenta.');
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Error al registrar usuario';
      toast.error(message);
      throw err;
    }
  };

  const login = async (email: string, password: string) => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });
      if (error) throw error;

      if (data.user) {
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('*')
          .eq('id', data.user.id)
          .single();

        if (userError) {
          toast.error('Error al obtener datos del usuario');
          throw userError;
        }

        if (userData) {
          setUser(userData);
        }
      }

      toast.success('Inicio de sesión exitoso');
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'Error al iniciar sesión';
      toast.error(message);
      throw error;
    }
  };

  const logout = async () => {
    try {
      await supabase.auth.signOut();
      setUser(null);
      toast.success('Sesión cerrada');
    } catch {
      toast.error('Error al cerrar sesión');
    }
  };

  const hasPermission = (action: string) => {
    if (!user) return false;
    const permissions = (ROLE_PERMISSIONS as Record<string, string[]>)[user.role] || [];

    // 'all' no otorga permisos de 'superadmin'. Deben ser explícitos.
    if (action === 'superadmin') {
      return permissions.includes('superadmin');
    }

    return permissions.includes('all') || permissions.includes(action);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, hasPermission, signUp }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}