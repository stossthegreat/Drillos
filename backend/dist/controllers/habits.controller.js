"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.habitsController = habitsController;
const habits_service_1 = require("../services/habits.service");
const db_1 = require("../utils/db");
async function habitsController(fastify) {
    // 🧠 Ensure demo user exists (for local/testing mode)
    async function ensureDemoUser(userId) {
        if (userId === "demo-user-123") {
            const exists = await db_1.prisma.user.findUnique({ where: { id: userId } });
            if (!exists) {
                await db_1.prisma.user.create({
                    data: {
                        id: userId,
                        email: "demo@drillsergeant.com",
                        mentorId: "marcus",
                        tone: "balanced",
                        intensity: 2,
                        plan: "FREE",
                    },
                });
                console.log("✅ Created demo user:", userId);
            }
        }
    }
    // ✅ GET habits
    fastify.get("/api/v1/habits", async (req, reply) => {
        const userId = req.user?.id || req.headers["x-user-id"] || "demo-user-123";
        await ensureDemoUser(userId);
        const habits = await habits_service_1.habitsService.list(userId);
        reply.send(habits);
    });
    // ✅ CREATE habit
    fastify.post("/api/v1/habits", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"] || "demo-user-123";
            await ensureDemoUser(userId);
            const habit = await habits_service_1.habitsService.create(userId, req.body);
            reply.code(201).send(habit);
        }
        catch (e) {
            console.error("❌ Error creating habit:", e);
            reply.code(400).send({ error: e.message });
        }
    });
    // ✅ TICK habit (mark complete)
    fastify.post("/api/v1/habits/:id/tick", async (req, reply) => {
        const userId = req.user?.id || req.headers["x-user-id"] || "demo-user-123";
        const id = req.params["id"];
        const date = req.body?.date;
        const idempotencyKey = req.headers["idempotency-key"] ||
            req.headers["Idempotency-Key"] ||
            undefined;
        const result = await habits_service_1.habitsService.tick({
            habitId: id,
            userId,
            dateISO: date,
            idempotencyKey,
        });
        reply.send(result);
    });
    // ✅ DELETE habit (fix for "Body cannot be empty" bug)
    fastify.delete("/api/v1/habits/:id", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"] || "demo-user-123";
            const id = req.params["id"];
            await ensureDemoUser(userId);
            // 🔥 PATCH: allow empty JSON bodies from Flutter
            if (req.headers["content-type"]?.includes("application/json") && !req.body) {
                req.body = {};
            }
            const result = await habits_service_1.habitsService.delete(id, userId);
            reply.code(200).send(result);
        }
        catch (e) {
            console.error("❌ Error deleting habit:", e);
            reply.code(400).send({ error: e.message });
        }
    });
}
