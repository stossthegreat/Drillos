import { FastifyRequest, FastifyReply } from 'fastify';

export interface AuthedUser {
  id: string;
  email?: string | null;
}

declare module 'fastify' {
  interface FastifyRequest {
    user?: AuthedUser;
  }
}

/**
 * Minimal auth middleware.
 * Production: swap this to Firebase Admin (verifyIdToken) or your JWT verifier.
 * For now:
 * - Authorization: Bearer valid-token  -> demo-user-123
 * - OR X-User-Id: <userId>             -> trust as user id (for local/dev)
 */
export async function requireAuth(req: FastifyRequest, reply: FastifyReply) {
  const auth = req.headers.authorization;
  const xuid = req.headers['x-user-id'];

  if (typeof xuid === 'string' && xuid.trim().length > 0) {
    req.user = { id: xuid.trim() };
    return;
  }

  if (auth && auth.startsWith('Bearer ')) {
    const token = auth.slice('Bearer '.length).trim();
    if (token === 'valid-token') {
      req.user = { id: 'demo-user-123', email: 'demo@drillsergeant.com' };
      return;
    }
    // TODO: integrate real token verification here
  }

  reply.code(401).send({ error: 'Unauthorized' });
}
