// src/plugins/auth.plugin.ts
import fp from 'fastify-plugin';
import jwt from 'jsonwebtoken';

declare module 'fastify' {
  interface FastifyRequest {
    user?: { id: string; email?: string; plan?: string; mentorId?: string };
  }
}

export default fp(async (fastify) => {
  fastify.decorateRequest('user', null);

  fastify.addHook('preHandler', async (req, reply) => {
    const auth = req.headers['authorization'];

    if (!auth?.startsWith('Bearer ')) {
      return reply.code(401).send({ error: 'Unauthorized: missing token' });
    }

    try {
      const token = auth.replace('Bearer ', '');
      const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;

      req.user = {
        id: decoded.sub,
        email: decoded.email,
        plan: decoded.plan ?? 'FREE',
        mentorId: decoded.mentorId ?? 'drill',
      };
    } catch (err: any) {
      return reply.code(401).send({ error: 'Unauthorized: invalid token' });
    }
  });
});
