import * as yup from 'yup';

export const loginSchema = yup.object({
  email: yup
    .string()
    .email('Ingrese un correo electrónico válido')
    .required('El correo es obligatorio'),
  password: yup
    .string()
    .min(6, 'La contraseña debe tener al menos 6 caracteres')
    .required('La contraseña es obligatoria'),
});

export type LoginFormData = yup.InferType<typeof loginSchema>;

export const customerSchema = yup.object({
  nombre: yup
    .string()
    .min(2, 'El nombre debe tener al menos 2 caracteres')
    .required('El nombre es obligatorio'),
  rut: yup
    .string()
    .matches(/^[0-9]{7,8}-[0-9kK]$/, 'Formato RUT inválido (ej: 12345678-9)')
    .required('El RUT es obligatorio'),
  telefono: yup
    .string()
    .matches(/^[0-9]{9,}$/, 'Teléfono inválido (mínimo 9 dígitos)')
    .nullable()
    .transform((v: string | null) => v || null),
  email: yup.string().email('Correo inválido').nullable().transform((v: string | null) => v || null),
  direccion: yup.string().nullable().transform((v: string | null) => v || null),
});

export type CustomerFormData = yup.InferType<typeof customerSchema>;
