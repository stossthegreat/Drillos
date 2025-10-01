import { PrismaClient } from '@prisma/client';
import { VoiceService as VoiceServiceImpl } from '../voice/voice.service';
import { NotificationsQueue } from '../notifications/notifications.queue';

// Optional queues/services – they no-op if missing
interface NotificationQueue {
  enqueuePush: (payload: {
    userId: string;
    title: string;
    body: string;
    data?: Record<string, string>;
    audioUrl?: string | null;
  }) => Promise<void>;
}

interface VoiceService {
  // If presetId provided, try return cached url; else synthesize from text+mentor+tone (and cache)
  getAudioUrl(input: {
    userId: string;
    mentor?: string;
    tone?: 'strict' | 'balanced' | 'light';
    presetId?: string;
    text?: string;
  }): Promise<{ url: string | null }>;
}

// You can wire real implementations later via module providers
const noopNotifications: NotificationQueue = {
  enqueuePush: async () => Promise.resolve(),
};

const noopVoice: VoiceService = {
  getAudioUrl: async () => ({ url: null }),
};

type CreateAlarmDTO = {
  label: string;
  rrule: string;
  tone?: 'strict' | 'balanced' | 'light';
  enabled?: boolean;
  metadata?: Record<string, any>;
};

type UpdateAlarmDTO = Partial<CreateAlarmDTO>;

export class AlarmsService {
  private prisma: PrismaClient;
  private notifications: NotificationQueue;
  private voice: VoiceService;

  constructor(
    prisma?: PrismaClient,
    notifications?: NotificationQueue,
    voice?: VoiceService,
  ) {
    this.prisma = prisma ?? new PrismaClient();
    this.notifications = notifications ?? new NotificationsQueue();
    this.voice = voice ?? new VoiceServiceImpl();
  }

  // ---------------------------
  // Public API
  // ---------------------------

  async list(userId: string) {
    return this.prisma.alarm.findMany({
      where: { userId },
      orderBy: [{ enabled: 'desc' }, { nextRun: 'asc' }],
    });
  }

  async create(userId: string, dto: CreateAlarmDTO) {
    const tone = this.normalizeTone(dto.tone);
    const nextRun = this.calculateNextRun(dto.rrule, new Date(), userId);

    const alarm = await this.prisma.alarm.create({
      data: {
        userId,
        label: dto.label,
        rrule: dto.rrule,
        tone,
        enabled: dto.enabled ?? true,
        nextRun,
        // Prisma model has no "metadata" column by default. If you want metadata, add a Json field.
        // For now we put it into Event log so it's still preserved and searchable.
      },
    });

    // Log event (optional)
    await this.logEvent(userId, 'alarm_created', { alarmId: alarm.id, dto });

    return alarm;
  }

  async update(userId: string, id: string, dto: UpdateAlarmDTO) {
    const alarm = await this.getOwned(userId, id);

    const tone = dto.tone ? this.normalizeTone(dto.tone) : alarm.tone;
    const rrule = dto.rrule ?? alarm.rrule;

    const nextRun =
      dto.rrule || (dto.enabled === true && !alarm.nextRun)
        ? this.calculateNextRun(rrule, new Date(), userId)
        : alarm.nextRun;

    const updated = await this.prisma.alarm.update({
      where: { id },
      data: {
        label: dto.label ?? alarm.label,
        rrule,
        tone,
        enabled: dto.enabled ?? alarm.enabled,
        nextRun,
      },
    });

    await this.logEvent(userId, 'alarm_updated', { alarmId: id, dto });

    return updated;
  }

  async fire(userId: string, id: string) {
    const alarm = await this.getOwned(userId, id);
    if (!alarm.enabled) {
      throw new Error('Alarm is disabled');
    }

    // Build push payload
    const title = alarm.label || 'Reminder';
    const body = this.buildMentorLine(alarm.tone);

    // Voice: try to fetch a cached preset or synthesize (if wired + allowed)
    const { url: audioUrl } = await this.voice.getAudioUrl({
      userId,
      mentor: this.guessMentorFromTone(alarm.tone),
      tone: alarm.tone,
      // You can pass presetId/text if you stored them somewhere
    });

    // Enqueue push (no-op if queue not wired)
    await this.notifications.enqueuePush({
      userId,
      title,
      body,
      data: {
        alarmId: alarm.id,
        ...(audioUrl ? { audioUrl } : {}),
      },
    });

    // Advance nextRun
    const nextRun = this.calculateNextRun(alarm.rrule, new Date(), userId);
    const updated = await this.prisma.alarm.update({
      where: { id: alarm.id },
      data: { nextRun },
    });

    await this.logEvent(userId, 'alarm_fired', {
      alarmId: alarm.id,
      sentBody: body,
      audioUrl: audioUrl || null,
      nextRun,
    });

    return { ok: true, firedAt: new Date().toISOString(), nextRun };
  }

