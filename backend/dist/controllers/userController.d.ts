import { FastifyRequest, FastifyReply } from 'fastify';
interface CreateUserRequest {
    email: string;
    tz?: string;
    tone?: 'strict' | 'balanced' | 'light';
    intensity?: number;
}
interface UpdateUserRequest {
    tz?: string;
    tone?: 'strict' | 'balanced' | 'light';
    intensity?: number;
    consentRoast?: boolean;
    safeWord?: string;
}
export declare class UserController {
    createUser(request: FastifyRequest<{
        Body: CreateUserRequest;
    }>, reply: FastifyReply): Promise<never>;
    getUser(request: FastifyRequest<{
        Params: {
            id: string;
        };
    }>, reply: FastifyReply): Promise<never>;
    updateUser(request: FastifyRequest<{
        Params: {
            id: string;
        };
        Body: UpdateUserRequest;
    }>, reply: FastifyReply): Promise<never>;
    deleteUser(request: FastifyRequest<{
        Params: {
            id: string;
        };
    }>, reply: FastifyReply): Promise<never>;
    getUsers(request: FastifyRequest, reply: FastifyReply): Promise<never>;
}
export declare const userController: UserController;
export default userController;
//# sourceMappingURL=userController.d.ts.map