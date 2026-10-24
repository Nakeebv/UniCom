import { env } from "@/lib/config-lite";

/**
 * Meta MMS-TTS via HuggingFace Inference — the only free provider with real
 * Yorùbá (yo) and Hausa (ha) speech synthesis (alongside 1,100+ languages).
 *
 * Endpoint: POST https://router.huggingface.co/hf-inference/models/facebook/mms-tts-{iso3}
 * Auth:     Bearer HF_API_TOKEN (free at huggingface.co/settings/tokens)
 * Body:     {"inputs": "<text>"} → binary audio (audio/flac)
 *
 * Env-gated: HF_API_TOKEN present → provider active. Never fakes success.
 */

export const mmsLanguages: Record<string, string> = {
  yo: "yor", // Yorùbá
  ha: "hau", // Hausa
  sw: "swh", // Swahili
  en: "eng",
  es: "spa",
  fr: "fra",
  pt: "por",
  ar: "ara",
};

export function mmsConfigured(): boolean {
  return Boolean(env("HF_API_TOKEN"));
}

export function mmsSupportedFor(languageCode: string): boolean {
  return Boolean(mmsConfigured() && mmsLanguages[languageCode]);
}

export class MmsError extends Error {
  provider: string;
  constructor(provider: string, message: string) {
    super(message);
    this.provider = provider;
  }
}

export async function synthesizeMms(
  text: string,
  languageCode: string,
): Promise<{ bytes: Uint8Array; mimeType: string; provider: string }> {
  const token = env("HF_API_TOKEN");
  if (!token) throw new MmsError("mms", "not configured");
  const iso3 = mmsLanguages[languageCode];
  if (!iso3) throw new MmsError("mms", `language ${languageCode} not supported`);

  const model = env("HF_TTS_MODEL") ?? `facebook/mms-tts-${iso3}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 60_000);
  try {
    const res = await fetch(
      `https://router.huggingface.co/hf-inference/models/${model}`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ inputs: text.slice(0, 1200) }),
        signal: controller.signal,
      },
    );
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new MmsError("mms", `http ${res.status} ${detail.slice(0, 140)}`);
    }
    const contentType = (res.headers.get("content-type") ?? "").split(";")[0];
    if (!contentType.startsWith("audio/")) {
      const body = await res.text().catch(() => "");
      throw new MmsError("mms", `unexpected response (${contentType}) ${body.slice(0, 140)}`);
    }
    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.byteLength < 512) {
      throw new MmsError("mms", "suspiciously small audio payload");
    }
    // MMS returns FLAC (RIFF container) on this pipeline.
    const mime = bytes[0] === 0x52 && bytes[1] === 0x49 ? "audio/wav" : contentType;
    return { bytes, mimeType: mime, provider: `hf:${model}` };
  } catch (err) {
    if (err instanceof MmsError) throw err;
    throw new MmsError("mms", err instanceof Error ? err.message : "request failed");
  } finally {
    clearTimeout(timer);
  }
}
