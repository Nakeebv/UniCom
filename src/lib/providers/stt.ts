import { cfAi, groq, features } from "@/lib/config";

/**
 * Pluggable speech-to-text providers — mirrors the translation provider
 * contract. Never fake success: any failure throws and the caller keeps the
 * voice job in a retryable state with the original audio still playable.
 *
 *   cloudflare → Workers AI @cf/openai/whisper (multilingual ASR, ~$0.0005/min)
 *   groq       → whisper-large-v3-turbo (OpenAI-compatible, free tier, m4a ok)
 *   off        → disabled; caller surfaces a clear, honest configuration error
 *
 * STT_PROVIDER selects explicitly; "auto" tries every configured provider in
 * the order cloudflare → groq.
 */

export type TranscribeResult = {
  transcript: string;
  provider: string;
  detectedLanguage?: string;
};

export class SttError extends Error {
  provider: string;
  constructor(provider: string, message: string) {
    super(message);
    this.provider = provider;
  }
}

type SttProvider = {
  name: string;
  enabled(): boolean;
  transcribe(
    bytes: Uint8Array,
    opts: { mimeType: string; languageHint?: string | null },
  ): Promise<TranscribeResult>;
};

async function fetchWithTimeout(url: string, ms: number, init?: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

const cloudflareWhisper: SttProvider = {
  name: "cloudflare-whisper",
  enabled() {
    return cfAi.whisperEnabled && ["auto", "cloudflare"].includes(features.stt);
  },
  async transcribe(bytes, { languageHint }) {
    if (!cfAi.accountId || !cfAi.apiToken) {
      throw new SttError("cloudflare-whisper", "not configured");
    }
    const model = cfAi.whisperModel;
    const res = await fetchWithTimeout(
      `https://api.cloudflare.com/client/v4/accounts/${cfAi.accountId}/ai/run/${model}`,
      60_000,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${cfAi.apiToken}`,
          "content-type": "application/octet-stream",
        },
        body: bytes as unknown as BodyInit,
      },
    );
    if (!res.ok) {
      throw new SttError("cloudflare-whisper", `http ${res.status}`);
    }
    const data = (await res.json().catch(() => null)) as
      | { success?: boolean; result?: { text?: string } }
      | null;
    const text = data?.result?.text?.trim();
    if (!data?.success || !text) {
      throw new SttError("cloudflare-whisper", "empty transcription");
    }
    return { transcript: text, provider: `workers-ai:${model}` };
  },
};

const groqWhisper: SttProvider = {
  name: "groq-whisper",
  enabled() {
    return groq.sttEnabled && ["auto", "groq"].includes(features.stt);
  },
  async transcribe(bytes, { mimeType, languageHint }) {
    if (!groq.apiKey) throw new SttError("groq-whisper", "not configured");
    const form = new FormData();
    form.append(
      "file",
      new Blob([bytes as unknown as BlobPart], { type: mimeType || "audio/m4a" }),
      "audio.m4a",
    );
    form.append("model", groq.sttModel);
    form.append("response_format", "json");
    if (languageHint && /^[a-z]{2}(-[A-Za-z]{2,4})?$/.test(languageHint)) {
      form.append("language", languageHint.split("-")[0]);
    }
    const res = await fetchWithTimeout(`${groq.baseUrl}/audio/transcriptions`, 60_000, {
      method: "POST",
      headers: { authorization: `Bearer ${groq.apiKey}` },
      body: form,
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new SttError("groq-whisper", `http ${res.status}${detail.slice(0, 120)}`);
    }
    const data = (await res.json().catch(() => null)) as { text?: string } | null;
    const text = data?.text?.trim();
    if (!text) throw new SttError("groq-whisper", "empty transcription");
    return { transcript: text, provider: `groq:${groq.sttModel}` };
  },
};

const off: SttProvider = {
  name: "stt-off",
  enabled() {
    return features.stt === "off";
  },
  async transcribe() {
    throw new SttError("stt-off", "Speech-to-text is disabled by configuration (STT_PROVIDER=off)");
  },
};

function providerOrder(): SttProvider[] {
  if (features.stt === "off") return [off];
  if (features.stt === "cloudflare") return [cloudflareWhisper];
  if (features.stt === "groq") return [groqWhisper];
  return [cloudflareWhisper, groqWhisper];
}

export function sttConfigured(): boolean {
  return providerOrder().some((p) => p.enabled());
}

export async function transcribeAudio(
  bytes: Uint8Array,
  opts: { mimeType: string; languageHint?: string | null },
): Promise<TranscribeResult> {
  const failures: string[] = [];
  for (const provider of providerOrder()) {
    if (!provider.enabled()) {
      failures.push(`${provider.name}: not configured`);
      continue;
    }
    try {
      return await provider.transcribe(bytes, opts);
    } catch (err) {
      const message = err instanceof Error ? err.message : "unknown";
      failures.push(`${provider.name}: ${message}`);
    }
  }
  throw new Error(failures.join(" · ") || "no speech-to-text provider configured");
}