  async dismiss(userId: string, id: string, snoozeMinutes: number) {
    const alarm = await this.getOwned(userId, id);

    let nextRun: Date | null = null;

    if (snoozeMinutes && snoozeMinutes > 0) {
      nextRun = new Date(Date.now() + snoozeMinutes * 60 * 1000);
    } else {
      // normal advance
      nextRun = this.calculateNextRun(alarm.rrule, new Date(), userId);
    }

    const updated = await this.prisma.alarm.update({
      where: { id },
      data: { nextRun },
    });

    await this.logEvent(userId, 'alarm_dismissed', {
      alarmId: id,
      snoozed: !!snoozeMinutes,
      snoozeMinutes: snoozeMinutes || 0,
      nextRun,
    });

    return { ok: true, nextRun };
  }

  async remove(userId: string, id: string) {
    const alarm = await this.getOwned(userId, id);

    await this.prisma.alarm.delete({ where: { id: alarm.id } });

    await this.logEvent(userId, 'alarm_deleted', { alarmId: id });

    return { ok: true, deleted: id };
  }

  // ---------------------------
  // Helpers
  // ---------------------------

  private async getOwned(userId: string, id: string) {
    const alarm = await this.prisma.alarm.findUnique({ where: { id } });
    if (!alarm) throw new Error('Alarm not found');
    if (alarm.userId !== userId) throw new Error('Not your alarm');
    return alarm;
  }

  private normalizeTone(t?: any): 'strict' | 'balanced' | 'light' {
    if (!t) return 'balanced';
    const v = String(t).toLowerCase();
    if (v === 'strict') return 'strict';
    if (v === 'light') return 'light';
    return 'balanced';
  }

  private guessMentorFromTone(tone: 'strict' | 'balanced' | 'light'): string {
    // You can change mapping later; just a sane default
    if (tone === 'strict') return 'sergeant';
    if (tone === 'light') return 'buddha';
    return 'marcus';
  }

  private buildMentorLine(tone: 'strict' | 'balanced' | 'light'): string {
    switch (tone) {
      case 'strict':
        return 'Move. Close distractions. One clean rep right now.';
      case 'light':
        return 'Gentle nudge: one mindful step, then begin.';
      default:
        return 'Reset posture. One small rep, then a clean block.';
    }
  }

  /**
   * Tiny RRULE interpreter:
   * Supports:
   * - FREQ=DAILY;BYHOUR=7;BYMINUTE=0
   * - FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU;BYHOUR=6;BYMINUTE=30
   * Fallback: next day, same time, or +24h.
   */
  private calculateNextRun(rrule: string, now: Date, _userId: string): Date {
    try {
      const parts = rrule
        .split(';')
        .map((kv) => kv.trim())
        .filter(Boolean)
        .reduce<Record<string, string>>((acc, kv) => {
          const [k, v] = kv.split('=');
          if (k) {
            acc[k.toUpperCase()] = (v || '').toUpperCase();
          }
          return acc;
        }, {});

      const freq = parts['FREQ'] || 'DAILY';
      const byHour = parseInt(parts['BYHOUR'] || '8', 10);
      const byMinute = parseInt(parts['BYMINUTE'] || '0', 10);

      if (freq === 'DAILY') {
        const candidate = new Date(
          now.getFullYear(),
          now.getMonth(),
          now.getDate(),
          byHour,
          byMinute,
          0,
          0,
        );
        if (candidate > now) return candidate;
        // tomorrow
        const t = new Date(candidate.getTime() + 24 * 60 * 60 * 1000);
        return t;
      }

      if (freq === 'WEEKLY') {
        const days = (parts['BYDAY'] || 'MO,TU,WE,TH,FR,SA,SU')
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean);

        // Map Sun..Sat => 0..6
        const map: Record<string, number> = {
          SU: 0,
          MO: 1,
          TU: 2,
          WE: 3,
          TH: 4,
          FR: 5,
          SA: 6,
        };

        const allowed = days
          .map((d) => map[d])
          .filter((n) => n !== undefined)
          .sort((a, b) => a - b);

        // Start from today, find the next allowed weekday at target time
        for (let add = 0; add <= 7; add++) {
          const test = new Date(
            now.getFullYear(),
            now.getMonth(),
            now.getDate() + add,
            byHour,
            byMinute,
            0,
            0,
          );
          if (!allowed.includes(test.getDay())) continue;
          if (test > now) return test;
        }
        // Fallback +7 days
        return new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      }

      // Fallback: next day
      return new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate() + 1,
        byHour,
        byMinute,
        0,
        0,
      );
    } catch {
      // absolute fallback: +24h
      return new Date(now.getTime() + 24 * 60 * 60 * 1000);
    }
  }

  private async logEvent(
    userId: string,
    type: string,
    payload: Record<string, any>,
  ) {
    try {
      await this.prisma.event.create({
        data: {
          userId,
          type,
          payload,
        },
      });
    } catch {
      // swallow logging errors in production
    }
  }
}

export default AlarmsService;
