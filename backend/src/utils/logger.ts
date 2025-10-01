// src/utils/logger.ts
import pino from 'pino';
import { isDev } from './env';

const redactions = [
  'req.headers.authorization',
  'headers.authorization',
  'OPENAI_API_KEY',
  'ELEVENLABS_API_KEY',
  'FIREBASE_PRIVATE_KEY',
  'STRIPE_SECRET_KEY',
  'STRIPE_WEBHOOK_SECRET',
];

export const logger = pino({
  level: process.env.LOG_LEVEL || (isDev ? 'debug' : 'info'),
  redact: { paths: redactions, censor: '[REDACTED]' },
  transport: isDev
    ? {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'SYS:standard',
          ignore: 'pid,hostname',
        },
      }
    : undefined,
  base: undefined, // don’t add pid/hostname clutter
});

export function childLogger(bindings: Record<string, any>) {
  return logger.child(bindings);
}
