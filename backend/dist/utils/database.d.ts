import { PrismaClient } from '@prisma/client';
declare class DatabaseClient {
    private static instance;
    static getInstance(): PrismaClient;
    static connect(): Promise<void>;
    static disconnect(): Promise<void>;
    static healthCheck(): Promise<boolean>;
}
export declare const prisma: PrismaClient<import(".prisma/client").Prisma.PrismaClientOptions, import(".prisma/client").Prisma.LogLevel, import("@prisma/client/runtime/library").DefaultArgs>;
export default DatabaseClient;
