// src/services/streaks.service.ts
import { prisma } from '../utils/db';

export class StreaksService {
  /**
   * Get a summary of the user’s overall streaks.
   * Returns total streaks, best streak, average, and per-habit breakdown.
   */
  async getStreakSummary(userId: string) {
    const habits = await prisma.habit.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });

    if (habits.length === 0) {
      return {
        overall: 0,
        bestStreak: 0,
        avgStreak: 0,
        habits: [],
      };
    }

    const streaks = habits.map((h) => h.streak);
    const overall = streaks.reduce((a, b) => a + b, 0);
    const bestStreak = Math.max(...streaks);
    const avgStreak = Math.round(overall / habits.length);

    return {
      overall,
      bestStreak,
      avgStreak,
      habits: habits.map((h) => ({
        id: h.id,
        title: h.title,
        streak: h.streak,
        lastTick: h.lastTick,
      })),
    };
  }

  /**
   * Build gamified achievement data from streaks.
   */
  async getUserAchievements(userId: string) {
    const summary = await this.getStreakSummary(userId);

    // XP = sum of all streaks × 10
    const totalXP = summary.overall * 10;
    const level = Math.floor(totalXP / 500) + 1;

    const achievements: { id: string; title: string; unlocked: boolean }[] = [
      { id: 'first_tick', title: 'First Tick', unlocked: totalXP >= 10 },
      { id: 'streak_7', title: 'One Week Streak', unlocked: summary.bestStreak >= 7 },
      { id: 'streak_30', title: 'One Month Streak', unlocked: summary.bestStreak >= 30 },
      { id: 'streak_90', title: '90 Days of Discipline', unlocked: summary.bestStreak >= 90 },
      { id: 'streak_365', title: '1 Year Unbroken', unlocked: summary.bestStreak >= 365 },
    ];

    return {
      totalXP,
      level,
      achievements: achievements.filter((a) => a.unlocked),
      rank: this.calculateRank(level),
      pendingCelebrations: achievements.filter((a) => a.unlocked), // can be used to trigger voice/notifications
    };
  }

  /**
   * Translate level → rank name.
   */
  private calculateRank(level: number): string {
    if (level < 3) return 'Novice';
    if (level < 6) return 'Disciple';
    if (level < 10) return 'Warrior';
    if (level < 20) return 'Master';
    return 'Legend';
  }
}

export const streaksService = new StreaksService();
