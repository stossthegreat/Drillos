// src/services/voice.service.ts
import axios from "axios";
import crypto from "crypto";
import { prisma } from "../utils/db";

// Optional S3 upload (recommended for serving audio); if you prefer CDN or local FS, adapt here.
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const ELEVEN_API_KEY = process.env.ELEVENLABS_API_KEY || "";
const ELEVEN_TTS_TIMEOUT_MS = Number(process.env.ELEVENLABS_TTS_TIMEOUT_MS || 10000);

// map mentor -> voiceId via env
const VOICES: Record<string, string | undefined> = {
  strict: process.env.ELEVENLABS_VOICE_STRICT,
  balanced: process.env.ELEVENLABS_VOICE_BALANCED,
  light: process.env.ELEVENLABS_VOICE_LIGHT,
  marcus: process.env.ELEVENLABS_VOICE_MARCUS,
  drill: process.env.ELEVENLABS_VOICE_DRILL,
  confucius: process.env.ELEVENLABS_VOICE_CONFUCIUS,
  lincoln: process.env.ELEVENLABS_VOICE_LINCOLN,
  buddha: process.env.ELEVENLABS_VOICE_BUDDHA,
};

const S3_ENDPOINT = process.env.S3_ENDPOINT || "";
const S3_BUCKET = process.env.S3_BUCKET || "";
const S3_ACCESS_KEY = process.env.S3_ACCESS_KEY || "";
const S3_SECRET_KEY = process.env.S3_SECRET_KEY || "";

const s3 =
  S3_BUCKET && S3_ACCESS_KEY && S3_SECRET_KEY
    ? new S3Client({
        region: "auto",
        endpoint: S3_ENDPOINT || undefined,
        forcePathStyle: !!S3_ENDPOINT,
        credentials: { accessKeyId: S3_ACCESS_KEY, secretAccessKey: S3_SECRET_KEY },
      })
    : null;

export class VoiceService {
  /**
   * Main: get TTS audio URL for a mentor/voice + text, with real caching.
   */
  async speak(userId: string, text: string, voiceKey: string) {
    if (!ELEVEN_API_KEY) throw new Error("ELEVENLABS_API_KEY missing");
    const voiceId = VOICES[voiceKey] || VOICES["balanced"];
    if (!voiceId) throw new Error(`Voice not configured for key "${voiceKey}"`);

    const cacheKey = this.hash(text + "|" + voiceId);
    const existing = await prisma.voiceCache.findUnique({ where: { id: cacheKey } });
    if (existing?.url) {
      // Log hit
      await prisma.event.create({
        data: { userId, type: "voice_cache_hit", payload: { id: cacheKey, voiceKey } },
      });
      return { url: existing.url, cached: true };
    }

    // Call ElevenLabs
    const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;
    const resp = await axios.post(
      url,
      {
        text,
        model_id: "eleven_monolingual_v1",
        voice_settings: { similarity_boost: 0.7, stability: 0.45, style: 0.0, use_speaker_boost: true },
      },
      {
        responseType: "arraybuffer",
        timeout: ELEVEN_TTS_TIMEOUT_MS,
        headers: {
          "xi-api-key": ELEVEN_API_KEY,
          "Content-Type": "application/json",
          "Accept": "audio/mpeg",
        },
      }
    );

    // Upload to S3-compatible storage (recommended)
    let publicUrl: string;
    if (s3 && S3_BUCKET) {
      const objectKey = `voice/${cacheKey}.mp3`;
      await s3.send(
        new PutObjectCommand({
          Bucket: S3_BUCKET,
          Key: objectKey,
          Body: Buffer.from(resp.data),
          ContentType: "audio/mpeg",
          ACL: "public-read",
        })
      );
      // Construct URL (for S3: https://{bucket}.s3.amazonaws.com/{key}; for MinIO: endpoint/bucket/key)
      publicUrl = S3_ENDPOINT
        ? `${S3_ENDPOINT.replace(/\/$/, "")}/${S3_BUCKET}/${objectKey}`
        : `https://${S3_BUCKET}.s3.amazonaws.com/${objectKey}`;
    } else {
      // Fallback: store data URI in DB (works but not ideal for production)
      const b64 = Buffer.from(resp.data).toString("base64");
      publicUrl = `data:audio/mpeg;base64,${b64}`;
    }

    // Save cache
    await prisma.voiceCache.create({
      data: { id: cacheKey, text, voice: voiceKey, url: publicUrl },
    });

    await prisma.event.create({
      data: { userId, type: "voice_generated", payload: { cacheKey, voiceKey, bytes: resp.data?.length || 0 } },
    });

    return { url: publicUrl, cached: false };
  }

  /**
   * Alias for speak() that returns just the URL string (backward compatibility)
   */
  async ttsToUrl(userId: string, text: string, voiceKey: string): Promise<string> {
    const result = await this.speak(userId, text, voiceKey);
    return result.url;
  }

  private hash(s: string) {
    return crypto.createHash("sha256").update(s).digest("hex").slice(0, 40);
  }
}

export const voiceService = new VoiceService();
