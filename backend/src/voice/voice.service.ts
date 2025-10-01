import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';
import axios from 'axios';

// Optional S3/MinIO upload (works with AWS or MinIO-compatible)
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const prisma = new PrismaClient();

type GetAudioInput = {
  userId: string;
  mentor?: 'marcus'|'confucius'|'lincoln'|'buddha'|'sergeant'|string;
  tone?: 'strict'|'balanced'|'light'|string;
  presetId?: string; // if provided, try preset -> cached URL
  text?: string;     // if provided, can synthesize (PRO or allowed)
};

export class VoiceService {
  private readonly elevenKey = process.env.ELEVENLABS_API_KEY || '';
  private readonly s3 = new S3Client({
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
  private readonly bucket = process.env.S3_BUCKET || 'voice';
  private readonly ttsTimeout = parseInt(process.env.ELEVENLABS_TTS_TIMEOUT_MS || '8000', 10);

  // map mentor+tone -> ElevenLabs voice id (env), else fallback to one default
  private pickVoiceId(mentor?: string, tone?: string): string | null {
    // Prefer tone-specific if provided
    if (tone === 'strict' && process.env.ELEVENLABS_VOICE_STRICT) return process.env.ELEVENLABS_VOICE_STRICT;
    if (tone === 'light'  && process.env.ELEVENLABS_VOICE_LIGHT)  return process.env.ELEVENLABS_VOICE_LIGHT;
    if (process.env.ELEVENLABS_VOICE_BALANCED) return process.env.ELEVENLABS_VOICE_BALANCED;
    return null;
  }

  private cacheKeyFromText(text: string, voiceId: string) {
    return crypto.createHash('sha256').update(`${voiceId}::${text}`).digest('hex');
  }

  private urlForS3Key(key: string): string {
    const endpoint = (process.env.S3_ENDPOINT || '').replace(/\/+$/,'');
    if (!endpoint) return `https://example.invalid/${this.bucket}/${key}`;
    // public URL (MinIO gateway or S3 public) — adjust to your setup
    return `${endpoint}/${this.bucket}/${key}`;
  }

  private async uploadToS3(pathKey: string, buffer: Buffer, contentType = 'audio/mpeg'): Promise<string> {
    await this.s3.send(new PutObjectCommand({
      Bucket: this.bucket,
      Key: pathKey,
      Body: buffer,
      ContentType: contentType,
      ACL: 'public-read',
    }));
    return this.urlForS3Key(pathKey);
  }

  private async synthesizeWithElevenLabs(text: string, voiceId: string): Promise<Buffer> {
    // ElevenLabs v1 text-to-speech
    // https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
    const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;
    const resp = await axios.post(url,
      {
        text,
        model_id: 'eleven_multilingual_v2',
        voice_settings: { stability: 0.55, similarity_boost: 0.6 },
      },
      {
        responseType: 'arraybuffer',
        timeout: this.ttsTimeout,
        headers: {
          'xi-api-key': this.elevenKey,
          'accept': 'audio/mpeg',
          'content-type': 'application/json',
        },
      }
    );
    return Buffer.from(resp.data);
  }

  private mentorLine(mentor?: string, tone?: string): string {
    // safe, short default line if text missing and preset not found
    const t = (tone || 'balanced').toLowerCase();
    if (t === 'strict')   return 'Move. Close distractions. One clean rep, now.';
    if (t === 'light')    return 'Gentle nudge. Begin with one mindful step.';
    // mentor flavor
    const m = (mentor || 'marcus').toLowerCase();
    if (m === 'marcus')   return 'What stands in the way becomes the way. Start your rep.';
    if (m === 'confucius')return 'The man who moves a mountain begins with small stones.';
    if (m === 'lincoln')  return 'Discipline today shapes the freedom of your tomorrow.';
    if (m === 'buddha')   return 'With each breath, return to the path. Begin.';
    if (m === 'sergeant') return 'No excuses. One rep. Now.';
    return 'Reset posture. One small rep, then a clean block.';
  }

  public async getAudioUrl(input: GetAudioInput): Promise<{ url: string | null }> {
    // 1) If presetId provided, just build a preset path (or you can map os presets)
    if (input.presetId) {
      const presetKey = `presets/${input.presetId}.mp3`;
      // If you actually host presets in S3, return that public URL.
      // Otherwise, return a CDN you control or a static server path.
      return { url: this.urlForS3Key(presetKey) };
    }

    // 2) If no TTS key configured, bail gracefully with null
    const voiceId = this.pickVoiceId(input.mentor, input.tone);
    if (!this.elevenKey || !voiceId) {
      return { url: null };
    }

    // 3) Text to speak — fallback to mentor line if not provided
    const text = (input.text && input.text.trim().length > 0)
      ? input.text.trim()
      : this.mentorLine(input.mentor, input.tone);

    // 4) Cache: check VoiceCache by content hash
    const cacheKey = this.cacheKeyFromText(text, voiceId);
    const existing = await prisma.voiceCache.findUnique({ where: { id: cacheKey }});
    if (existing?.url) {
      return { url: existing.url };
    }

    // 5) Synthesize + upload
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
    } catch {
      // On failure, don't crash alarms — return null
      return { url: null };
    }
  }
}

export default VoiceService;
