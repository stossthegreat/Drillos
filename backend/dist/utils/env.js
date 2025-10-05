"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isDev = exports.isProd = exports.ENV = void 0;
// src/utils/env.ts
require("dotenv/config");
const zod_1 = require("zod");
const EnvSchema = zod_1.z.object({
    NODE_ENV: zod_1.z.enum(['development', 'test', 'production']).default('development'),
    PORT: zod_1.z.coerce.number().int().positive().default(8080),
    // Infra
    DATABASE_URL: zod_1.z.string().url('DATABASE_URL must be a valid Postgres connection string'),
    REDIS_URL: zod_1.z.string().url('REDIS_URL must be a valid redis:// or rediss:// URL'),
    // Public URL (Railway)
    BACKEND_URL: zod_1.z.string().url().default('http://localhost:8080'),
    // OpenAI
    OPENAI_API_KEY: zod_1.z.string().default(''),
    OPENAI_MODEL: zod_1.z.string().default('gpt-4o-mini'),
    LLM_MAX_TOKENS: zod_1.z.coerce.number().int().positive().default(500),
    LLM_TIMEOUT_MS: zod_1.z.coerce.number().int().positive().default(10000),
    LLM_ENABLED: zod_1.z
        .string()
        .default('true')
        .transform((v) => v.toLowerCase() === 'true'),
    // ElevenLabs
    ELEVENLABS_API_KEY: zod_1.z.string().default(''),
    ELEVENLABS_VOICE_MARCUS: zod_1.z.string().default(''),
    ELEVENLABS_VOICE_DRILL: zod_1.z.string().default(''),
    ELEVENLABS_VOICE_CONFUCIUS: zod_1.z.string().default(''),
    ELEVENLABS_VOICE_LINCOLN: zod_1.z.string().default(''),
    ELEVENLABS_VOICE_BUDDHA: zod_1.z.string().default(''),
    TTS_DAILY_CHAR_CAP_FREE: zod_1.z.coerce.number().int().nonnegative().default(2500),
    TTS_DAILY_CHAR_CAP_PRO: zod_1.z.coerce.number().int().positive().default(15000),
    TTS_ENABLED: zod_1.z
        .string()
        .default('true')
        .transform((v) => v.toLowerCase() === 'true'),
    // Firebase (push)
    FIREBASE_PROJECT_ID: zod_1.z.string().default(''),
    FIREBASE_CLIENT_EMAIL: zod_1.z.string().default(''),
    FIREBASE_PRIVATE_KEY: zod_1.z.string().default(''), // keep literal \n in .env and we'll replace
    // Stripe (optional now; still validate presence if you plan billing)
    STRIPE_SECRET_KEY: zod_1.z.string().default(''),
    STRIPE_WEBHOOK_SECRET: zod_1.z.string().default(''),
    // S3/MinIO (optional)
    S3_ENDPOINT: zod_1.z.string().default(''),
    S3_BUCKET: zod_1.z.string().default(''),
    S3_ACCESS_KEY: zod_1.z.string().default(''),
    S3_SECRET_KEY: zod_1.z.string().default(''),
});
const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
    // Print all issues but don't crash - let the server start
    console.warn('⚠️ Environment configuration issues:\n');
    for (const issue of parsed.error.issues) {
        console.warn(`- ${issue.path.join('.')}: ${issue.message}`);
    }
    console.warn('⚠️ Server will start but some features may not work');
}
exports.ENV = parsed.success ? parsed.data : {};
// Helpers
exports.isProd = exports.ENV.NODE_ENV === 'production';
exports.isDev = exports.ENV.NODE_ENV === 'development';
