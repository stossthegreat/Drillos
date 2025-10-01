import { PrismaClient } from '@prisma/client';

class DatabaseClient {
  private static instance: PrismaClient;

  public static getInstance(): PrismaClient {
    if (!DatabaseClient.instance) {
      DatabaseClient.instance = new PrismaClient({
        log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
        errorFormat: 'pretty',
      });
    }
    return DatabaseClient.instance;
  }

  public static async connect(): Promise<void> {
    const client = DatabaseClient.getInstance();
    await client.$connect();
  }

  public static async disconnect(): Promise<void> {
    const client = DatabaseClient.getInstance();
    await client.$disconnect();
  }

  public static async healthCheck(): Promise<boolean> {
    try {
      const client = DatabaseClient.getInstance();
      await client.$queryRaw`SELECT 1`;
      return true;
    } catch (error) {
      console.error('Database health check failed:', error);
      return false;
    }
  }
}

export const prisma = DatabaseClient.getInstance();
export default DatabaseClient;
