// src/utils/db.ts
import { PrismaClient } from '@prisma/client';
import { isDev } from './env';
import { logger } from './logger';

let _prisma: PrismaClient | null = null;

function makeClient() {
  const client = new PrismaClient({
    log: isDev ? ['warn', 'error'] : ['error'],
    errorFormat: 'pretty',
  });

  // (Optional) Prisma middleware to stamp queries / add observability later
  // client.$use(async (params, next) => next(params));

  return client;
}

export function getPrisma(): PrismaClient {
  if (!_prisma) {
    // reuse in dev hot-reload
    const g = global as any;
    if (isDev && g.__prisma__) {
      _prisma = g.__prisma__ as PrismaClient;
    } else {
      _prisma = makeClient();
      if (isDev) (global as any).__prisma__ = _prisma;
    }
  }
  return _prisma!;
}

export const prismaClient = getPrisma();
export const prisma = prismaClient; // Export as 'prisma' for compatibility

export async function dbHealthCheck(): Promise<boolean> {
  try {
    await prismaClient.$queryRaw`SELECT 1`;
    return true;
  } catch (err) {
    logger.error({ err }, 'DB health check failed');
    return false;
  }
}

export async function closeDb(): Promise<void> {
  if (_prisma) {
    await _prisma.$disconnect();
    _prisma = null;
  }
}
