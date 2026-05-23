import React from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts';

interface CategoryChartProps {
  data: Array<{ name: string; value: number }>;
}

// MarketPro Palette: Emerald to Indigo gradient feel
const COLORS = [
  '#10B981', // Emerald 500
  '#0EA5E9', // Sky 500
  '#6366F1', // Indigo 500
  '#F59E0B', // Amber 500
  '#EC4899', // Pink 500
  '#8B5CF6', // Violet 500
  '#14B8A6', // Teal 500
  '#F43F5E', // Rose 500
];

interface TooltipPayloadItem {
  name: string;
  value: number;
}

interface CustomTooltipProps {
  active?: boolean;
  payload?: Array<{ payload: TooltipPayloadItem; name: string; value: number }>;
}

const CustomTooltip = ({ active, payload }: CustomTooltipProps) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-white p-3 border border-slate-100 shadow-xl rounded-xl">
        <p className="font-bold text-slate-800">{payload[0].name}</p>
        <p className="text-emerald-600 font-medium">
          {payload[0].value} productos
        </p>
      </div>
    );
  }
  return null;
};

export function CategoryChart({ data }: CategoryChartProps) {
  // Filter out empty categories
  const cleanData = data.filter(d => d.value > 0);

  return (
    <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100 flex flex-col h-full min-h-[400px]">
      <h3 className="text-lg font-bold text-slate-800 mb-6">Distribución de Inventario</h3>
      {cleanData.length > 0 ? (
        <div className="flex-1 w-full relative">
          {/* Wrapper div needs explicit dimensions for Recharts */}
          <div className="absolute inset-0">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={cleanData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={90}
                  paddingAngle={5}
                  dataKey="value"
                  nameKey="name"
                  cornerRadius={6}
                  stroke="none"
                >
                  {cleanData.map((_, index) => (
                    <Cell
                      key={`cell-${index}`}
                      fill={COLORS[index % COLORS.length]}
                      className="outline-none focus:outline-none hover:opacity-80 transition-opacity cursor-pointer"
                    />
                  ))}
                </Pie>
                <Tooltip content={<CustomTooltip />} />
                <Legend
                  verticalAlign="bottom"
                  height={36}
                  iconType="circle"
                  wrapperStyle={{ paddingTop: "20px" }}
                  formatter={(value) => <span className="text-slate-600 font-medium ml-1 text-sm">{value}</span>}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      ) : (
        <div className="flex-1 flex flex-col items-center justify-center text-slate-400 min-h-[200px]">
          <div className="bg-slate-50 p-4 rounded-full mb-3">
            <span className="text-2xl">📊</span>
          </div>
          <p className="text-sm font-medium">Sin datos para mostrar</p>
          <p className="text-xs text-slate-400 mt-1">Agrega productos para ver estadísticas</p>
        </div>
      )}
    </div>
  );
}