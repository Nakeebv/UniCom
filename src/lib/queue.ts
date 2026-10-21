/**
 * In-process background worker, standing in for the BullMQ/Redis worker tier
 * described in the architecture (single-process deploy tier shares the event
 * loop; the durable job state lives in Postgres so a restart resumes cleanly).
 *
 * Pipeline contract:
 *  - The API commits message + outbox event + "queued" translation rows in one
 *    transaction, then calls enqueue*() which schedules in-memory tasks.
 *  - States are explicit (queued → processing → completed / failed / stale),
 *    never inferred from the presence of a text field.
 *  - Retries use exponential backoff with jitter; terminal failures keep the
 *    original message perfectly readable.
 */
import { and, eq, ne } from "drizzle-orm";
import { db } from "@/db";
import {
  conversationMembers,
  messageContents,
  messages,
  messageTranslations,
  outboxEvents,
  userPreferences,
  voiceJobs,
} from "@/db/schema";
import { newId } from "@/lib/ids";
import { detectLanguageByPhrase } from "@/lib/i18n/phrasebook";
import { translateText } from "@/lib/providers/translation";
import { transcribeAudio, sttConfigured } from "@/lib/providers/stt";
import { synthesizeSpeech, ttsSupportedFor } from "@/lib/providers/tts";
import { getObjectBytes, mediaKeys, storeObject } from "@/lib/storage";
import { mediaAssets } from "@/db/schema";

const MAX_ATTEMPTS = 3;

/* Timer registry (module-safe across hot reloads). */
const globalTimers = globalThis as typeof globalThis & {
  __unicomTimers?: Set<ReturnType<typeof setTimeout>>;
};
const timers = (globalTimers.__unicomTimers ??= new Set());

function schedule(task: () => Promise<void>, delayMs: number): void {
  const handle = setTimeout(() => {
    timers.delete(handle);
    task().catch((err) => console.error("[worker]", err));
  }, delayMs);
  timers.add(handle);
}

/** Distinct target languages actually required by current members — no more. */
export async function planTargetLanguages(conversationId: string, sourceLanguage: string): Promise<string[]> {
  const rows = await db
    .select({ lang: userPreferences.preferredLanguage })
    .from(conversationMembers)
    .innerJoin(userPreferences, eq(userPreferences.userId, conversationMembers.userId))
    .where(eq(conversationMembers.conversationId, conversationId));
  return [...new Set(rows.map((r) => r.lang).filter((l) => l && l !== sourceLanguage))];
}

export async function markOutboxPublished(eventId: string): Promise<void> {
  await db
    .update(outboxEvents)
    .set({ publishedAt: new Date() })
    .where(eq(outboxEvents.id, eventId));
}

/* ── Text translations ────────────────────────────────────────────────────── */

export async function enqueueTranslationsForMessage(messageId: string): Promise<void> {
  const [msg] = await db.select().from(messages).where(eq(messages.id, messageId)).limit(1);
  if (!msg || msg.deletedAt) return;

  const targets = await planTargetLanguages(msg.conversationId, msg.sourceLanguage);
  for (const target of targets) {
    await upsertTranslationRow({
      messageId,
      targetLanguage: target,
      sourceVersion: msg.version,
      status: "queued",
      detail: "queued via transactional outbox",
    });
    schedule(() => runTranslation(messageId, target, msg.version), 350 + Math.random() * 1100);
  }
}

async function upsertTranslationRow(input: {
  messageId: string;
  targetLanguage: string;
  sourceVersion: number;
  status: string;
  translatedText?: string | null;
  provider?: string | null;
  detail?: string | null;
  attempts?: number;
}): Promise<void> {
  const existing = await db
    .select()
    .from(messageTranslations)
    .where(
      and(
        eq(messageTranslations.messageId, input.messageId),
        eq(messageTranslations.targetLanguage, input.targetLanguage),
        eq(messageTranslations.sourceVersion, input.sourceVersion),
      ),
    )
    .limit(1);

  if (existing[0]) {
    await db
      .update(messageTranslations)
      .set({
        status: input.status,
        translatedText: input.translatedText !== undefined ? input.translatedText : existing[0].translatedText,
        provider: input.provider !== undefined ? input.provider : existing[0].provider,
        detail: input.detail !== undefined ? input.detail : existing[0].detail,
        attempts: input.attempts !== undefined ? input.attempts : existing[0].attempts,
        updatedAt: new Date(),
      })
      .where(eq(messageTranslations.id, existing[0].id));
  } else {
    await db.insert(messageTranslations).values({
      id: newId("trl"),
      messageId: input.messageId,
      targetLanguage: input.targetLanguage,
      sourceVersion: input.sourceVersion,
      status: input.status,
      translatedText: input.translatedText ?? null,
      provider: input.provider ?? null,
      detail: input.detail ?? null,
      attempts: input.attempts ?? 0,
    });
  }
}

