import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';
import axios from 'axios';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
const prisma = new PrismaClient();
export class VoiceService {
    elevenKey = process.env.ELEVENLABS_API_KEY || '';
    s3 = new S3Client({
        region: 'auto',
        ...(process.env.S3_ENDPOINT && { endpoint: process.env.S3_ENDPOINT }),
        forcePathStyle: true,
        ...(process.env.S3_ACCESS_KEY && process.env.S3_SECRET_KEY && {
            credentials: {
                accessKeyId: process.env.S3_ACCESS_KEY,
                secretAccessKey: process.env.S3_SECRET_KEY,
            }
        }),
    });
    bucket = process.env.S3_BUCKET || 'voice';
    ttsTimeout = parseInt(process.env.ELEVENLABS_TTS_TIMEOUT_MS || '8000', 10);
    pickVoiceId(mentor, tone) {
        if (tone === 'strict' && process.env.ELEVENLABS_VOICE_STRICT)
            return process.env.ELEVENLABS_VOICE_STRICT;
        if (tone === 'light' && process.env.ELEVENLABS_VOICE_LIGHT)
            return process.env.ELEVENLABS_VOICE_LIGHT;
        if (process.env.ELEVENLABS_VOICE_BALANCED)
            return process.env.ELEVENLABS_VOICE_BALANCED;
        return null;
    }
    cacheKeyFromText(text, voiceId) {
        return crypto.createHash('sha256').update(`${voiceId}::${text}`).digest('hex');
    }
    urlForS3Key(key) {
        const endpoint = (process.env.S3_ENDPOINT || '').replace(/\/+$/, '');
        if (!endpoint)
            return `https://example.invalid/${this.bucket}/${key}`;
        return `${endpoint}/${this.bucket}/${key}`;
    }
    async uploadToS3(pathKey, buffer, contentType = 'audio/mpeg') {
        await this.s3.send(new PutObjectCommand({
            Bucket: this.bucket,
            Key: pathKey,
            Body: buffer,
            ContentType: contentType,
            ACL: 'public-read',
        }));
        return this.urlForS3Key(pathKey);
    }
    async synthesizeWithElevenLabs(text, voiceId) {
        const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;
        const resp = await axios.post(url, {
            text,
            model_id: 'eleven_multilingual_v2',
            voice_settings: { stability: 0.55, similarity_boost: 0.6 },
        }, {
            responseType: 'arraybuffer',
            timeout: this.ttsTimeout,
            headers: {
                'xi-api-key': this.elevenKey,
                'accept': 'audio/mpeg',
                'content-type': 'application/json',
            },
        });
        return Buffer.from(resp.data);
    }
    mentorLine(mentor, tone) {
        const t = (tone || 'balanced').toLowerCase();
        if (t === 'strict')
            return 'Move. Close distractions. One clean rep, now.';
        if (t === 'light')
            return 'Gentle nudge. Begin with one mindful step.';
        const m = (mentor || 'marcus').toLowerCase();
        if (m === 'marcus')
            return 'What stands in the way becomes the way. Start your rep.';
        if (m === 'confucius')
            return 'The man who moves a mountain begins with small stones.';
        if (m === 'lincoln')
            return 'Discipline today shapes the freedom of your tomorrow.';
        if (m === 'buddha')
            return 'With each breath, return to the path. Begin.';
        if (m === 'sergeant')
            return 'No excuses. One rep. Now.';
        return 'Reset posture. One small rep, then a clean block.';
    }
    async getAudioUrl(input) {
        if (input.presetId) {
            const presetKey = `presets/${input.presetId}.mp3`;
            return { url: this.urlForS3Key(presetKey) };
        }
        const voiceId = this.pickVoiceId(input.mentor, input.tone);
        if (!this.elevenKey || !voiceId) {
            return { url: null };
        }
        const text = (input.text && input.text.trim().length > 0)
            ? input.text.trim()
            : this.mentorLine(input.mentor, input.tone);
        const cacheKey = this.cacheKeyFromText(text, voiceId);
        const existing = await prisma.voiceCache.findUnique({ where: { id: cacheKey } });
        if (existing?.url) {
            return { url: existing.url };
        }
        try {
            const audio = await this.synthesizeWithElevenLabs(text, voiceId);
            const pathKey = `tts/${voiceId}/${cacheKey}.mp3`;
            const publicUrl = await this.uploadToS3(pathKey, audio, 'audio/mpeg');
            await prisma.voiceCache.upsert({
                where: { id: cacheKey },
                update: { text, voice: voiceId, url: publicUrl },
                create: { id: cacheKey, text, voice: voiceId, url: publicUrl },
            });
            return { url: publicUrl };
        }
        catch {
            return { url: null };
        }
    }
}
export default VoiceService;
//# sourceMappingURL=voice.service.js.map