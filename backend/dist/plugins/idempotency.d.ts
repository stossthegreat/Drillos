import type { FastifyInstance } from 'fastify';
declare const _default: (fastify: FastifyInstance) => Promise<void>;
export default _default;
declare module 'fastify' {
    interface FastifyInstance {
        withIdempotency: <R extends FastifyRequest = FastifyRequest>(handler: (req: R) => any, makeKey?: (req: R) => string | null) => (req: R, reply: any) => any;
    }
}
