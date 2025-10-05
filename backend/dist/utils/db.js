"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.prisma = exports.prismaClient = void 0;
exports.getPrisma = getPrisma;
exports.dbHealthCheck = dbHealthCheck;
exports.closeDb = closeDb;
// src/utils/db.ts
const client_1 = require("@prisma/client");
const env_1 = require("./env");
const logger_1 = require("./logger");
let _prisma = null;
function makeClient() {
    const client = new client_1.PrismaClient({
        log: env_1.isDev ? ['warn', 'error'] : ['error'],
        errorFormat: 'pretty',
    });
    // (Optional) Prisma middleware to stamp queries / add observability later
    // client.$use(async (params, next) => next(params));
    return client;
}
function getPrisma() {
    if (!_prisma) {
        // reuse in dev hot-reload
        const g = global;
        if (env_1.isDev && g.__prisma__) {
            _prisma = g.__prisma__;
        }
        else {
            _prisma = makeClient();
            if (env_1.isDev)
                global.__prisma__ = _prisma;
        }
    }
    return _prisma;
}
exports.prismaClient = getPrisma();
exports.prisma = exports.prismaClient; // Export as 'prisma' for compatibility
async function dbHealthCheck() {
    try {
        await exports.prismaClient.$queryRaw `SELECT 1`;
        return true;
    }
    catch (err) {
        logger_1.logger.error({ err }, 'DB health check failed');
        return false;
    }
}
async function closeDb() {
    if (_prisma) {
        await _prisma.$disconnect();
        _prisma = null;
    }
}
