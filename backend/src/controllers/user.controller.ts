import { FastifyInstance } from "fastify";
import { UserService } from "../services/user.service";

export async function userController(fastify: FastifyInstance) {
  const userService = new UserService();

  // GET current user profile
  fastify.get("/api/v1/users/me", async (request: any, reply) => {
    const userId = request.user?.id; // you’ll connect this to auth later
    if (!userId) return reply.code(401).send({ error: "Unauthorized" });

    const user = await userService.getUser(userId);
    return user;
  });

  // PATCH update user profile
  fastify.patch("/api/v1/users/me", async (request: any, reply) => {
    const userId = request.user?.id;
    if (!userId) return reply.code(401).send({ error: "Unauthorized" });

    const updates = request.body as { mentorId?: string; tone?: string; intensity?: number };

    // only allow valid mentors
    if (updates.mentorId && !["marcus", "drill", "confucius", "lincoln", "buddha"].includes(updates.mentorId)) {
      return reply.code(400).send({ error: "Invalid mentorId" });
    }

    const updatedUser = await userService.updateUser(userId, updates);
    return updatedUser;
  });
}
