"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = briefRoutes;
const brief_service_1 = require("../services/brief.service");
const today_service_1 = require("../services/today.service");
const db_1 = require("../utils/db");
function getUserIdOrThrow(req) {
    const uid = req?.user?.id || req.headers['x-user-id'];
    if (!uid || typeof uid !== 'string') {
        throw new Error('Unauthorized: missing user id');
    }
    return uid;
}
async function briefRoutes(fastify, _opts) {
    // Helper to ensure demo user exists
    async function ensureDemoUser(userId) {
        if (userId === "demo-user-123") {
            const existingUser = await db_1.prisma.user.findUnique({ where: { id: userId } });
            if (!existingUser) {
                await db_1.prisma.user.create({
                    data: {
                        id: userId,
                        email: "demo@drillsergeant.com",
                        tz: "Europe/London",
                        tone: "balanced",
                        intensity: 2,
                        consentRoast: false,
                        plan: "FREE",
                        mentorId: "marcus",
                        nudgesEnabled: true,
                        briefsEnabled: true,
                        debriefsEnabled: true,
                    },
                });
                console.log("✅ Created demo user:", userId);
            }
        }
    }
    // GET /v1/brief/today - returns habits, tasks, and today's selections
    fastify.get('/v1/brief/today', {
        schema: {
            tags: ['Brief'],
            summary: 'Get today\'s morning brief',
            response: {
                200: { type: 'object' },
                400: { type: 'object' }
            }
        },
    }, async (req, reply) => {
        try {
            const userId = getUserIdOrThrow(req);
            await ensureDemoUser(userId);
            // DIRECT IMPLEMENTATION - bypass service for now
            const { HabitsService } = await Promise.resolve().then(() => __importStar(require('../services/habits.service')));
            const { tasksService } = await Promise.resolve().then(() => __importStar(require('../services/tasks.service')));
            const habitsService = new HabitsService();
            const habits = await habitsService.list(userId);
            const tasks = await tasksService.list(userId, true); // Include completed tasks
            const todaySelections = await db_1.prisma.todaySelection.findMany({
                where: { userId, date: new Date().toISOString().split('T')[0] },
                include: { habit: true, task: true },
            });
            const today = todaySelections.map(sel => {
                if (sel.habit)
                    return {
                        id: sel.habit.id, name: sel.habit.title, type: 'habit',
                        completed: sel.habit.lastTick ? new Date(sel.habit.lastTick).toDateString() === new Date().toDateString() : false,
                        streak: sel.habit.streak, color: sel.habit.color ?? 'emerald',
                    };
                if (sel.task)
                    return {
                        id: sel.task.id, name: sel.task.title, type: 'task',
                        completed: sel.task.completed, priority: sel.task.priority,
                    };
                return null;
            }).filter(Boolean);
            return {
                mentor: 'marcus',
                message: 'Begin your mission today.',
                audio: null,
                missions: habits,
                habits,
                tasks,
                today
            };
        }
        catch (e) {
            console.error('❌ Brief error:', e);
            return reply.code(400).send({ error: e.message || String(e) });
        }
    });
    // GET /v1/brief/evening
    fastify.get('/v1/brief/evening', {
        schema: {
            tags: ['Brief'],
            summary: 'Get evening debrief',
            response: {
                200: { type: 'object' },
                400: { type: 'object' }
            }
        },
    }, async (req, reply) => {
        try {
            const userId = getUserIdOrThrow(req);
            await ensureDemoUser(userId);
            return await brief_service_1.briefService.getEveningDebrief(userId);
        }
        catch (e) {
            return reply.code(400).send({ error: e.message });
        }
    });
    // POST /v1/brief/today/select
    fastify.post('/v1/brief/today/select', {
        schema: {
            tags: ['Brief'],
            summary: 'Select a habit or task for today',
            body: {
                type: 'object',
                properties: {
                    habitId: { type: 'string' },
                    taskId: { type: 'string' },
                    date: { type: 'string' },
                },
            },
            response: { 200: { type: 'object' }, 400: { type: 'object' } },
        },
    }, async (req, reply) => {
        try {
            const userId = getUserIdOrThrow(req);
            await ensureDemoUser(userId);
            const body = req.body;
            if (!body.habitId && !body.taskId) {
                return reply.code(400).send({ error: 'habitId or taskId is required' });
            }
            const res = await today_service_1.todayService.selectForToday(userId, body.habitId, body.taskId, body.date);
            return res;
        }
        catch (e) {
            return reply.code(400).send({ error: e.message });
        }
    });
    // TEST ENDPOINT - direct habits/tasks with today selections
    fastify.get('/v1/brief/test', async (req, reply) => {
        try {
            const userId = getUserIdOrThrow(req);
            await ensureDemoUser(userId);
            const { HabitsService } = await Promise.resolve().then(() => __importStar(require('../services/habits.service')));
            const { tasksService } = await Promise.resolve().then(() => __importStar(require('../services/tasks.service')));
            const habitsService = new HabitsService();
            const habits = await habitsService.list(userId);
            const tasks = await tasksService.list(userId, true); // Include completed tasks
            // Get today's selections
            const todaySelections = await db_1.prisma.todaySelection.findMany({
                where: { userId, date: new Date().toISOString().split('T')[0] },
                include: { habit: true, task: true },
            });
            const today = todaySelections.map(sel => {
                if (sel.habit)
                    return {
                        id: sel.habit.id, name: sel.habit.title, type: 'habit',
                        completed: sel.habit.lastTick ? new Date(sel.habit.lastTick).toDateString() === new Date().toDateString() : false,
                        streak: sel.habit.streak, color: sel.habit.color ?? 'emerald',
                    };
                if (sel.task)
                    return {
                        id: sel.task.id, name: sel.task.title, type: 'task',
                        completed: sel.task.completed, priority: sel.task.priority,
                    };
                return null;
            }).filter(Boolean);
            return {
                success: true,
                mentor: 'marcus',
                message: 'Begin your mission today.',
                audio: null,
                habitsCount: habits.length,
                tasksCount: tasks.length,
                todayCount: today.length,
                habits,
                tasks,
                today
            };
        }
        catch (e) {
            return { error: e.message, stack: e.stack };
        }
    });
    // POST /v1/brief/today/deselect
    fastify.post('/v1/brief/today/deselect', {
        schema: {
            tags: ['Brief'],
            summary: 'Deselect (remove) a habit or task from today',
            body: {
                type: 'object',
                properties: {
                    habitId: { type: 'string' },
                    taskId: { type: 'string' },
                    date: { type: 'string' },
                },
            },
            response: { 200: { type: 'object' }, 400: { type: 'object' } },
        },
    }, async (req, reply) => {
        try {
            const userId = getUserIdOrThrow(req);
            const body = req.body;
            if (!body.habitId && !body.taskId) {
                return reply.code(400).send({ error: 'habitId or taskId is required' });
            }
            const res = await today_service_1.todayService.deselectForToday(userId, body.habitId, body.taskId, body.date);
            return res;
        }
        catch (e) {
            return reply.code(400).send({ error: e.message });
        }
    });
}
