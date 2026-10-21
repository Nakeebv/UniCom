/**
 * Central, typed configuration for optional integrations.
 *
 * Everything here is ENV-GATED: the product stays fully functional (with the
 * demo/demo-tier paths) when values are absent, and upgrades itself the
 * moment keys are dropped in. No secret is ever read outside this module.
 */

function env(name: string): string | null {
  const v = process.env[name];
  return v && v.trim() ? v.trim() : null;
}

function bool(name: string, fallback: boolean): boolean {
  const v = env(name);
  if (v == null) return fallback;
  return ["1", "true", "yes", "on"].includes(v.toLowerCase());
}

/* ── Cloudflare R2 (S3-compatible private object storage) ────────────────── */

const r2AccountId = env("R2_ACCOUNT_ID") ?? env("CLOUDFLARE_ACCOUNT_ID");
const r2KeyId = env("R2_ACCESS_KEY_ID");
const r2Secret = env("R2_SECRET_ACCESS_KEY");
const r2Bucket = env("R2_BUCKET");

export const storage = {
  /** R2 active only when all four values exist; otherwise Postgres bytes. */
  get r2Enabled() {
    return Boolean(r2AccountId && r2KeyId && r2Secret && r2Bucket);
  },
  get accountId() {
    return r2AccountId;
  },
  get accessKeyId() {
    return r2KeyId;
  },
  get secretAccessKey() {
    return r2Secret;
  },
  get bucket() {
    return r2Bucket;
  },
} as const;

/* ── Workers AI / Groq (speech + language models) ────────────────────────── */

export const cfAi = {
  get accountId() {
    return env("CLOUDFLARE_ACCOUNT_ID") ?? r2AccountId;
  },
  get apiToken() {
    return env("CLOUDFLARE_AI_API_TOKEN");
  },
  get whisperEnabled() {
    return Boolean(env("CLOUDFLARE_ACCOUNT_ID") && env("CLOUDFLARE_AI_API_TOKEN"));
  },
  /** Accuracy/price is identical per minute across the two whisper models. */
  get whisperModel() {
    return env("CLOUDFLARE_WHISPER_MODEL") ?? "@cf/openai/whisper";
  },
  get ttsEnabled() {
    return Boolean(env("CLOUDFLARE_ACCOUNT_ID") && env("CLOUDFLARE_AI_API_TOKEN"));
  },
  get ttsModel() {
    return env("CLOUDFLARE_TTS_MODEL") ?? "@cf/myshell-ai/melotts";
  },
} as const;

export const groq = {
  get apiKey() {
    return env("GROQ_API_KEY");
  },
  get sttEnabled() {
    return Boolean(env("GROQ_API_KEY"));
  },
  get sttModel() {
    return env("GROQ_STT_MODEL") ?? "whisper-large-v3-turbo";
  },
  get mtEnabled() {
    return Boolean(env("GROQ_API_KEY"));
  },
  get mtModel() {
    return env("GROQ_MT_MODEL") ?? "openai/gpt-oss-20b";
  },
  get baseUrl() {
    return env("GROQ_BASE_URL") ?? "https://api.groq.com/openai/v1";
  },
} as const;

/* ── Feature selectors (default: auto = use what's configured) ───────────── */

export const features = {
  get stt() {
    return env("STT_PROVIDER") ?? "auto"; // auto | cloudflare | groq | off
  },
  get tts() {
    return env("TTS_PROVIDER") ?? "auto"; // auto | cloudflare | off
  },
  get storage() {
    return env("STORAGE") ?? "auto"; // auto | r2 | db
  },
} as const;

/* ── Upload limits (shared by routes) ────────────────────────────────────── */

export const limits = {
  maxAudioBytes: 8 * 1024 * 1024,
  maxAudioMs: 3 * 60 * 1000,
  maxAvatarBytes: 2 * 1024 * 1024,
  /** STT providers reject clips beyond ~25MB free tier; ours are far smaller. */
  maxSttBytes: 24 * 1024 * 1024,
} as const;

/** Alias kept for route-layer readability: `import { config } from '@/lib/config'`. */
export const config = {
  storage,
  cfAi,
  groq,
  features,
  limits,
} as const;
