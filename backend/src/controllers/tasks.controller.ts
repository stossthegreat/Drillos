import { FastifyInstance } from "fastify";
import { tasksService } from "../services/tasks.service";

function getUserIdOrThrow(req: any): string {
  const uid = req?.user?.id || req.headers["x-user-id"];
  if (!uid || typeof uid !== "string") {
    throw new Error("Unauthorized: missing user id");
  }
  return uid;
}

export async function tasksController(fastify: FastifyInstance) {
  const service = tasksService;

  // GET /api/v1/tasks
  fastify.get("/api/v1/tasks", {
    schema: {
      tags: ["Tasks"],
      summary: "List user's tasks",
      querystring: {
        type: 'object',
        properties: {
          includeCompleted: { type: 'boolean', default: false },
        },
      },
      response: { 200: { type: 'array' }, 400: { type: 'object' }, 401: { type: 'object' } },
    },
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const includeCompleted = req.query.includeCompleted === 'true' || req.query.includeCompleted === true;
      return await service.list(userId, includeCompleted);
    } catch (e: any) {
      return reply.code(401).send({ error: e.message });
    }
  });

  // GET /api/v1/tasks/:id
  fastify.get("/api/v1/tasks/:id", {
    schema: {
      tags: ["Tasks"],
      summary: "Get task by ID",
      params: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
      response: { 200: { type: 'object' }, 400: { type: 'object' }, 401: { type: 'object' }, 404: { type: 'object' } },
    },
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params;
      const task = await service.getById(id, userId);
      if (!task) return reply.code(404).send({ error: "Task not found" });
      return task;
    } catch (e: any) {
      return reply.code(401).send({ error: e.message });
    }
  });

  // POST /api/v1/tasks
  fastify.post("/api/v1/tasks", {
    schema: {
      tags: ["Tasks"],
      summary: "Create a new task",
      body: {
        type: 'object',
        required: ['title'],
        properties: {
          title: { type: 'string' },
          description: { type: 'string' },
          dueDate: { type: 'string', format: 'date-time' },
          priority: { type: 'number', minimum: 1, maximum: 3 },
          category: { type: 'string' },
        },
      },
      response: { 201: { type: 'object' }, 400: { type: 'object' }, 401: { type: 'object' } },
    },
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const task = await service.create(userId, req.body);
      reply.code(201);
      return task;
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });

  // PATCH /api/v1/tasks/:id
  fastify.patch("/api/v1/tasks/:id", {
    schema: {
      tags: ["Tasks"],
      summary: "Update a task",
      params: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
      body: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          description: { type: 'string' },
          dueDate: { type: 'string', format: 'date-time' },
          priority: { type: 'number', minimum: 1, maximum: 3 },
          category: { type: 'string' },
          completed: { type: 'boolean' },
        },
      },
      response: { 200: { type: 'object' }, 400: { type: 'object' }, 401: { type: 'object' } },
    },
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params;
      const updatedTask = await service.update(id, userId, req.body);
      return updatedTask;
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });

  // POST /api/v1/tasks/:id/complete
  fastify.post("/api/v1/tasks/:id/complete", {
    schema: {
      tags: ["Tasks"],
      summary: "Mark a task as complete",
      params: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
      response: { 200: { type: 'object' }, 400: { type: 'object' }, 401: { type: 'object' } },
    },
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params;
      const completedTask = await service.complete(id, userId);
      return completedTask;
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });

  // DELETE /api/v1/tasks/:id
  fastify.delete("/api/v1/tasks/:id", {
    schema: {
      tags: ["Tasks"],
      summary: "Delete a task",
      params: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
      response: { 200: { type: 'object' }, 400: { type: 'object' }, 401: { type: 'object' } },
    },
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params;
      const result = await service.delete(id, userId);
      return result;
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });
}
