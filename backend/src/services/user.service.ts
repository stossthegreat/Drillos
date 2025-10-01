import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

export class UserService {
  async getUser(userId: string) {
    return prisma.user.findUnique({
      where: { id: userId },
    });
  }

  async updateUser(userId: string, updates: { mentorId?: string; tone?: string; intensity?: number }) {
    return prisma.user.update({
      where: { id: userId },
      data: {
        ...(updates.mentorId && { mentorId: updates.mentorId }),
        ...(updates.tone && { tone: updates.tone as any }),
        ...(updates.intensity && { intensity: updates.intensity }),
        updatedAt: new Date(),
      },
    });
  }
}
