// src/services/voice.service.ts
import { prisma } from '../utils/db';
import { redis } from '../utils/redis';
import axios from 'axios';

const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY!;
if (!ELEVENLABS_API_KEY) throw new Error('Missing ELEVENLABS_API_KEY');

const VOICE_IDS: Record<string, string> = {
  marcus: process.env.ELEVENLABS_VOICE_MARCUS!,
  drill: process.env.ELEVENLABS_VOICE_DRILL!,
  confucius: process.env.ELEVENLABS_VOICE_CONFUCIUS!,
  lincoln: process.env.ELEVENLABS_VOICE_LINCOLN!,
  buddha: process.env.ELEVENLABS_VOICE_BUDDHA!,
};

export class VoiceService {
  /**
   * Text-to-speech with Redis caching + Prisma logging.
   */
  async speak(userId: string, mentorId: keyof typeof VOICE_IDS, text: string) {
    if (!VOICE_IDS[mentorId]) throw new Error(`No voice configured for ${mentorId}`);
    const cacheKey = `voice:${mentorId}:${Buffer.from(text).toString('base64')}`;

    // Check Redis cache
    const cachedUrl = await redis.get(cacheKey);
    if (cachedUrl) {
      return { url: cachedUrl, cached: true };
    }

    // Call ElevenLabs TTS
    const res = await axios.post(
      `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_IDS[mentorId]}`,
      { text, model_id: 'eleven_monolingual_v1' },
      {
        headers: {
          'xi-api-key': ELEVENLABS_API_KEY,
          'Content-Type': 'application/json',
        },
        responseType: 'arraybuffer',
      }
    );

    // Store audio to S3 or local (simplified: base64 data URI)
    const audioBase64 = `data:audio/mpeg;base64,${Buffer.from(res.data).toString('base64')}`;

    // Cache in Redis (1 day)
    await redis.set(cacheKey, audioBase64, 'EX', 86400);

    // Log in DB
    await prisma.voiceCache.create({
      data: {
        id: cacheKey,
        text,
        voice: mentorId,
        url: audioBase64,
      },
    });

    return { url: audioBase64, cached: false };
  }
}

export const voiceService = new VoiceService();
