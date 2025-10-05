"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserService = void 0;
const db_1 = require("../utils/db");
class UserService {
    async getUser(userId) {
        return db_1.prisma.user.findUnique({
            where: { id: userId },
        });
    }
    async updateUser(userId, updates) {
        return db_1.prisma.user.update({
            where: { id: userId },
            data: {
                ...(updates.mentorId && { mentorId: updates.mentorId }),
                ...(updates.tone && { tone: updates.tone }),
                ...(updates.intensity && { intensity: updates.intensity }),
                updatedAt: new Date(),
            },
        });
    }
}
exports.UserService = UserService;
