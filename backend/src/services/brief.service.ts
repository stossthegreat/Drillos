// src/services/brief.service.ts
import { prisma } from '../utils/db';
import { habitsService } from './habits.service';
import { alarmsService } from './alarms.service';
import { eventsService } from './events.service';

// Mentor personalities
const mentors = {
  marcus: {
    id: 'marcus',
    name: 'Marcus Aurelius',
    tone: 'stoic',
    lines: {
      morning: (habits: any[]) =>
        `Discipline begins today. ${habits.length} duties await you. Perform them as if your whole life depended on it.`,
      evening: (completed: number, total: number) =>
        `Today, you completed ${completed}/${total}. Reflect: Did you act with virtue, or with delay?`,
    },
  },
  drill: {
    id: 'drill',
    name: 'Drill Sergeant',
    tone: 'strict',
    lines: {
      morning: (habits: any[]) =>
        `Listen up! You’ve got ${habits.length} missions. No excuses. No delays. MOVE.`,
      evening: (completed: number, total: number) =>
        `Results: ${completed}/${total}. If you slacked, square one. Tomorrow, no mercy.`,
    },
  },
  confucius: {
    id: 'confucius',
    name: 'Confucius',
    tone: 'balanced',
    lines: {
      morning: (habits: any[]) =>
        `A journey of ${habits.length} steps today. Keep order, and balance shall follow.`,
      evening: (completed: number, total: number) =>
        `Harmony check: ${completed}/${total} done. Where there is imbalance, correct it.`,
    },
  },
  lincoln: {
    id: 'lincoln',
    name: 'Abraham Lincoln',
    tone: 'inspirational',
    lines: {
      morning: (habits: any[]) =>
        `Self-government begins now. ${habits.length} tasks are your nation. Rule them well.`,
      evening: (completed: number, total: number) =>
        `Leadership report: ${completed}/${total} complete. A man is measured by consistency.`,
    },
  },
  buddha: {
    id: 'buddha',
    name: 'Buddha',
    tone: 'light',
    lines: {
      morning: (habits: any[]) =>
        `Be still. ${habits.length} seeds to water today. Each habit, a breath toward awakening.`,
      evening: (completed: number, total: number) =>
        `Meditation: ${completed}/${total} complete. Let go of craving. Tomorrow is new.`,
    },
  },
};

export const briefService = {
  async getTodaysBrief(userId: string) {
    // get habits from DB
    const habits = await habitsService.list(userId);
    const now = new Date();
    const today = now.toDateString();

    const missions = habits.map((h) => {
      const doneToday =
        h.lastTick && new Date(h.lastTick).toDateString() === today;
      return {
        id: h.id,
        title: h.title,
        streak: h.streak,
        status: doneToday ? 'completed' : 'pending',
      };
    });

    const riskBanners = habits
      .filter((h) => {
        const daysSince = h.lastTick
          ? Math.floor((now.getTime() - new Date(h.lastTick).getTime()) / 86400000)
          : 999;
        return daysSince > 1 && h.streak > 5;
      })
      .map((h) => ({
        type: 'streak_save',
        habitId: h.id,
        message: `${h.title} streak at risk! Don’t break the chain.`,
      }));

    // pick mentor voice (for now default Marcus — later tie to user choice)
    const mentor = mentors.marcus;

    return {
      mentor: mentor.name,
      message: mentor.lines.morning(habits),
      missions,
      riskBanners,
      nudges: this.generateNudges(habits, riskBanners.length > 0),
    };
  },

  async getEveningDebrief(userId: string) {
    const habits = await habitsService.list(userId);
    const today = new Date().toDateString();

    const completed = habits.filter(
      (h) => h.lastTick && new Date(h.lastTick).toDateString() === today
    ).length;

    const mentor = mentors.drill; // evening drill sergeant by default for impact

    return {
      mentor: mentor.name,
      message: mentor.lines.evening(completed, habits.length),
      stats: { completed, total: habits.length },
      reflections: this.generateReflections(userId, habits),
    };
  },

  generateNudges(habits: any[], hasRisks: boolean) {
    const nudges: any[] = [];
    if (hasRisks) {
      nudges.push({
        type: 'streak_save',
        title: 'Save Your Streak',
        message: 'One habit slipping. Get back on it now.',
        priority: 'high',
      });
    }
    const undone = habits.filter(
      (h) =>
        !h.lastTick ||
        new Date(h.lastTick).toDateString() !== new Date().toDateString()
    );
    if (undone.length > 0) {
      nudges.push({
        type: 'daily_reminder',
        title: 'Habits pending',
        message: `${undone.length} still incomplete.`,
        priority: 'medium',
      });
    }
    return nudges;
  },

  generateReflections(userId: string, habits: any[]) {
    // Later: use eventsService to analyze
    return [
      `Today you fought ${habits.length} battles.`,
      `Your strongest habit: ${
        habits.sort((a, b) => b.streak - a.streak)[0]?.title || 'None'
      }.`,
    ];
  },
};
