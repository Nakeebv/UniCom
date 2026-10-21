/**
 * Pluggable machine-translation providers.
 *
 * UniCom never hard-depends on one AI vendor: providers implement a common
 * contract and are tried in order. Configure with TRANSLATION_PROVIDER=
 *   auto       (default) mymemory → google-gtx → offline phrasebook
 *   mymemory   force MyMemory only
 *   gtx        force Google free endpoint only
 *   offline    force the built-in reviewed phrasebook (deterministic demo)
 */
import { contentHash } from "@/lib/ids";
import { phraseLookup } from "@/lib/i18n/phrasebook";

export type TranslateResult = {
  translatedText: string;
  provider: string;
  detectedSourceLanguage?: string;
};

class ProviderError extends Error {
  provider: string;
  constructor(provider: string, message: string) {
    super(message);
    this.provider = provider;
  }
}

async function fetchWithTimeout(url: string, ms: number): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(url, { signal: controller.signal, headers: { "user-agent": "unicom-demo/1.0" } });
  } finally {
    clearTimeout(timer);
  }
}

type Provider = {
  name: string;
  translate(text: string, source: string, target: string): Promise<{ translatedText: string; detectedSourceLanguage?: string }>;
};

/** Free keyless endpoint — fine for development quotas, not a production SLA. */
const mymemory: Provider = {
  name: "mymemory",
  async translate(text, source, target) {
    const url =
      `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text.slice(0, 480))}` +
      `&langpair=${encodeURIComponent(`${source}|${target}`)}`;
    let res: Response;
    try {
      res = await fetchWithTimeout(url, 7000);
    } catch {
      throw new ProviderError("mymemory", "network timeout / unreachable");
    }
    if (!res.ok) throw new ProviderError("mymemory", `http ${res.status}`);
    const data = (await res.json().catch(() => null)) as
      | { responseData?: { translatedText?: string }; responseStatus?: number | string }
      | null;
    const out = data?.responseData?.translatedText;
    if (!out || typeof out !== "string") throw new ProviderError("mymemory", "empty response");
    if (/QUERY LENGTH LIMIT|MYMEMORY WARNING/i.test(out)) {
      throw new ProviderError("mymemory", "quota / input rejected");
    }
    return { translatedText: out };
  },
};

/** Free Google gtx endpoint — unofficial, used strictly as a resilience fallback. */
const googleGtx: Provider = {
  name: "google-gtx",
  async translate(text, source, target) {
    const url =
      "https://translate.googleapis.com/translate_a/single" +
      `?client=gtx&sl=${encodeURIComponent(source)}&tl=${encodeURIComponent(target)}&dt=t&q=${encodeURIComponent(text.slice(0, 800))}`;
    let res: Response;
    try {
      res = await fetchWithTimeout(url, 7000);
    } catch {
      throw new ProviderError("google-gtx", "network timeout / unreachable");
    }
    if (!res.ok) throw new ProviderError("google-gtx", `http ${res.status}`);
    const data = (await res.json().catch(() => null)) as unknown;
    if (!Array.isArray(data) || !Array.isArray(data[0])) {
      throw new ProviderError("google-gtx", "unexpected payload");
    }
    const segments = data[0] as Array<[string | null, ...unknown[]]>;
    const out = segments.map((seg) => seg?.[0] ?? "").join("").trim();
    if (!out) throw new ProviderError("google-gtx", "empty response");
    return { translatedText: out };
  },
};

/** Deterministic, reviewed phrasebook — the graceful-degradation provider. */
const phrasebook: Provider = {
  name: "phrasebook-offline",
  async translate(text, source, target) {
    const hit = phraseLookup(text, source, target);
    if (!hit) {
      throw new ProviderError("phrasebook-offline", "untested pair in offline mode");
    }
    return { translatedText: hit.translatedText };
  },
};

function providerOrder(): Provider[] {
  switch (process.env.TRANSLATION_PROVIDER ?? "auto") {
    case "mymemory":
      return withGroqIfConfigured([mymemory, phrasebook]);
    case "gtx":
      return withGroqIfConfigured([googleGtx, phrasebook]);
    case "offline":
      return [phrasebook];
    default:
      return withGroqIfConfigured([mymemory, googleGtx, phrasebook]);
  }
}

