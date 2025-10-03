// src/controllers/brief.controller.ts
import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { briefService } from '../services/brief.service';
import { todayService } from '../services/today.service';
import { prisma } from '../utils/db';

function getUserIdOrThrow(req: any): string {
  const uid = req?.user?.id || req.headers['x-user-id'];
  if (!uid || typeof uid !== 'string') {
    throw new Error('Unauthorized: missing user id');
  }
  return uid;
}

export default async function briefRoutes(fastify: FastifyInstance, _opts: FastifyPluginOptions) {
  
  // Helper to ensure demo user exists
  async function ensureDemoUser(userId: string) {
    if (userId === "demo-user-123") {
      const existingUser = await prisma.user.findUnique({ where: { id: userId } });
      if (!existingUser) {
        await prisma.user.create({
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
      const { HabitsService } = await import('../services/habits.service');
      const { tasksService } = await import('../services/tasks.service');
      const habitsService = new HabitsService();
      
      const habits = await habitsService.list(userId);
      const tasks = await tasksService.list(userId, false);
      const todaySelections = await prisma.todaySelection.findMany({
        where: { userId, date: new Date().toISOString().split('T')[0] },
        include: { habit: true, task: true },
      });
      
      const today = todaySelections.map(sel => {
        if (sel.habit) return {
          id: sel.habit.id, name: sel.habit.title, type: 'habit',
          completed: sel.habit.lastTick ? new Date(sel.habit.lastTick).toDateString() === new Date().toDateString() : false,
          streak: sel.habit.streak, color: (sel.habit as any).color ?? 'emerald',
        };
        if (sel.task) return {
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
    } catch (e: any) {
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
      return await briefService.getEveningDebrief(userId);
    } catch (e: any) {
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
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      await ensureDemoUser(userId);
      const body = req.body as { habitId?: string; taskId?: string; date?: string };
      if (!body.habitId && !body.taskId) {
        return reply.code(400).send({ error: 'habitId or taskId is required' });
      }
      const res = await todayService.selectForToday(userId, body.habitId, body.taskId, body.date);
      return res;
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });

  // TEST ENDPOINT - direct habits/tasks
  fastify.get('/v1/brief/test', async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      await ensureDemoUser(userId);
      
      const { HabitsService } = await import('../services/habits.service');
      const { tasksService } = await import('../services/tasks.service');
      const habitsService = new HabitsService();
      
      const habits = await habitsService.list(userId);
      const tasks = await tasksService.list(userId, false);
      
      return { 
        success: true, 
        habitsCount: habits.length, 
        tasksCount: tasks.length,
        habits: habits.slice(0, 2),
        tasks: tasks.slice(0, 2)
      };
    } catch (e: any) {
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
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const body = req.body as { habitId?: string; taskId?: string; date?: string };
      if (!body.habitId && !body.taskId) {
        return reply.code(400).send({ error: 'habitId or taskId is required' });
      }
      const res = await todayService.deselectForToday(userId, body.habitId, body.taskId, body.date);
      return res;
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });
}
