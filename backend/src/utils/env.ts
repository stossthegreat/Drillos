// src/utils/env.ts
import 'dotenv/config';
import { z } from 'zod';

const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),

  // Infra
  DATABASE_URL: z.string().url('DATABASE_URL must be a valid Postgres connection string'),
  REDIS_URL: z.string().url('REDIS_URL must be a valid redis:// or rediss:// URL'),

  // Public URL (Railway)
  BACKEND_URL: z.string().url().default('http://localhost:8080'),

  // OpenAI
  OPENAI_API_KEY: z.string().min(10, 'OPENAI_API_KEY missing'),
  OPENAI_MODEL: z.string().default('gpt-4o-mini'),
  LLM_MAX_TOKENS: z.coerce.number().int().positive().default(500),
  LLM_TIMEOUT_MS: z.coerce.number().int().positive().default(10000),
  LLM_ENABLED: z
    .string()
    .default('true')
    .transform((v) => v.toLowerCase() === 'true'),

  // ElevenLabs
  ELEVENLABS_API_KEY: z.string().min(10, 'ELEVENLABS_API_KEY missing'),
  ELEVENLABS_VOICE_MARCUS: z.string().min(10, 'ELEVENLABS_VOICE_MARCUS missing'),
  ELEVENLABS_VOICE_DRILL: z.string().min(10, 'ELEVENLABS_VOICE_DRILL missing'),
  ELEVENLABS_VOICE_CONFUCIUS: z.string().min(10, 'ELEVENLABS_VOICE_CONFUCIUS missing'),
  ELEVENLABS_VOICE_LINCOLN: z.string().min(10, 'ELEVENLABS_VOICE_LINCOLN missing'),
  ELEVENLABS_VOICE_BUDDHA: z.string().min(10, 'ELEVENLABS_VOICE_BUDDHA missing'),
  TTS_DAILY_CHAR_CAP_FREE: z.coerce.number().int().nonnegative().default(2500),
  TTS_DAILY_CHAR_CAP_PRO: z.coerce.number().int().positive().default(15000),
  TTS_ENABLED: z
    .string()
    .default('true')
    .transform((v) => v.toLowerCase() === 'true'),

  // Firebase (push)
  FIREBASE_PROJECT_ID: z.string().min(2),
  FIREBASE_CLIENT_EMAIL: z.string().email(),
  FIREBASE_PRIVATE_KEY: z.string().min(20), // keep literal \n in .env and we’ll replace

  // Stripe (optional now; still validate presence if you plan billing)
  STRIPE_SECRET_KEY: z.string().optional(),
  STRIPE_WEBHOOK_SECRET: z.string().optional(),
});

const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
  // Print all issues clearly and crash
  console.error('❌ Invalid environment configuration:\n');
  for (const issue of parsed.error.issues) {
    console.error(`- ${issue.path.join('.')}: ${issue.message}`);
  }
  process.exit(1);
}

export const ENV = parsed.data;

// Helpers
export const isProd = ENV.NODE_ENV === 'production';
export const isDev = ENV.NODE_ENV === 'development';
