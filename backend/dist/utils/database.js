"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.prisma = void 0;
const client_1 = require("@prisma/client");
class DatabaseClient {
    static instance;
    static getInstance() {
        if (!DatabaseClient.instance) {
            DatabaseClient.instance = new client_1.PrismaClient({
                log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
                errorFormat: 'pretty',
            });
        }
        return DatabaseClient.instance;
    }
    static async connect() {
        const client = DatabaseClient.getInstance();
        await client.$connect();
    }
    static async disconnect() {
        const client = DatabaseClient.getInstance();
        await client.$disconnect();
    }
    static async healthCheck() {
        try {
            const client = DatabaseClient.getInstance();
            await client.$queryRaw `SELECT 1`;
            return true;
        }
        catch (error) {
            console.error('Database health check failed:', error);
            return false;
        }
    }
}
exports.prisma = DatabaseClient.getInstance();
exports.default = DatabaseClient;
