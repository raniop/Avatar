import dotenv from 'dotenv';
import { z } from 'zod';

// Load .env with override to handle cases where env vars are already set (e.g., by parent process)
dotenv.config({ override: true });

const envSchema = z.object({
  // Database
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),

  // AI Services
  ANTHROPIC_API_KEY: z.string().min(1, 'ANTHROPIC_API_KEY is required'),
  OPENAI_API_KEY: z.string().min(1, 'OPENAI_API_KEY is required'),

  // Authentication
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters'),
  JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 characters').optional(),

  // Server
  PORT: z
    .string()
    .default('3000')
    .transform((val) => parseInt(val, 10))
    .pipe(z.number().int().positive()),
  HOST: z.string().default('0.0.0.0'),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),

  // CORS
  CORS_ORIGIN: z.string().default('http://localhost:8081'),

  // File Storage
  UPLOAD_DIR: z.string().default('./uploads'),
});

export type Environment = z.infer<typeof envSchema>;

let cachedEnv: Environment | null = null;

export function getEnv(): Environment {
  if (cachedEnv) return cachedEnv;

  const result = envSchema.safeParse(process.env);

  if (!result.success) {
    const formatted = result.error.format();
    const errorMessages = Object.entries(formatted)
      .filter(([key]) => key !== '_errors')
      .map(([key, value]) => {
        const errors = (value as { _errors: string[] })._errors;
        return `  ${key}: ${errors.join(', ')}`;
      })
      .join('\n');

    console.error('Environment validation failed:\n' + errorMessages);
    process.exit(1);
  }

  cachedEnv = result.data;
  return cachedEnv;
}

export function isDev(): boolean {
  return getEnv().NODE_ENV === 'development';
}

export function isProd(): boolean {
  return getEnv().NODE_ENV === 'production';
}
