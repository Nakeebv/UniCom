import { randomBytes, randomUUID, createHash } from "node:crypto";

/** Server-generated, prefixed opaque IDs (msg_…, conv_…) — matching the architecture doc. */
export function newId(prefix: string): string {
  return `${prefix}_${randomUUID().replace(/-/g, "").slice(0, 20)}`;
}

export function newToken(): string {
  return randomBytes(32).toString("base64url");
}

/** Stable content hash used for translation-cache keys. */
export function contentHash(input: string): string {
  return createHash("sha256").update(input, "utf8").digest("hex").slice(0, 24);
}
