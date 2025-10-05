"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.userController = userController;
const db_1 = require("../utils/db");
async function userController(fastify) {
    // Helper to get userId from auth or header
    const getUserId = (req) => req?.user?.id || req.headers["x-user-id"];
    // GET /api/v1/users/me
    fastify.get("/api/v1/users/me", async (req, reply) => {
        const userId = getUserId(req);
        if (!userId)
            return reply.code(401).send({ error: "Unauthorized" });
        const user = await db_1.prisma.user.findUnique({ where: { id: String(userId) } });
        if (!user)
            return reply.code(404).send({ error: "User not found" });
        return user;
    });
    // PATCH /api/v1/users/me
    fastify.patch("/api/v1/users/me", async (req, reply) => {
        const userId = getUserId(req);
        if (!userId)
            return reply.code(401).send({ error: "Unauthorized" });
        const allowedMentors = ["marcus", "drill", "confucius", "lincoln", "buddha"];
        const body = req.body;
        if (body.mentorId && !allowedMentors.includes(body.mentorId)) {
            return reply.code(400).send({ error: "Invalid mentorId" });
        }
        const updated = await db_1.prisma.user.update({
            where: { id: String(userId) },
            data: {
                tone: body.tone,
                intensity: typeof body.intensity === "number" ? body.intensity : undefined,
                mentorId: body.mentorId,
                fcmToken: body.fcmToken,
                plan: body.plan, // keep admin-only on FE
            },
        });
        return updated;
    });
    // GET /api/v1/users/me/preferences
    fastify.get("/api/v1/users/me/preferences", async (req, reply) => {
        const userId = getUserId(req);
        if (!userId)
            return reply.code(401).send({ error: "Unauthorized" });
        const u = await db_1.prisma.user.findUnique({
            where: { id: String(userId) },
            select: {
                nudgesEnabled: true,
                briefsEnabled: true,
                debriefsEnabled: true,
                plan: true,
                mentorId: true,
            },
        });
        if (!u)
            return reply.code(404).send({ error: "User not found" });
        return u;
    });
    // PATCH /api/v1/users/me/preferences
    fastify.patch("/api/v1/users/me/preferences", async (req, reply) => {
        const userId = getUserId(req);
        if (!userId)
            return reply.code(401).send({ error: "Unauthorized" });
        const body = req.body;
        const updated = await db_1.prisma.user.update({
            where: { id: String(userId) },
            data: {
                nudgesEnabled: typeof body.nudgesEnabled === "boolean" ? body.nudgesEnabled : undefined,
                briefsEnabled: typeof body.briefsEnabled === "boolean" ? body.briefsEnabled : undefined,
                debriefsEnabled: typeof body.debriefsEnabled === "boolean" ? body.debriefsEnabled : undefined,
            },
        });
        return updated;
    });
    // POST /api/v1/users/me/fcm-token
    fastify.post("/api/v1/users/me/fcm-token", async (req, reply) => {
        const userId = getUserId(req);
        if (!userId)
            return reply.code(401).send({ error: "Unauthorized" });
        const { token } = req.body;
        if (!token)
            return reply.code(400).send({ error: "token required" });
        await db_1.prisma.user.update({
            where: { id: String(userId) },
            data: { fcmToken: token },
        });
        return { ok: true };
    });
}
