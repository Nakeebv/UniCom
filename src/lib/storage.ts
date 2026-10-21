import { AwsClient } from "aws4fetch";
import { storage } from "./config";

/**
 * Private object storage with two interchangeable backends:
 *
 *  • R2 (Cloudflare, S3-compatible) — production path. Objects are uploaded
 *    server-side; reads go through short-lived presigned GET URLs so bytes
 *    never flow through the Node process at playback time.
 *
 *  • Postgres (base64 column) — zero-config demo tier. Media the API
 *    controller stores inline; reads stream through the route with authz.
 *
 * Callers decide per-asset which tier to use via [storeObject] returning
 * null (→ DB fallback) or a storage key.
 */

export type StoredObject = { storageKey: string };

function client(): AwsClient {
  if (!storage.r2Enabled) throw new Error("R2 is not configured");
  return new AwsClient({
    accessKeyId: storage.accessKeyId!,
    secretAccessKey: storage.secretAccessKey!,
    region: "auto",
    service: "s3",
  });
}

function endpoint(key: string, query = ""): string {
  const base = `https://${storage.accountId}.r2.cloudflarestorage.com/${storage.bucket}/${encodeR2Key(key)}`;
  return query ? `${base}?${query}` : base;
}

/** S3 keys may contain slashes; components must be URI-encoded. */
function encodeR2Key(key: string): string {
  return key
    .split("/")
    .map((part) => encodeURIComponent(part))
    .join("/");
}

/** Uploads bytes to R2. Returns null when R2 is not configured (caller falls back to DB). */
export async function storeObject(
  key: string,
  bytes: Uint8Array,
  contentType: string,
): Promise<StoredObject | null> {
  if (!storage.r2Enabled) return null;
  const res = await client().fetch(endpoint(key), {
    method: "PUT",
    body: bytes as unknown as BodyInit,
    headers: { "content-type": contentType, "content-length": String(bytes.byteLength) },
  });
  if (!res.ok) throw new Error(`r2 put failed: http ${res.status}`);
  return { storageKey: key };
}

/** Signed GET URL for private playback. Throws when R2 is not configured. */
export async function presignGetUrl(key: string, ttlSeconds = 120): Promise<string> {
  const signed = await client().sign(new Request(endpoint(key)), {
    aws: { signQuery: true },
  });
  const url = new URL(signed.url);
  url.searchParams.set("X-Amz-Expires", String(ttlSeconds));
  return url.toString();
}

/** Fetches object bytes (used server-side, e.g. feeding STT). */
export async function getObjectBytes(key: string): Promise<Uint8Array> {
  const res = await client().fetch(endpoint(key), { method: "GET" });
  if (!res.ok) throw new Error(`r2 get failed: http ${res.status}`);
  return new Uint8Array(await res.arrayBuffer());
}

export async function deleteObject(key: string): Promise<void> {
  if (!storage.r2Enabled) return;
  await client().fetch(endpoint(key), { method: "DELETE" });
}

/* ── Key namespaces ───────────────────────────────────────────────────────── */

export const mediaKeys = {
  voiceNote: (assetId: string, ext: string) => `voice/${assetId}.${ext}`,
  ttsVariant: (messageId: string, lang: string) => `tts/${messageId}.${lang}.mp3`,
  avatar: (userId: string, ext: string) => `avatars/${userId}.${ext}`,
} as const;

export function extFromMime(mimeType: string): string {
  if (mimeType.includes("webm")) return "webm";
  if (mimeType.includes("ogg")) return "ogg";
  if (mimeType.includes("wav")) return "wav";
  if (mimeType.includes("flac")) return "flac";
  if (mimeType.includes("mpeg")) return "mp3";
  if (mimeType.includes("mp3")) return "mp3";
  if (mimeType.includes("mp4") || mimeType.includes("m4a")) return "m4a";
  if (mimeType.includes("jpeg")) return "jpg";
  if (mimeType.includes("png")) return "png";
  if (mimeType.includes("webp")) return "webp";
  return "bin";
}
