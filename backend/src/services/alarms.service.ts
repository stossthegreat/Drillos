// src/services/alarms.service.ts
import { prisma } from '../utils/db';
import { redis } from '../utils/redis';

/**
 * Very small RRULE parser with sane defaults.
 * Supports:
 *   - FREQ=DAILY
 *   - FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU
 *   - BYHOUR=H;BYMINUTE=M
 *   - FREQ=ONCE;DTSTART=ISO
 *
 * Returns the next Date after `from`, or null when not computable.
 */
function computeNextRun(rrule: string, from = new Date()): Date | null {
  const parts = Object.fromEntries(
    rrule
      .split(';')
      .map((kv) => kv.trim())
      .filter(Boolean)
      .map((kv) => {
        const [k, v] = kv.split('=');
        return [k.toUpperCase(), (v || '').toUpperCase()];
      }),
  );

  const FREQ = parts['FREQ'] || 'DAILY';
  const BYHOUR = parts['BYHOUR'] ? parseInt(parts['BYHOUR'], 10) : 9;
  const BYMINUTE = parts['BYMINUTE'] ? parseInt(parts['BYMINUTE'], 10) : 0;
  const BYDAY = parts['BYDAY'] ? parts['BYDAY'].split(',') : null; // e.g. ['MO','TU']
  const DTSTART = parts['DTSTART']; // ISO for FREQ=ONCE

  const base = new Date(from);
  base.setSeconds(0, 0);

  const setTime = (d: Date) => {
    const x = new Date(d);
    x.setHours(BYHOUR, BYMINUTE, 0, 0);
    return x;
  };

  // Map 0..6 => SU..SA (JS getDay: 0=Sun)
  const dowCode = (d: number) => ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'][d];

  if (FREQ === 'ONCE') {
    if (!DTSTART) return null;
    const t = new Date(DTSTART);
    return t > from ? t : null;
  }

  if (FREQ === 'DAILY') {
    // today at H:M, else tomorrow
    const candidate = setTime(from);
    if (candidate > from) return candidate;
    const tomorrow = new Date(from);
    tomorrow.setDate(tomorrow.getDate() + 1);
    return setTime(tomorrow);
  }

  if (FREQ === 'WEEKLY') {
    const allowed = new Set(BYDAY || ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']);
    for (let i = 0; i < 8; i++) {
      const d = new Date(from);
      d.setDate(d.getDate() + i);
      const code = dowCode(d.getDay());
      if (allowed.has(code)) {
        const candidate = setTime(d);
        if (candidate > from) return candidate;
      }
    }
    // If nothing in the next 7 days (!) default to next week same time
    const nextWeek = new Date(from);
    nextWeek.setDate(nextWeek.getDate() + 7);
    return setTime(nextWeek);
  }

  // Fallback: treat as DAILY
  const fallback = setTime(from);
  if (fallback > from) return fallback;
  const next = new Date(from);
  next.setDate(next.getDate() + 1);
  return setTime(next);
}

export class AlarmsService {
  /**
   * List alarms for user.
   */
  async list(userId: string) {
    return prisma.alarm.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Create alarm. rrule required.
   * Example rrule:
   *   - FREQ=DAILY;BYHOUR=7;BYMINUTE=0
   *   - FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=6;BYMINUTE=30
   *   - FREQ=ONCE;DTSTART=2025-10-01T08:00:00.000Z
   */
  async create(userId: string, data: { label: string; rrule: string; tone?: 'strict' | 'balanced' | 'light' }) {
    if (!data?.label || !data?.rrule) throw new Error('label and rrule are required');

    const nextRun = computeNextRun(data.rrule);
    const alarm = await prisma.alarm.create({
      data: {
        userId,
        label: data.label,
        rrule: data.rrule,
        tone: (data.tone as any) || 'balanced',
        enabled: true,
        nextRun: nextRun ?? null,
      },
    });

    await prisma.event.create({
      data: {
        userId,
        type: 'alarm_created',
        payload: { alarmId: alarm.id, label: alarm.label, rrule: alarm.rrule },
      },
    });

    return alarm;
  }

  /**
   * Update alarm. Recomputes nextRun if rrule or enabled changes.
   */
  async update(id: string, userId: string, changes: Partial<{ label: string; rrule: string; enabled: boolean; tone: 'strict' | 'balanced' | 'light' }>) {
    const existing = await prisma.alarm.findFirst({ where: { id, userId } });
    if (!existing) throw new Error('Alarm not found');

    let nextRun = existing.nextRun;
    if (typeof changes.enabled === 'boolean') {
      nextRun = changes.enabled ? computeNextRun(changes.rrule ?? existing.rrule) : null;
    }
    if (typeof changes.rrule === 'string') {
      nextRun = computeNextRun(changes.rrule);
    }

    const updated = await prisma.alarm.update({
      where: { id },
      data: {
        label: typeof changes.label === 'string' ? changes.label : existing.label,
        rrule: typeof changes.rrule === 'string' ? changes.rrule : existing.rrule,
        tone: (changes.tone as any) ?? existing.tone,
        enabled: typeof changes.enabled === 'boolean' ? changes.enabled : existing.enabled,
        nextRun,
      },
    });

    await prisma.event.create({
      data: {
        userId,
        type: 'alarm_updated',
        payload: { alarmId: id, changes },
      },
    });

    return updated;
  }

  /**
   * Delete alarm.
   */
  async delete(id: string, userId: string) {
    const existing = await prisma.alarm.findFirst({ where: { id, userId } });
    if (!existing) throw new Error('Alarm not found');

    await prisma.alarm.delete({ where: { id } });

    await prisma.event.create({
      data: {
        userId,
        type: 'alarm_deleted',
        payload: { alarmId: id, label: existing.label },
      },
    });

    return { ok: true };
  }

  /**
   * Mark an alarm “fired” (e.g., webhook or manual trigger), then schedule next.
   * Debounces by Redis to avoid double-fires within 60s.
   */
  async markFired(id: string, userId: string) {
    const alarm = await prisma.alarm.findFirst({ where: { id, userId } });
    if (!alarm) throw new Error('Alarm not found');
    if (!alarm.enabled) return { ok: false, message: 'Alarm disabled' };

    // debounce 60s
    const dedupeKey = `alarm:fired:${id}`;
    const seen = await redis.get(dedupeKey);
    if (seen) return { ok: true, deduped: true };

    await redis.set(dedupeKey, '1', 'EX', 60);

    await prisma.event.create({
      data: {
        userId,
        type: 'alarm_fired',
        payload: { alarmId: id, label: alarm.label, tone: alarm.tone, rrule: alarm.rrule },
      },
    });

    // compute next
    const nextRun = computeNextRun(alarm.rrule, new Date());
    await prisma.alarm.update({
      where: { id },
      data: { nextRun },
    });

    return { ok: true, nextRun };
  }
}

export const alarmsService = new AlarmsService();
