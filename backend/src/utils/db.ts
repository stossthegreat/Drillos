// src/utils/db.ts
import { PrismaClient } from '@prisma/client';

let prisma: PrismaClient;

// Prevent multiple clients in dev/hot-reload
declare global {
  // eslint-disable-next-line no-var
  var __prisma__: PrismaClient | undefined;
}

if (process.env.NODE_ENV !== 'production') {
  if (!global.__prisma__) {
    global.__prisma__ = new PrismaClient({
      log: ['error', 'warn'],
    });
  }
  prisma = global.__prisma__;
} else {
  prisma = new PrismaClient({
    log: ['error', 'warn'],
  });
}

export { prisma };