export async function runTranslation(
  messageId: string,
  targetLanguage: string,
  sourceVersion: number,
): Promise<void> {
  const [msg] = await db.select().from(messages).where(eq(messages.id, messageId)).limit(1);
  if (!msg || msg.deletedAt || msg.version !== sourceVersion) return; // stale or deleted

  const [content] = await db
    .select()
    .from(messageContents)
    .where(eq(messageContents.messageId, messageId))
    .limit(1);
  const text = content?.originalText?.trim() ?? "";
  if (!text) {
    await upsertTranslationRow({
      messageId,
      targetLanguage,
      sourceVersion,
      status: "failed",
      detail: "empty source text",
      attempts: sourceVersion,
    });
    return;
  }

  const source = msg.sourceLanguage === "auto" ? detectLanguageByPhrase(text) ?? "en" : msg.sourceLanguage;

  const [current] = await db
    .select()
    .from(messageTranslations)
    .where(
      and(
        eq(messageTranslations.messageId, messageId),
        eq(messageTranslations.targetLanguage, targetLanguage),
        eq(messageTranslations.sourceVersion, sourceVersion),
      ),
    )
    .limit(1);
  const attempt = (current?.attempts ?? 0) + 1;

  await upsertTranslationRow({
    messageId,
    targetLanguage,
    sourceVersion,
    status: "processing",
    attempts: attempt,
  });

  try {
    const result = await translateText(text, source, targetLanguage);
    await upsertTranslationRow({
      messageId,
      targetLanguage,
      sourceVersion,
      status: "completed",
      translatedText: result.translatedText,
      provider: result.provider,
      detail: `attempt ${attempt}`,
      attempts: attempt,
    });
  } catch (err) {
    const reason = err instanceof Error ? err.message : "provider failure";
    if (attempt < MAX_ATTEMPTS) {
      await upsertTranslationRow({
        messageId,
        targetLanguage,
        sourceVersion,
        status: "queued",
        detail: `retry ${attempt + 1} scheduled · ${reason.slice(0, 140)}`,
        attempts: attempt,
      });
      schedule(
        () => runTranslation(messageId, targetLanguage, sourceVersion),
        2 ** attempt * 1400 + Math.random() * 800,
      );
    } else {
      await upsertTranslationRow({
        messageId,
        targetLanguage,
        sourceVersion,
        status: "failed",
        detail: reason.slice(0, 240),
        attempts: attempt,
      });
    }
  }
}

/** Manual retry / on-demand request for a specific target language. */
export async function requestTranslation(messageId: string, targetLanguage: string): Promise<void> {
  const [msg] = await db.select().from(messages).where(eq(messages.id, messageId)).limit(1);
  if (!msg || msg.deletedAt) return;
  if (targetLanguage === msg.sourceLanguage) return;
  await upsertTranslationRow({
    messageId,
    targetLanguage,
    sourceVersion: msg.version,
    status: "queued",
    translatedText: null,
    detail: "manual request",
    attempts: 0,
  });
  schedule(() => runTranslation(messageId, targetLanguage, msg.version), 200 + Math.random() * 500);
}

/** Edit invalidation: versions older than the current one become stale. */
export async function invalidateStaleTranslations(messageId: string, currentVersion: number): Promise<void> {
  const rows = await db
    .select()
    .from(messageTranslations)
    .where(eq(messageTranslations.messageId, messageId));
  for (const row of rows) {
    if (row.sourceVersion < currentVersion && row.status !== "stale") {
      await db
        .update(messageTranslations)
        .set({ status: "stale", detail: "superseded by edited source", updatedAt: new Date() })
        .where(eq(messageTranslations.id, row.id));
    }
  }
}

/** Lazily generate a translation on first read (on-demand, never speculative). */
export async function ensureTranslationForReader(messageId: string, readerLanguage: string): Promise<void> {
  const [msg] = await db.select().from(messages).where(eq(messages.id, messageId)).limit(1);
  if (!msg || msg.deletedAt || msg.sourceLanguage === readerLanguage) return;
  const [content] = await db
    .select()
    .from(messageContents)
    .where(eq(messageContents.messageId, messageId))
    .limit(1);
  if (!content?.originalText?.trim()) return;

  const [existing] = await db
    .select()
    .from(messageTranslations)
    .where(
      and(
        eq(messageTranslations.messageId, messageId),
        eq(messageTranslations.targetLanguage, readerLanguage),
        eq(messageTranslations.sourceVersion, msg.version),
      ),
    )
    .limit(1);
  if (existing) return;
  await requestTranslation(messageId, readerLanguage);
}

