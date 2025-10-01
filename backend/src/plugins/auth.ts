import fp from 'fastify-plugin';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import jwt from 'jsonwebtoken';

declare module 'fastify' {
  interface FastifyRequest {
    user?: { id: string };
  }
}

type Decoded = { sub?: string; userId?: string; id?: string };

const HEADER_USER_ID = 'x-user-id';

export default fp(async function authPlugin(fastify: FastifyInstance) {
  fastify.decorateRequest('user', null);

  fastify.addHook('preHandler', async (req: FastifyRequest, reply) => {
    // 1) Prefer explicit header (mobile/web can set this)
    const headerUser = (req.headers[HEADER_USER_ID] as string | undefined)?.trim();
    if (headerUser) {
      req.user = { id: headerUser };
      return;
    }

    // 2) Try Bearer JWT if provided
    const auth = req.headers.authorization;
    if (auth && auth.startsWith('Bearer ')) {
      const token = auth.slice('Bearer '.length).trim();
      const secret = process.env.JWT_PUBLIC_KEY || process.env.JWT_SECRET;
      if (!secret) {
        reply.code(500).send({ error: 'Server auth misconfiguration' });
        return;
      }
      try {
        const decoded = jwt.verify(token, secret, {
          algorithms: process.env.JWT_PUBLIC_KEY ? ['RS256'] : ['HS256'],
        }) as Decoded;
        const uid = decoded.sub || decoded.userId || decoded.id;
        if (uid) {
          req.user = { id: uid };
          return;
        }
      } catch {
        // fall-through
      }
    }

    // 3) Hard-fail (NO DEMO, NO MOCK)
    reply.code(401).send({ error: 'Unauthorized: missing user identity' });
  });
});
