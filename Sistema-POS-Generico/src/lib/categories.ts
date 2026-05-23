export const PRODUCT_CATEGORIES = [
  { value: 'almacen', label: 'Almacén y Abarrotes' },
  { value: 'bebidas', label: 'Bebidas y Licores' },
  { value: 'lacteos', label: 'Lácteos y Fiambrería' },
  { value: 'limpieza', label: 'Aseo y Limpieza' },
  { value: 'escritorio', label: 'Escritorio y Papelería' },
  { value: 'herramientas', label: 'Herramientas y Ferretería' },
  { value: 'electricidad', label: 'Electricidad y Gasfitería' },
  { value: 'ferreteria', label: 'Ferretería General' },
  { value: 'libreria', label: 'Librería y Útiles' },
  { value: 'jugueteria', label: 'Juguetería' },
  { value: 'ropa', label: 'Ropa y Calzado' },
  { value: 'electronica', label: 'Electrónica y Computación' },
  { value: 'mascotas', label: 'Mascotas y Accesorios' },
  { value: 'farmacia', label: 'Farmacia y Perfumería' },
  { value: 'bazar', label: 'Bazar y Hogar' },
  { value: 'otros', label: 'Otros' },
] as const;

export type CategoryValue = (typeof PRODUCT_CATEGORIES)[number]['value'];
