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
export declare function requireAuth(req: FastifyRequest, reply: FastifyReply): Promise<void>;
