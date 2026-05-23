import { BrowserRouter as Router, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { LayoutProvider } from './contexts/LayoutContext';
import { Layout } from './components/layout/Layout';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { Inventory } from './pages/Inventory';
import Entries from './pages/Entries';

import { ProductMaster } from './pages/ProductMaster';
import { Movements } from './pages/Movements';

import { Customers } from './pages/Customers'; // Import new page
import { Users } from './pages/Users';
import { PurchaseOrders } from './pages/purchases/PurchaseOrders';
import { CreatePurchaseOrder } from './pages/purchases/CreatePurchaseOrder';
import { ReceiveOrder } from './pages/purchases/ReceiveOrder';
import { InventoryAudit } from './pages/inventory/InventoryAudit';
import { PreVentas } from './pages/PreVentas';
import { CrearPreVenta } from './pages/CrearPreVenta';
import { CajeroPreVentas } from './pages/CajeroPreVentas';
import { SalesHistory } from './pages/SalesHistory';
import { SuperAdmin } from './pages/SuperAdmin';
import { Traslados } from './pages/Traslados';
import { PrintBarcodes } from './pages/PrintBarcodes';

function ProtectedRoute() {
  const { user } = useAuth();

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  return (
    <Layout>
      <Outlet />
    </Layout>
  );
}

function AppRoutes() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <Routes>
      <Route
        path="/login"
        element={user ? <Navigate to="/" replace /> : <Login />}
      />

      {/* Rutas Protegidas */}
      <Route element={<ProtectedRoute />}>
        <Route path="/" element={<Dashboard />} />
        <Route path="/customers" element={<Customers />} />
        <Route path="/purchases" element={<PurchaseOrders />} />
        <Route path="/purchases/new" element={<CreatePurchaseOrder />} />
        <Route path="/purchases/:id/receive" element={<ReceiveOrder />} />
        <Route path="/audit" element={<InventoryAudit />} />
        <Route path="/inventory" element={<Inventory />} />
        <Route path="/entries" element={<Entries />} />

        <Route path="/product-master" element={<ProductMaster />} />
        <Route path="/movements" element={<Movements />} />
        <Route path="/sales" element={<SalesHistory />} />

        <Route path="/users" element={<Users />} />
        <Route path="/superadmin" element={<SuperAdmin />} />
        <Route path="/traslados" element={<Traslados />} />
        <Route path="/print-barcodes" element={<PrintBarcodes />} />

        {/* Pre-Ventas */}
        <Route path="/preventas" element={<PreVentas />} />
        <Route path="/preventas/nueva" element={<CrearPreVenta />} />
        <Route path="/preventas/cajero" element={<CajeroPreVentas />} />
      </Route>

      {/* Redirección para cualquier otra ruta */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

import { ThemeProvider } from './contexts/ThemeContext';

import { ErrorBoundary } from './components/ui/ErrorBoundary';

function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <LayoutProvider>
          <ThemeProvider>
            <Router>
              <div className="App">
                <AppRoutes />
                <Toaster
                position="top-right"
                toastOptions={{
                  duration: 4000,
                  style: {
                    background: '#363636',
                    color: '#fff',
                  },
                  success: {
                    duration: 3000,
                    iconTheme: {
                      primary: '#10B981',
                      secondary: '#fff',
                    },
                  },
                  error: {
                    duration: 4000,
                    iconTheme: {
                      primary: '#EF4444',
                      secondary: '#fff',
                    },
                  },
                }}
              />
            </div>
          </Router>
        </ThemeProvider>
      </LayoutProvider>
    </AuthProvider>
  </ErrorBoundary>
  );
}

export default App;