/* ── Voice pipeline ───────────────────────────────────────────────────────── */

async function setVoiceJob(
  messageId: string,
  targetLanguage: string,
  patch: Partial<{ status: string; detail: string | null; attempts: number }>,
): Promise<string> {
  const [existing] = await db
    .select()
    .from(voiceJobs)
    .where(and(eq(voiceJobs.messageId, messageId), eq(voiceJobs.targetLanguage, targetLanguage)))
    .limit(1);
  if (existing) {
    await db
      .update(voiceJobs)
      .set({
        status: patch.status ?? existing.status,
        detail: patch.detail !== undefined ? patch.detail : existing.detail,
        attempts: patch.attempts ?? existing.attempts,
        updatedAt: new Date(),
      })
      .where(eq(voiceJobs.id, existing.id));
    return existing.id;
  }
  const id = newId("vjob");
  await db.insert(voiceJobs).values({
    id,
    messageId,
    targetLanguage,
    status: patch.status ?? "queued",
    detail: patch.detail ?? null,
    attempts: patch.attempts ?? 0,
  });
  return id;
}

export async function enqueueVoiceJobs(messageId: string): Promise<void> {
  const [msg] = await db.select().from(messages).where(eq(messages.id, messageId)).limit(1);
  if (!msg || msg.deletedAt || msg.type !== "voice") return;

  const [content] = await db
    .select()
    .from(messageContents)
    .where(eq(messageContents.messageId, messageId))
    .limit(1);
  const transcript = content?.originalText?.trim() ?? "";

  if (!transcript) {
    // No transcript yet: schedule real speech-to-text on the uploaded audio.
    // When no STT provider is configured, fail honestly — the original audio
    // remains playable either way.
    if (!sttConfigured()) {
      await setVoiceJob(messageId, "*", {
        status: "failed_retryable",
        detail:
          "Transcription pending — configure an STT provider (Cloudflare Workers AI or Groq) to enable the voice pipeline",
        attempts: 1,
      });
      return;
    }
    await setVoiceJob(messageId, "*", {
      status: "transcribing",
      detail: "transcribing recorded audio",
      attempts: 1,
    });
    schedule(() => runSttThenEnqueue(messageId), 400 + Math.random() * 600);
    return;
  }

  const targets = await planTargetLanguages(msg.conversationId, msg.sourceLanguage);
  if (targets.length === 0) {
    await setVoiceJob(messageId, msg.sourceLanguage, {
      status: "completed",
      detail: "No translation targets — all members share the source language",
      attempts: 1,
    });
    return;
  }

  for (const target of targets) {
    await setVoiceJob(messageId, target, { status: "queued", detail: "voice pipeline queued", attempts: 1 });
    schedule(() => runVoicePipeline(messageId, target, msg.version), 300 + Math.random() * 600);
  }
}

/**
 * Stage 1 of the voice pipeline for clips without a client-provided
 * transcript: load the stored audio, run STT, persist the transcript, then
 * fan the message out to each recipient language exactly like a text message.
 */
