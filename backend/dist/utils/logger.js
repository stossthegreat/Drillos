"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
exports.childLogger = childLogger;
// src/utils/logger.ts
const pino_1 = __importDefault(require("pino"));
const env_1 = require("./env");
const redactions = [
    'req.headers.authorization',
    'headers.authorization',
    'OPENAI_API_KEY',
    'ELEVENLABS_API_KEY',
    'FIREBASE_PRIVATE_KEY',
    'STRIPE_SECRET_KEY',
    'STRIPE_WEBHOOK_SECRET',
];
exports.logger = (0, pino_1.default)({
    level: process.env.LOG_LEVEL || (env_1.isDev ? 'debug' : 'info'),
    redact: { paths: redactions, censor: '[REDACTED]' },
    transport: env_1.isDev
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
function childLogger(bindings) {
    return exports.logger.child(bindings);
}
