import type { FastifyInstance } from 'fastify';
declare module 'fastify' {
    interface FastifyRequest {
        user?: {
            id: string;
        };
    }
}
declare const _default: (fastify: FastifyInstance) => Promise<void>;
export default _default;