/**
 * Groq hosts open LLMs (default llama-3.3-70b) with a generous free tier.
 * When a key exists, an LLM provider is PREPENDED: it produces markedly
 * better translations than the free keyless endpoints, especially for rare
 * language pairs and longer sentences. The prompt is constrained to output
 * translation text only. Falls through to the classic chain on any failure.
 */
function withGroqIfConfigured(base: Provider[]): Provider[] {
  if (!groqMt) return base;
  return [groqMt, ...base];
}

const groqMt: Provider | null = buildGroqMt();

function buildGroqMt(): Provider | null {
  const apiKey = process.env.GROQ_API_KEY?.trim();
  if (!apiKey) return null;
  const model = process.env.GROQ_MT_MODEL?.trim() || "openai/gpt-oss-20b";
  const baseUrl = process.env.GROQ_BASE_URL?.trim() || "https://api.groq.com/openai/v1";

  return {
    name: `groq:${model}`,
    async translate(text, source, target) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 20_000);
      try {
        const res = await fetch(`${baseUrl}/chat/completions`, {
          method: "POST",
          headers: {
            authorization: `Bearer ${apiKey}`,
            "content-type": "application/json",
          },
          signal: controller.signal,
          body: JSON.stringify({
            model,
            temperature: 0.2,
            max_tokens: Math.min(2048, Math.max(128, Math.ceil(text.length * 3))),
            messages: [
              {
                role: "system",
                content:
                  "You are a translation engine inside the UniCom messenger. " +
                  `Translate the user's message from language code "${source}" to language code "${target}". ` +
                  "Rules: output ONLY the translation — no quotes, no explanations, no language names. " +
                  "Preserve tone, emoji, names, links and line breaks. " +
                  "If the text is already in the target language, output it unchanged.",
              },
              { role: "user", content: text },
            ],
          }),
        });
        if (!res.ok) {
          const detail = await res.text().catch(() => "");
          throw new ProviderError(`groq:${model}`, `http ${res.status} ${detail.slice(0, 120)}`);
        }
        const data = (await res.json().catch(() => null)) as
          | { choices?: Array<{ message?: { content?: string } }> }
          | null;
        const out = data?.choices?.[0]?.message?.content?.trim();
        if (!out) throw new ProviderError(`groq:${model}`, "empty response");
        // Some models like to wrap translations in quotes — strip symmetric wrappers.
        const cleaned = out.replace(/^["“”'«»]+|["“”'«»]+$/g, "").trim();
        if (!cleaned) throw new ProviderError(`groq:${model}`, "empty response");
        return { translatedText: cleaned };
      } catch (err) {
        if (err instanceof ProviderError) throw err;
        throw new ProviderError(`groq:${model}`, err instanceof Error ? err.message : "request failed");
      } finally {
        clearTimeout(timer);
      }
    },
  };
}

/** Privacy-aware cache: in-memory only, keyed by content hash, per-process. */
const cache = new Map<string, TranslateResult>();

export async function translateText(
  text: string,
  sourceLanguage: string,
  targetLanguage: string,
): Promise<TranslateResult> {
  if (sourceLanguage === targetLanguage) {
    return { translatedText: text, provider: "same-language" };
  }
  const cacheKey = `${sourceLanguage}|${targetLanguage}|${contentHash(text)}`;
  const hit = cache.get(cacheKey);
  if (hit) return hit;

  const failures: string[] = [];
  for (const provider of providerOrder()) {
    try {
      const result = await provider.translate(text, sourceLanguage, targetLanguage);
      const record: TranslateResult = { ...result, provider: provider.name };
      cache.set(cacheKey, record);
      return record;
    } catch (err) {
      const message = err instanceof Error ? err.message : "unknown";
      failures.push(`${provider.name}: ${message}`);
    }
  }
  throw new Error(failures.join(" · ") || "all providers unavailable");
}

export const providerHealth = providerOrder().map((p) => p.name);
