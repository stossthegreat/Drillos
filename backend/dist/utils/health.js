"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkDependencies = checkDependencies;
exports.assertHealthyOrLog = assertHealthyOrLog;
const db_1 = require("./db");
const redis_1 = require("./redis");
const openai_1 = __importDefault(require("openai"));
const stripe_1 = __importDefault(require("stripe"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
async function checkDependencies() {
    const results = {};
    try {
        await db_1.prisma.$queryRaw `SELECT 1`;
        results.postgres = 'ok';
    }
    catch (e) {
        results.postgres = `error: ${e.message}`;
    }
    try {
        await redis_1.redis.ping();
        results.redis = 'ok';
    }
    catch (e) {
        results.redis = `error: ${e.message}`;
    }
    try {
        if (!process.env.OPENAI_API_KEY) {
            results.openai = 'error: OpenAI API key not configured';
        }
        else {
            const client = new openai_1.default({ apiKey: process.env.OPENAI_API_KEY });
            await client.models.list();
            results.openai = 'ok';
        }
    }
    catch (e) {
        results.openai = `error: ${e.message}`;
    }
    try {
        const res = await fetch('https://api.elevenlabs.io/v1/voices', {
            headers: { 'xi-api-key': process.env.ELEVENLABS_API_KEY },
        });
        results.elevenlabs = res.ok ? 'ok' : `error: ${res.statusText}`;
    }
    catch (e) {
        results.elevenlabs = `error: ${e.message}`;
    }
    try {
        if (!firebase_admin_1.default.apps.length) {
            firebase_admin_1.default.initializeApp({
                credential: firebase_admin_1.default.credential.cert({
                    projectId: process.env.FIREBASE_PROJECT_ID,
                    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
                    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
                }),
            });
        }
        results.firebase = 'ok';
    }
    catch (e) {
        results.firebase = `error: ${e.message}`;
    }
    try {
        const stripe = new stripe_1.default(process.env.STRIPE_SECRET_KEY, { apiVersion: '2025-08-27.basil' });
        await stripe.accounts.retrieve();
        results.stripe = 'ok';
    }
    catch (e) {
        results.stripe = `error: ${e.message}`;
    }
    return results;
}
async function assertHealthyOrLog(userId) {
    const checks = await checkDependencies();
    const failures = Object.entries(checks).filter(([_, v]) => v !== 'ok');
    if (failures.length > 0) {
        await db_1.prisma.event.create({
            data: {
                userId,
                type: 'system_alert',
                payload: { failures },
            },
        });
        return false;
    }
    return true;
}
