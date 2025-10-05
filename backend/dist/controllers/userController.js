import { prisma } from '../utils/database';
import { emailService } from '../services/emailService';
export class UserController {
    async createUser(request, reply) {
        try {
            const { email, tz = 'Europe/London', tone = 'balanced', intensity = 2 } = request.body;
            const existingUser = await prisma.user.findUnique({
                where: { email },
            });
            if (existingUser) {
                return reply.code(409).send({
                    error: 'User already exists',
                    message: 'A user with this email already exists',
                });
            }
            const user = await prisma.user.create({
                data: {
                    email,
                    tz,
                    tone,
                    intensity,
                },
            });
            try {
                await emailService.sendWelcomeEmail(email, email.split('@')[0] || 'User');
            }
            catch (emailError) {
                console.error('Failed to send welcome email:', emailError);
            }
            return reply.code(201).send({
                success: true,
                data: {
                    id: user.id,
                    email: user.email,
                    tz: user.tz,
                    tone: user.tone,
                    intensity: user.intensity,
                    plan: user.plan,
                    createdAt: user.createdAt,
                },
            });
        }
        catch (error) {
            console.error('Error creating user:', error);
            return reply.code(500).send({
                error: 'Internal server error',
                message: 'Failed to create user',
            });
        }
    }
    async getUser(request, reply) {
        try {
            const { id } = request.params;
            const user = await prisma.user.findUnique({
                where: { id },
                select: {
                    id: true,
                    email: true,
                    tz: true,
                    tone: true,
                    intensity: true,
                    consentRoast: true,
                    plan: true,
                    createdAt: true,
                    updatedAt: true,
                },
            });
            if (!user) {
                return reply.code(404).send({
                    error: 'User not found',
                    message: 'No user found with the provided ID',
                });
            }
            return reply.send({
                success: true,
                data: user,
            });
        }
        catch (error) {
            console.error('Error fetching user:', error);
            return reply.code(500).send({
                error: 'Internal server error',
                message: 'Failed to fetch user',
            });
        }
    }
    async updateUser(request, reply) {
        try {
            const { id } = request.params;
            const updateData = request.body;
            const existingUser = await prisma.user.findUnique({
                where: { id },
            });
            if (!existingUser) {
                return reply.code(404).send({
                    error: 'User not found',
                    message: 'No user found with the provided ID',
                });
            }
            const updatedUser = await prisma.user.update({
                where: { id },
                data: updateData,
                select: {
                    id: true,
                    email: true,
                    tz: true,
                    tone: true,
                    intensity: true,
                    consentRoast: true,
                    plan: true,
                    updatedAt: true,
                },
            });
            return reply.send({
                success: true,
                data: updatedUser,
            });
        }
        catch (error) {
            console.error('Error updating user:', error);
            return reply.code(500).send({
                error: 'Internal server error',
                message: 'Failed to update user',
            });
        }
    }
    async deleteUser(request, reply) {
        try {
            const { id } = request.params;
            const existingUser = await prisma.user.findUnique({
                where: { id },
            });
            if (!existingUser) {
                return reply.code(404).send({
                    error: 'User not found',
                    message: 'No user found with the provided ID',
                });
            }
            await prisma.user.delete({
                where: { id },
            });
            return reply.send({
                success: true,
                message: 'User deleted successfully',
            });
        }
        catch (error) {
            console.error('Error deleting user:', error);
            return reply.code(500).send({
                error: 'Internal server error',
                message: 'Failed to delete user',
            });
        }
    }
    async getUsers(request, reply) {
        try {
            const { page = 1, limit = 10 } = request.query;
            const skip = (page - 1) * limit;
            const [users, total] = await Promise.all([
                prisma.user.findMany({
                    skip,
                    take: limit,
                    select: {
                        id: true,
                        email: true,
                        tz: true,
                        tone: true,
                        intensity: true,
                        plan: true,
                        createdAt: true,
                    },
                    orderBy: { createdAt: 'desc' },
                }),
                prisma.user.count(),
            ]);
            return reply.send({
                success: true,
                data: users,
                pagination: {
                    page,
                    limit,
                    total,
                    pages: Math.ceil(total / limit),
                },
            });
        }
        catch (error) {
            console.error('Error fetching users:', error);
            return reply.code(500).send({
                error: 'Internal server error',
                message: 'Failed to fetch users',
            });
        }
    }
}
export const userController = new UserController();
export default userController;
//# sourceMappingURL=userController.js.map