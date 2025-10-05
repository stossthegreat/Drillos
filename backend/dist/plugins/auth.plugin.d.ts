declare module 'fastify' {
    interface FastifyRequest {
        user?: {
            id: string;
            email?: string;
            plan?: string;
            mentorId?: string;
        };
    }
}
declare const _default: (fastify: import("fastify").FastifyInstance<import("fastify").RawServerDefault, import("http").IncomingMessage, import("http").ServerResponse<import("http").IncomingMessage>, import("fastify").FastifyBaseLogger, import("fastify").FastifyTypeProviderDefault>) => Promise<void>;
export default _default;
