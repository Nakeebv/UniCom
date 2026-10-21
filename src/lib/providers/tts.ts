import { cfAi, features } from "@/lib/config";

/**
 * Text-to-speech via Cloudflare Workers AI (@cf/myshell-ai/melotts).
 *
 * Generates a real audio variant for a message's translated text so the
 * recipient can *hear* the translation ("Play in Spanish"). Coverage is
 * intentionally conservative — the model speaks a subset of languages, and
 * UniCom never pretends a variant exists when it can't be generated (the
 * UI falls back to the original audio with an honest label).
 *
 * Variants are content-cached upstream by (message, target, voice, speed).
 */

/** Language codes melotts can synthesize (639-1). Reviewed against the
 * Workers AI model schema at integration time; extend cautiously. */
const TTS_LANGUAGES = new Set([
  "en", "es", "fr", "de", "it", "pt", "zh", "ja", "ko",
]);

export function ttsSupportedFor(languageCode: string): boolean {
  if (features.tts === "off") return false;
  if (["auto", "cloudflare"].indexOf(features.tts) === -1) return false;
  return TTS_LANGUAGES.has(languageCode) && cfAi.ttsEnabled;
}

export class TtsError extends Error {
  provider: string;
  constructor(provider: string, message: string) {
    super(message);
    this.provider = provider;
  }
}

export async function synthesizeSpeech(
  text: string,
  languageCode: string,
): Promise<{ bytes: Uint8Array; mimeType: string; provider: string }> {
  if (!cfAi.ttsEnabled) throw new TtsError("melotts", "not configured");
  const model = cfAi.ttsModel;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 60_000);
  let res: Response;
  try {
    res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${cfAi.accountId}/ai/run/${model}`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${cfAi.apiToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ prompt: text.slice(0, 1200), lang: languageCode }),
        signal: controller.signal,
      },
    );
  } catch {
    throw new TtsError("melotts", "network timeout / unreachable");
  } finally {
    clearTimeout(timer);
  }

  if (!res.ok) {
    throw new TtsError("melotts", `http ${res.status}`);
  }
  const contentType = res.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    // Direct audio bytes (older gateway behavior).
    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.byteLength < 512) {
      throw new TtsError("melotts", "suspiciously small audio payload");
    }
    return { bytes, mimeType: "audio/wav", provider: `workers-ai:${model}` };
  }
  // Current API shape: { result: { audio: <base64 WAV/MP3> } }.
  const data = (await res.json().catch(() => null)) as
    | { result?: { audio?: string } }
    | null;
  const b64 = data?.result?.audio;
  if (!b64) throw new TtsError("melotts", "response missing result.audio");
  const bytes = new Uint8Array(Buffer.from(b64, "base64"));
  if (bytes.byteLength < 512) {
    throw new TtsError("melotts", "suspiciously small audio payload");
  }
  // Payload is a RIFF/WAVE container per the model card.
  const mime = bytes[0] === 0x52 && bytes[1] === 0x49 ? "audio/wav" : "audio/mpeg";
  return { bytes, mimeType: mime, provider: `workers-ai:${model}` };
}

/* Language-code mapping note: UniCom stores ISO-639-1 codes; melotts accepts
   the same base codes for its supported set (zh → its zh voice). */
