import { PrismaClient } from '@prisma/client';
export declare function getPrisma(): PrismaClient;
export declare const prismaClient: PrismaClient<import(".prisma/client").Prisma.PrismaClientOptions, import(".prisma/client").Prisma.LogLevel, import("@prisma/client/runtime/library").DefaultArgs>;
export declare const prisma: PrismaClient<import(".prisma/client").Prisma.PrismaClientOptions, import(".prisma/client").Prisma.LogLevel, import("@prisma/client/runtime/library").DefaultArgs>;
export declare function dbHealthCheck(): Promise<boolean>;
export declare function closeDb(): Promise<void>;
