import { FastifyRequest, FastifyReply } from 'fastify';
import { prisma } from '../utils/database';
import { emailService } from '../services/emailService';

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

export class UserController {
  async createUser(request: FastifyRequest<{ Body: CreateUserRequest }>, reply: FastifyReply) {
    try {
      const { email, tz = 'Europe/London', tone = 'balanced', intensity = 2 } = request.body;

      // Check if user already exists
      const existingUser = await prisma.user.findUnique({
        where: { email },
      });

      if (existingUser) {
        return reply.code(409).send({
          error: 'User already exists',
          message: 'A user with this email already exists',
        });
      }

      // Create new user
      const user = await prisma.user.create({
        data: {
          email,
          tz,
          tone,
          intensity,
        },
      });

      // Send welcome email
      try {
        await emailService.sendWelcomeEmail(email, email.split('@')[0] || 'User');
      } catch (emailError) {
        console.error('Failed to send welcome email:', emailError);
        // Don't fail the user creation if email fails
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
    } catch (error) {
      console.error('Error creating user:', error);
      return reply.code(500).send({
        error: 'Internal server error',
        message: 'Failed to create user',
      });
    }
  }

  async getUser(request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) {
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
    } catch (error) {
      console.error('Error fetching user:', error);
      return reply.code(500).send({
        error: 'Internal server error',
        message: 'Failed to fetch user',
      });
    }
  }

  async updateUser(request: FastifyRequest<{ Params: { id: string }; Body: UpdateUserRequest }>, reply: FastifyReply) {
    try {
      const { id } = request.params;
      const updateData = request.body;

      // Check if user exists
      const existingUser = await prisma.user.findUnique({
        where: { id },
      });

      if (!existingUser) {
        return reply.code(404).send({
          error: 'User not found',
          message: 'No user found with the provided ID',
        });
      }

      // Update user
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
    } catch (error) {
      console.error('Error updating user:', error);
      return reply.code(500).send({
        error: 'Internal server error',
        message: 'Failed to update user',
      });
    }
  }

  async deleteUser(request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) {
    try {
      const { id } = request.params;

      // Check if user exists
      const existingUser = await prisma.user.findUnique({
        where: { id },
      });

      if (!existingUser) {
        return reply.code(404).send({
          error: 'User not found',
          message: 'No user found with the provided ID',
        });
      }

      // Delete user (cascade will handle related records)
      await prisma.user.delete({
        where: { id },
      });

      return reply.send({
        success: true,
        message: 'User deleted successfully',
      });
    } catch (error) {
      console.error('Error deleting user:', error);
      return reply.code(500).send({
        error: 'Internal server error',
        message: 'Failed to delete user',
      });
    }
  }

  async getUsers(request: FastifyRequest, reply: FastifyReply) {
    try {
      const { page = 1, limit = 10 } = request.query as { page?: number; limit?: number };
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
    } catch (error) {
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