async function runSttThenEnqueue(messageId: string): Promise<void> {
  const retryable = async (detail: string) => {
    await setVoiceJob(messageId, "*", { status: "failed_retryable", detail });
  };

  try {
    const [msg] = await db.select().from(messages).where(eq(messages.id, messageId)).limit(1);
    if (!msg || msg.deletedAt || msg.type !== "voice" || !msg.mediaAssetId) {
      await retryable("voice message has no audio asset");
      return;
    }
    const [asset] = await db
      .select()
      .from(mediaAssets)
      .where(eq(mediaAssets.id, msg.mediaAssetId))
      .limit(1);
    if (!asset) {
      await retryable("audio asset missing");
      return;
    }

    let bytes: Uint8Array | null = null;
    if (asset.storageKey) {
      bytes = await getObjectBytes(asset.storageKey);
    } else if (asset.dataBase64) {
      bytes = new Uint8Array(Buffer.from(asset.dataBase64, "base64"));
    }
    if (!bytes || bytes.byteLength === 0) {
      await retryable("audio bytes unavailable");
      return;
    }

    const result = await transcribeAudio(bytes, {
      mimeType: asset.mimeType,
      languageHint: msg.sourceLanguage,
    });

    const [existingContent] = await db
      .select()
      .from(messageContents)
      .where(eq(messageContents.messageId, messageId))
      .limit(1);
    if (existingContent) {
      await db
        .update(messageContents)
        .set({ originalText: result.transcript })
        .where(eq(messageContents.messageId, messageId));
    } else {
      await db.insert(messageContents).values({ messageId, originalText: result.transcript });
    }

    await setVoiceJob(messageId, "*", {
      status: "queued",
      detail: `transcribed via ${result.provider}`,
    });

    const targets = await planTargetLanguages(msg.conversationId, msg.sourceLanguage);
    if (targets.length === 0) {
      await setVoiceJob(messageId, msg.sourceLanguage, {
        status: "completed",
        detail: "Transcribed — all members share the source language",
        attempts: 1,
      });
      return;
    }
    for (const target of targets) {
      await setVoiceJob(messageId, target, { status: "queued", detail: "voice pipeline queued" });
      schedule(() => runVoicePipeline(messageId, target, msg.version), 300 + Math.random() * 600);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : "transcription failed";
    await retryable(message.slice(0, 220));
  }
}

async function runVoicePipeline(messageId: string, target: string, sourceVersion: number): Promise<void> {
  const [msg] = await db.select().from(messages).where(eq(messages.id, messageId)).limit(1);
  if (!msg || msg.deletedAt || msg.version !== sourceVersion) return;
  const [content] = await db
    .select()
    .from(messageContents)
    .where(eq(messageContents.messageId, messageId))
    .limit(1);
  const transcript = content?.originalText?.trim() ?? "";
  if (!transcript) return;

  await setVoiceJob(messageId, target, { status: "transcribing", detail: "on-device transcript received" });
  await sleep(250 + Math.random() * 350);

  await setVoiceJob(messageId, target, { status: "translating", detail: `translating → ${target}` });
  try {
    await runTranslation(messageId, target, sourceVersion);
    const [t] = await db
      .select()
      .from(messageTranslations)
      .where(
        and(
          eq(messageTranslations.messageId, messageId),
          eq(messageTranslations.targetLanguage, target),
          eq(messageTranslations.sourceVersion, sourceVersion),
        ),
      )
      .limit(1);
    if (!t || t.status !== "completed") {
      await setVoiceJob(messageId, target, {
        status: "failed_retryable",
        detail: t?.detail?.slice(0, 200) ?? "translation failed",
      });
      return;
    }
  } catch (err) {
    await setVoiceJob(messageId, target, {
      status: "failed_retryable",
      detail: err instanceof Error ? err.message.slice(0, 200) : "translation failed",
    });
    return;
  }

  await setVoiceJob(messageId, target, {
    status: "synthesizing",
    detail: "generating target-language speech",
  });

  /* Real TTS via Workers AI melotts for covered languages. A speech failure
     never erases the completed translation: the job completes text-only with
     an honest detail, and the recipient keeps "text + original audio". */
  if (!ttsSupportedFor(target)) {
    await setVoiceJob(messageId, target, {
      status: "completed",
      detail: `Translation ready — spoken variant not available for ${target} (demo)`,
    });
    return;
  }

  try {
    const [translatedRow] = await db
      .select()
      .from(messageTranslations)
      .where(
        and(
          eq(messageTranslations.messageId, messageId),
          eq(messageTranslations.targetLanguage, target),
          eq(messageTranslations.sourceVersion, sourceVersion),
        ),
      )
      .limit(1);
    const spokenText = translatedRow?.translatedText?.trim();
    if (!spokenText) {
      await setVoiceJob(messageId, target, {
        status: "completed",
        detail: "Translation ready — no speakable text",
      });
      return;
    }

    // Cache: reuse an existing identical variant for this message+language.
    const [existingJob] = await db
      .select()
      .from(voiceJobs)
      .where(and(eq(voiceJobs.messageId, messageId), eq(voiceJobs.targetLanguage, target)))
      .limit(1);
    if (existingJob?.outputMediaId) {
      await setVoiceJob(messageId, target, {
        status: "completed",
        detail: "Translated speech ready",
      });
      return;
    }

    const speech = await synthesizeSpeech(spokenText, target);
    const assetId = newId("med");
    const stored = await storeObject(
      mediaKeys.ttsVariant(messageId, target),
      speech.bytes,
      speech.mimeType,
    );

    await db.insert(mediaAssets).values({
      id: assetId,
      ownerId: msg.senderId,
      kind: "tts",
      mimeType: speech.mimeType,
      sizeBytes: speech.bytes.byteLength,
      durationMs: null,
      storageKey: stored?.storageKey ?? null,
      dataBase64: stored ? null : Buffer.from(speech.bytes).toString("base64"),
    });
    await db
      .update(voiceJobs)
      .set({ outputMediaId: assetId, updatedAt: new Date() })
      .where(
        and(eq(voiceJobs.messageId, messageId), eq(voiceJobs.targetLanguage, target)),
      );

    await setVoiceJob(messageId, target, {
      status: "completed",
      detail: `Translated speech ready via ${speech.provider}`,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "speech generation failed";
    await setVoiceJob(messageId, target, {
      status: "completed",
      detail: `Translation ready — spoken variant unavailable (${message.slice(0, 120)})`,
    });
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
