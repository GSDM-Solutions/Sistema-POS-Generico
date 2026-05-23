/**
 * Utilidades para manejo de unidades de medida
 */

export type UnidadMedida = 'UN' | 'KG' | 'MTRS' | 'LTS' | 'GR' | 'ML';

export const UNIDADES_CONFIG = {
    UN: {
        label: 'Unidad',
        abreviatura: 'UN',
        permiteDecimales: false,
        step: 1,
        min: 1,
        placeholder: 'Ej: 5'
    },
    KG: {
        label: 'Kilogramo',
        abreviatura: 'KG',
        permiteDecimales: true,
        step: 0.01,
        min: 0.01,
        placeholder: 'Ej: 2.5'
    },
    MTRS: {
        label: 'Metro',
        abreviatura: 'MTRS',
        permiteDecimales: true,
        step: 0.01,
        min: 0.01,
        placeholder: 'Ej: 3.75'
    },
    LTS: {
        label: 'Litro',
        abreviatura: 'LTS',
        permiteDecimales: true,
        step: 0.01,
        min: 0.01,
        placeholder: 'Ej: 1.5'
    },
    GR: {
        label: 'Gramo',
        abreviatura: 'GR',
        permiteDecimales: true,
        step: 1,
        min: 1,
        placeholder: 'Ej: 250'
    },
    ML: {
        label: 'Mililitro',
        abreviatura: 'ML',
        permiteDecimales: true,
        step: 1,
        min: 1,
        placeholder: 'Ej: 500'
    }
} as const;

/**
 * Valida si una cantidad es válida para la unidad de medida
 */
export function validarCantidad(cantidad: number, unidad: string): boolean {
    const config = UNIDADES_CONFIG[unidad as UnidadMedida] || UNIDADES_CONFIG.UN;

    if (cantidad < config.min) return false;

    if (!config.permiteDecimales && !Number.isInteger(cantidad)) {
        return false;
    }

    return true;
}

/**
 * Formatea la cantidad según la unidad de medida
 */
export function formatearCantidad(cantidad: number, unidad: string): string {
    const config = UNIDADES_CONFIG[unidad as UnidadMedida] || UNIDADES_CONFIG.UN;

    if (config.permiteDecimales) {
        // Mostrar hasta 2 decimales, eliminando ceros innecesarios
        return cantidad.toFixed(2).replace(/\.?0+$/, '');
    }

    return Math.floor(cantidad).toString();
}

/**
 * Formatea cantidad con unidad de medida
 */
export function formatearCantidadConUnidad(cantidad: number, unidad: string): string {
    const cantidadFormateada = formatearCantidad(cantidad, unidad);
    const config = UNIDADES_CONFIG[unidad as UnidadMedida] || UNIDADES_CONFIG.UN;

    return `${cantidadFormateada} ${config.abreviatura}`;
}

/**
 * Obtiene la configuración de una unidad de medida
 */
export function getConfigUnidad(unidad: string) {
    return UNIDADES_CONFIG[unidad as UnidadMedida] || UNIDADES_CONFIG.UN;
}

/**
 * Redondea la cantidad según la unidad de medida
 */
export function redondearCantidad(cantidad: number, unidad: string): number {
    const config = UNIDADES_CONFIG[unidad as UnidadMedida] || UNIDADES_CONFIG.UN;

    if (!config.permiteDecimales) {
        return Math.floor(cantidad);
    }

    // Redondear a 2 decimales
    return Math.round(cantidad * 100) / 100;
}
