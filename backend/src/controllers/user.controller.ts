// src/controllers/user.controller.ts
import { FastifyInstance } from "fastify";
import { prisma } from "../utils/db";

export async function userController(fastify: FastifyInstance) {
  // Helper to get userId from auth or header
  const getUserId = (req: any) => req?.user?.id || req.headers["x-user-id"];

  // GET /api/v1/users/me
  fastify.get("/api/v1/users/me", async (req: any, reply) => {
    const userId = getUserId(req);
    if (!userId) return reply.code(401).send({ error: "Unauthorized" });
    const user = await prisma.user.findUnique({ where: { id: String(userId) } });
    if (!user) return reply.code(404).send({ error: "User not found" });
    return user;
  });

  // PATCH /api/v1/users/me
  fastify.patch("/api/v1/users/me", async (req: any, reply) => {
    const userId = getUserId(req);
    if (!userId) return reply.code(401).send({ error: "Unauthorized" });

    const allowedMentors = ["marcus", "drill", "confucius", "lincoln", "buddha"];
    const body = req.body as {
      tone?: "strict" | "balanced" | "light";
      intensity?: number;
      mentorId?: string;
      fcmToken?: string;
      plan?: "FREE" | "PRO";
    };

    if (body.mentorId && !allowedMentors.includes(body.mentorId)) {
      return reply.code(400).send({ error: "Invalid mentorId" });
    }

    const updated = await prisma.user.update({
      where: { id: String(userId) },
      data: {
        tone: body.tone as any,
        intensity: typeof body.intensity === "number" ? body.intensity : undefined,
        mentorId: body.mentorId,
        fcmToken: body.fcmToken,
        plan: body.plan as any, // keep admin-only on FE
      },
    });

    return updated;
  });

  // GET /api/v1/users/me/preferences
  fastify.get("/api/v1/users/me/preferences", async (req: any, reply) => {
    const userId = getUserId(req);
    if (!userId) return reply.code(401).send({ error: "Unauthorized" });
    const u = await prisma.user.findUnique({
      where: { id: String(userId) },
      select: {
        nudgesEnabled: true,
        briefsEnabled: true,
        debriefsEnabled: true,
        plan: true,
        mentorId: true,
      },
    });
    if (!u) return reply.code(404).send({ error: "User not found" });
    return u;
  });

  // PATCH /api/v1/users/me/preferences
  fastify.patch("/api/v1/users/me/preferences", async (req: any, reply) => {
    const userId = getUserId(req);
    if (!userId) return reply.code(401).send({ error: "Unauthorized" });

    const body = req.body as {
      nudgesEnabled?: boolean;
      briefsEnabled?: boolean;
      debriefsEnabled?: boolean;
    };

    const updated = await prisma.user.update({
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
  fastify.post("/api/v1/users/me/fcm-token", async (req: any, reply) => {
    const userId = getUserId(req);
    if (!userId) return reply.code(401).send({ error: "Unauthorized" });
    const { token } = req.body as { token: string };
    if (!token) return reply.code(400).send({ error: "token required" });

    await prisma.user.update({
      where: { id: String(userId) },
      data: { fcmToken: token },
    });

    return { ok: true };
  });
}
