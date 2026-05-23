import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import { useAuth } from '../contexts/AuthContext';
import { Input } from '../components/ui/Input';
import { Button } from '../components/ui/Button';
import { ShoppingBag, ArrowRight, AlertCircle } from 'lucide-react';
import { loginSchema, LoginFormData } from '../lib/validation';

export function Login() {
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormData>({
    resolver: yupResolver(loginSchema),
  });

  const onSubmit = async (data: LoginFormData) => {
    setLoading(true);
    try {
      await login(data.email, data.password);
      navigate('/');
    } catch {
      // Error handling is done in the login function
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex">
      {/* Left Side: Branding & Visuals */}
      <div className="hidden lg:flex lg:w-1/2 bg-slate-900 relative flex-col justify-between p-12 overflow-hidden">
        {/* Background Pattern */}
        <div className="absolute inset-0 opacity-10">
          <svg className="h-full w-full" viewBox="0 0 100 100" preserveAspectRatio="none">
            <path d="M0 100 C 20 0 50 0 100 100 Z" fill="currentColor" className="text-emerald-500" />
          </svg>
        </div>

        <div className="relative z-10">
          <div className="flex items-start gap-3 mb-8">
            <div className="p-2 bg-emerald-500 rounded-xl shadow-lg shadow-emerald-900/40">
              <ShoppingBag className="text-white h-8 w-8" />
            </div>
          </div>
          <h1 className="text-5xl font-extrabold text-white tracking-tight mb-4">
            MARKET<span className="text-emerald-500">PRO</span>
          </h1>
          <p className="text-slate-400 text-xl max-w-md">
            Gestión inteligente de inventario y punto de venta para el comercio moderno.
          </p>
        </div>

        <div className="relative z-10 text-slate-500 text-sm">
          &copy; 2024 MarketPro Systems. Todos los derechos reservados.
        </div>
      </div>

      {/* Right Side: Login Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-gray-50">
        <div className="max-w-md w-full space-y-8 bg-white p-10 rounded-2xl shadow-xl border border-gray-100">
          <div className="text-center lg:text-left">
            {/* Mobile Logo shows here */}
            <div className="flex lg:hidden justify-center mb-6">
              <div className="p-2 bg-emerald-500 rounded-xl shadow-lg">
                <ShoppingBag className="text-white h-8 w-8" />
              </div>
            </div>
            <h2 className="text-3xl font-bold text-gray-900">Bienvenido de nuevo</h2>
            <p className="mt-2 text-gray-600">Por favor ingresa tus credenciales para continuar.</p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 mt-8">
            <div className="space-y-4">
              <div>
                <Input
                  label="Correo Electrónico"
                  type="email"
                  {...register('email')}
                  placeholder="admin@marketpro.cl"
                  className={`bg-gray-50 border-gray-200 focus:border-emerald-500 focus:ring-emerald-500 ${errors.email ? 'border-red-400' : ''}`}
                />
                {errors.email && (
                  <p className="mt-1 text-xs text-red-500 flex items-center gap-1">
                    <AlertCircle size={12} /> {errors.email.message}
                  </p>
                )}
              </div>

              <div>
                <Input
                  label="Contraseña"
                  type="password"
                  {...register('password')}
                  placeholder="••••••••"
                  className={`bg-gray-50 border-gray-200 focus:border-emerald-500 focus:ring-emerald-500 ${errors.password ? 'border-red-400' : ''}`}
                />
                {errors.password && (
                  <p className="mt-1 text-xs text-red-500 flex items-center gap-1">
                    <AlertCircle size={12} /> {errors.password.message}
                  </p>
                )}
              </div>
            </div>

            <Button
              type="submit"
              className="w-full bg-slate-900 hover:bg-slate-800 text-white h-12 text-base font-semibold shadow-lg shadow-slate-900/20 flex items-center justify-center group"
              isLoading={loading}
            >
              Ingresar al Sistema
              {!loading && <ArrowRight className="ml-2 h-4 w-4 group-hover:translate-x-1 transition-transform" />}
            </Button>
          </form>

          <div className="mt-6 text-center">
            <p className="text-sm text-gray-500">
              ¿Olvidaste tu contraseña? <a href="#" className="font-medium text-emerald-600 hover:text-emerald-500">Contactar soporte</a>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}