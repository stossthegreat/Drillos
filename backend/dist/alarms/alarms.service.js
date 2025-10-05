import { PrismaClient } from '@prisma/client';
import { VoiceService as VoiceServiceImpl } from '../voice/voice.service';
import { NotificationsQueue } from '../notifications/notifications.queue';
const noopNotifications = {
    enqueuePush: async () => Promise.resolve(),
};
const noopVoice = {
    getAudioUrl: async () => ({ url: null }),
};
export class AlarmsService {
    prisma;
    notifications;
    voice;
    constructor(prisma, notifications, voice) {
        this.prisma = prisma ?? new PrismaClient();
        this.notifications = notifications ?? new NotificationsQueue();
        this.voice = voice ?? new VoiceServiceImpl();
    }
    async list(userId) {
        return this.prisma.alarm.findMany({
            where: { userId },
            orderBy: [{ enabled: 'desc' }, { nextRun: 'asc' }],
        });
    }
    async create(userId, dto) {
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
            },
        });
        await this.logEvent(userId, 'alarm_created', { alarmId: alarm.id, dto });
        return alarm;
    }
    async update(userId, id, dto) {
        const alarm = await this.getOwned(userId, id);
        const tone = dto.tone ? this.normalizeTone(dto.tone) : alarm.tone;
        const rrule = dto.rrule ?? alarm.rrule;
        const nextRun = dto.rrule || (dto.enabled === true && !alarm.nextRun)
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
    async fire(userId, id) {
        const alarm = await this.getOwned(userId, id);
        if (!alarm.enabled) {
            throw new Error('Alarm is disabled');
        }
        const title = alarm.label || 'Reminder';
        const body = this.buildMentorLine(alarm.tone);
        const { url: audioUrl } = await this.voice.getAudioUrl({
            userId,
            mentor: this.guessMentorFromTone(alarm.tone),
            tone: alarm.tone,
        });
        await this.notifications.enqueuePush({
            userId,
            title,
            body,
            data: {
                alarmId: alarm.id,
                ...(audioUrl ? { audioUrl } : {}),
            },
        });
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
    async dismiss(userId, id, snoozeMinutes) {
        const alarm = await this.getOwned(userId, id);
        let nextRun = null;
        if (snoozeMinutes && snoozeMinutes > 0) {
            nextRun = new Date(Date.now() + snoozeMinutes * 60 * 1000);
        }
        else {
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
    async remove(userId, id) {
        const alarm = await this.getOwned(userId, id);
        await this.prisma.alarm.delete({ where: { id: alarm.id } });
        await this.logEvent(userId, 'alarm_deleted', { alarmId: id });
        return { ok: true, deleted: id };
    }
    async getOwned(userId, id) {
        const alarm = await this.prisma.alarm.findUnique({ where: { id } });
        if (!alarm)
            throw new Error('Alarm not found');
        if (alarm.userId !== userId)
            throw new Error('Not your alarm');
        return alarm;
    }
    normalizeTone(t) {
        if (!t)
            return 'balanced';
        const v = String(t).toLowerCase();
        if (v === 'strict')
            return 'strict';
        if (v === 'light')
            return 'light';
        return 'balanced';
    }
    guessMentorFromTone(tone) {
        if (tone === 'strict')
            return 'sergeant';
        if (tone === 'light')
            return 'buddha';
        return 'marcus';
    }
    buildMentorLine(tone) {
        switch (tone) {
            case 'strict':
                return 'Move. Close distractions. One clean rep right now.';
            case 'light':
                return 'Gentle nudge: one mindful step, then begin.';
            default:
                return 'Reset posture. One small rep, then a clean block.';
        }
    }
    calculateNextRun(rrule, now, _userId) {
        try {
            const parts = rrule
                .split(';')
                .map((kv) => kv.trim())
                .filter(Boolean)
                .reduce((acc, kv) => {
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
                const candidate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), byHour, byMinute, 0, 0);
                if (candidate > now)
                    return candidate;
                const t = new Date(candidate.getTime() + 24 * 60 * 60 * 1000);
                return t;
            }
            if (freq === 'WEEKLY') {
                const days = (parts['BYDAY'] || 'MO,TU,WE,TH,FR,SA,SU')
                    .split(',')
                    .map((s) => s.trim())
                    .filter(Boolean);
                const map = {
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
                for (let add = 0; add <= 7; add++) {
                    const test = new Date(now.getFullYear(), now.getMonth(), now.getDate() + add, byHour, byMinute, 0, 0);
                    if (!allowed.includes(test.getDay()))
                        continue;
                    if (test > now)
                        return test;
                }
                return new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
            }
            return new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, byHour, byMinute, 0, 0);
        }
        catch {
            return new Date(now.getTime() + 24 * 60 * 60 * 1000);
        }
    }
    async logEvent(userId, type, payload) {
        try {
            await this.prisma.event.create({
                data: {
                    userId,
                    type,
                    payload,
                },
            });
        }
        catch {
        }
    }
}
export default AlarmsService;
//# sourceMappingURL=alarms.service.js.map