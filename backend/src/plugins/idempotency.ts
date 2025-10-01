import fp from 'fastify-plugin';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { redis } from '../utils/redis';

const HEADER = 'idempotency-key';
const TTL_SECONDS = 60 * 10; // 10 min window

async function takeLock(key: string) {
  // SET key value NX EX ttl
  const ok = await redis.set(key, '1', 'NX', 'EX', TTL_SECONDS);
  return ok === 'OK';
}

export default fp(async function idempotencyPlugin(fastify: FastifyInstance) {
  fastify.decorate('withIdempotency', function <
    R extends FastifyRequest = FastifyRequest
  >(handler: (req: R) => any, makeKey?: (req: R) => string | null) {
    return async function wrapped(req: R, reply: any) {
      const headerKey = (req.headers[HEADER] as string | undefined)?.trim();
      const customKey = makeKey ? makeKey(req) : null;
      const key = headerKey || customKey;

      if (!key) {
        // No key supplied: process normally (no mock!)
        return handler(req);
      }

      const namespaced = `idem:${key}`;
      const acquired = await takeLock(namespaced);
      if (!acquired) {
        return reply.code(409).send({ error: 'Duplicate request' });
      }

      return handler(req);
    };
  });
});

declare module 'fastify' {
  interface FastifyInstance {
    withIdempotency: <R extends FastifyRequest = FastifyRequest>(
      handler: (req: R) => any,
      makeKey?: (req: R) => string | null
    ) => (req: R, reply: any) => any;
  }
}
