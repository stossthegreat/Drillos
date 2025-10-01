import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type Nudge = {
  type: 'streak_save' | 'daily_reminder' | 'momentum' | 'reflection';
  title: string;
  message: string;
  priority: 'low' | 'medium' | 'high';
  audioPresetId?: string;
};

export class BriefService {
  // Call this once per user after onboarding to ensure the two daily briefs exist as alarms
  async ensureDailyBriefAlarms(userId: string, tz = 'Europe/London') {
    // 07:00 (morning) & 21:30 (evening)
    const targets = [
      { label: 'Morning Brief',  rrule: 'FREQ=DAILY;BYHOUR=7;BYMINUTE=0'   },
      { label: 'Evening Debrief', rrule: 'FREQ=DAILY;BYHOUR=21;BYMINUTE=30' },
    ];
    for (const t of targets) {
      const exists = await prisma.alarm.findFirst({ where: { userId, label: t.label } });
      if (!exists) {
        await prisma.alarm.create({
          data: {
            userId,
            label: t.label,
            rrule: t.rrule,
            tone: 'balanced',
            enabled: true,
          }
        });
      }
    }
    return { ok: true };
  }

  private getNextMilestone(streak: number) {
    const milestones = [7, 14, 30, 60, 90, 180, 365];
    return milestones.find(m => m > streak) || null;
  }

  private daysBetween(a: Date, b: Date) {
    return Math.floor((a.getTime() - b.getTime()) / 86_400_000);
  }

  private buildNudges(habits: any[], anyRisk: boolean): Nudge[] {
    const nudges: Nudge[] = [];

    if (anyRisk) {
      nudges.push({
        type: 'streak_save',
        title: 'Save Your Streak',
        message: 'Don\'t let your progress slip — one small rep now.',
        priority: 'high',
        audioPresetId: 'streak_save',
      });
    }

    const incompletes = habits.filter(h => {
      const today = new Date().toDateString();
      return !h.lastTick || new Date(h.lastTick).toDateString() !== today;
    }).length;

    if (incompletes > 0) {
      nudges.push({
        type: 'daily_reminder',
        title: 'Complete Your Mission',
        message: `${incompletes} habits left today — take a small step.`,
        priority: 'medium',
        audioPresetId: 'alarm_wake',
      });
    }

    nudges.push({
      type: 'momentum',
      title: 'Momentum Builds Character',
      message: 'Stack two tiny wins. Begin with the easier one.',
      priority: 'low',
    });

    return nudges;
  }

  async getMorningBrief(userId: string) {
    const habits = await prisma.habit.findMany({ where: { userId }});
    const now = new Date();
    const today = now.toDateString();

    const missions = habits.slice(0, 4).map((h: any) => {
      const tickedToday = h.lastTick && new Date(h.lastTick).toDateString() === today;
      const nextMilestone = this.getNextMilestone(h.streak);
      return {
        id: h.id,
        title: h.title,
        streak: h.streak,
        status: tickedToday ? 'completed' : 'pending',
        due: 'today',
        nextMilestone,
        daysToMilestone: nextMilestone ? nextMilestone - h.streak : null,
      };
    });

    const atRisk = habits.filter((h: any) => {
      if (!h.lastTick) return false;
      return this.daysBetween(now, new Date(h.lastTick)) > 1 && h.streak >= 7;
    });
    const riskBanners = atRisk.map((h: any) => ({
      type: 'streak_save',
      habitId: h.id,
      message: `${h.title} streak at risk — don't break the chain.`,
      urgency: 'high' as const,
    }));

    const nudges = this.buildNudges(habits, riskBanners.length > 0);

    return {
      missions,
      riskBanners,
      nudges,
      weeklyTarget: { current: Math.min(missions.filter((m: any) => m.status==='completed').length * 1.5, 6.0), goal: 6.0 },
      sentiment: { energy: 'primed', focus: 'fresh', suggestion: 'Start with the smallest win.' },
    };
  }

  async getEveningBrief(userId: string) {
    const habits = await prisma.habit.findMany({ where: { userId }});
    const now = new Date();
    const today = now.toDateString();

    const done = habits.filter((h: any) => h.lastTick && new Date(h.lastTick).toDateString() === today).length;
    const total = habits.length;
    const completion = total > 0 ? Math.round((done / total) * 100) : 0;

    // simple reflection prompts
    const prompts = [
      'What was the smallest choice today that moved you forward?',
      'What should you do again tomorrow that worked today?',
      'What obstacle showed up? How will you handle it differently?',
    ];

    return {
      completed: done,
      total,
      completion,
      reflections: prompts,
      suggestion: completion >= 60
        ? 'Strong showing. Set one non-negotiable for tomorrow.'
        : 'No shame. Note the friction and plan one tiny step for morning.',
    };
  }

  // Optional: send a push with audio (preset) for morning brief
  async pushMorningBrief(userId: string, fcmToken?: string) {
    const brief = await this.getMorningBrief(userId);
    const mainNudge = brief.nudges.find(n => n.priority === 'high') || brief.nudges[0];

    // Try to include a preset alarm sound
    let audioUrl: string | null = null;
    if (mainNudge?.audioPresetId) {
      const presetKey = `presets/${mainNudge.audioPresetId}.mp3`;
      const endpoint = (process.env.S3_ENDPOINT || '').replace(/\/+$/,'');
      const bucket = process.env.S3_BUCKET || 'voice';
      audioUrl = endpoint ? `${endpoint}/${bucket}/${presetKey}` : null;
    }

    // For now, just log the push (you can integrate with your notification queue)
    console.log('📣 MORNING BRIEF PUSH ->', {
      userId,
      fcmToken,
      title: mainNudge?.title || 'Morning Brief',
      body: mainNudge?.message || 'Start with the smallest win.',
      data: { kind: 'morning_brief' },
      audioUrl,
    });

    return { ok: true };
  }
}

export default BriefService;
