"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.alarmsService = exports.AlarmsService = void 0;
// src/services/alarms.service.ts
const db_1 = require("../utils/db");
const redis_1 = require("../utils/redis");
const voice_service_1 = require("./voice.service");
const notifications_service_1 = require("./notifications.service");
/**
 * RRULE parser for daily/weekly/once.
 */
function computeNextRun(rrule, from = new Date()) {
    const parts = Object.fromEntries(rrule
        .split(';')
        .map((kv) => kv.trim())
        .filter(Boolean)
        .map((kv) => {
        const [k, v] = kv.split('=');
        return [k.toUpperCase(), (v || '').toUpperCase()];
    }));
    const FREQ = parts['FREQ'] || 'DAILY';
    const BYHOUR = parts['BYHOUR'] ? parseInt(parts['BYHOUR'], 10) : 9;
    const BYMINUTE = parts['BYMINUTE'] ? parseInt(parts['BYMINUTE'], 10) : 0;
    const BYDAY = parts['BYDAY'] ? parts['BYDAY'].split(',') : null;
    const DTSTART = parts['DTSTART'];
    const base = new Date(from);
    base.setSeconds(0, 0);
    const setTime = (d) => {
        const x = new Date(d);
        x.setHours(BYHOUR, BYMINUTE, 0, 0);
        return x;
    };
    const dowCode = (d) => ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'][d];
    if (FREQ === 'ONCE') {
        if (!DTSTART)
            return null;
        const t = new Date(DTSTART);
        return t > from ? t : null;
    }
    if (FREQ === 'DAILY') {
        const candidate = setTime(from);
        if (candidate > from)
            return candidate;
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
                if (candidate > from)
                    return candidate;
            }
        }
        const nextWeek = new Date(from);
        nextWeek.setDate(nextWeek.getDate() + 7);
        return setTime(nextWeek);
    }
    const fallback = setTime(from);
    if (fallback > from)
        return fallback;
    const next = new Date(from);
    next.setDate(next.getDate() + 1);
    return setTime(next);
}
class AlarmsService {
    async list(userId) {
        return db_1.prisma.alarm.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
    }
    async create(userId, data) {
        if (!data?.label || !data?.rrule)
            throw new Error('label and rrule required');
        const nextRun = computeNextRun(data.rrule);
        const alarm = await db_1.prisma.alarm.create({
            data: {
                userId,
                label: data.label,
                rrule: data.rrule,
                tone: data.tone || 'balanced',
                enabled: true,
                nextRun,
            },
        });
        await db_1.prisma.event.create({
            data: { userId, type: 'alarm_created', payload: { alarmId: alarm.id, label: alarm.label } },
        });
        return alarm;
    }
    async update(id, userId, changes) {
        const existing = await db_1.prisma.alarm.findFirst({ where: { id, userId } });
        if (!existing)
            throw new Error('Alarm not found');
        let nextRun = existing.nextRun;
        if (typeof changes.enabled === 'boolean') {
            nextRun = changes.enabled ? computeNextRun(changes.rrule ?? existing.rrule) : null;
        }
        if (changes.rrule)
            nextRun = computeNextRun(changes.rrule);
        const updated = await db_1.prisma.alarm.update({
            where: { id },
            data: {
                label: changes.label ?? existing.label,
                rrule: changes.rrule ?? existing.rrule,
                tone: changes.tone ?? existing.tone,
                enabled: changes.enabled ?? existing.enabled,
                nextRun,
            },
        });
        await db_1.prisma.event.create({
            data: { userId, type: 'alarm_updated', payload: { alarmId: id, changes } },
        });
        return updated;
    }
    async delete(id, userId) {
        const existing = await db_1.prisma.alarm.findFirst({ where: { id, userId } });
        if (!existing)
            throw new Error('Alarm not found');
        await db_1.prisma.alarm.delete({ where: { id } });
        await db_1.prisma.event.create({
            data: { userId, type: 'alarm_deleted', payload: { alarmId: id, label: existing.label } },
        });
        return { ok: true };
    }
    async markFired(id, userId) {
        const alarm = await db_1.prisma.alarm.findFirst({ where: { id, userId } });
        if (!alarm)
            throw new Error('Alarm not found');
        if (!alarm.enabled)
            return { ok: false, message: 'Alarm disabled' };
        // prevent duplicate fires
        const dedupeKey = `alarm:fired:${id}`;
        if (await redis_1.redis.get(dedupeKey))
            return { ok: true, deduped: true };
        await redis_1.redis.set(dedupeKey, '1', 'EX', 60);
        // log firing
        await db_1.prisma.event.create({
            data: { userId, type: 'alarm_fired', payload: { alarmId: id, label: alarm.label, tone: alarm.tone } },
        });
        // mentor speech (ElevenLabs voice)
        const text = `${alarm.label}. Time to move. ${alarm.tone === 'strict' ? 'No excuses — do it now.' :
            alarm.tone === 'balanced' ? 'Stay steady, progress comes daily.' :
                'Take this lightly, but stay consistent.'}`;
        const user = await db_1.prisma.user.findUnique({ where: { id: userId } });
        const voiceResult = await voice_service_1.voiceService.speak(userId, text, user?.mentorId ?? 'marcus');
        const voiceUrl = voiceResult.url;
        // push notification (Firebase)
        await notifications_service_1.notificationsService.send(userId, 'Alarm', text);
        // reschedule
        const nextRun = computeNextRun(alarm.rrule, new Date());
        await db_1.prisma.alarm.update({ where: { id }, data: { nextRun } });
        return { ok: true, nextRun, voiceUrl };
    }
}
exports.AlarmsService = AlarmsService;
exports.alarmsService = new AlarmsService();
