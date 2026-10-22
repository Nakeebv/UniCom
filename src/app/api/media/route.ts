import { NextResponse } from "next/server";
import { db } from "@/db";
import { mediaAssets } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { config as appConfig } from "@/lib/config";
import { newId } from "@/lib/ids";
import { extFromMime, mediaKeys, storeObject } from "@/lib/storage";
import { RULES, enforce } from "@/lib/rate-limit";

const MAX_BYTES = appConfig.limits.maxAudioBytes; // voice notes: small, private uploads
const MAX_DURATION_MS = appConfig.limits.maxAudioMs;

/**
 * Voice-note upload (server-mediated).
 *
 * When R2 credentials are configured the bytes are written to the private
 * bucket and only the storage key is persisted. Without credentials the
 * base64 body stays in Postgres (demo tier). Same validation either way.
 */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const limited = enforce(RULES.media, me.id);
  if (limited) return limited;
  const body = (await request.json().catch(() => null)) as {
    base64?: string;
    mimeType?: string;
    durationMs?: number;
  } | null;

  const base64 = body?.base64 ?? "";
  const mimeType = (body?.mimeType ?? "audio/webm").toLowerCase();
  const durationMs = Math.min(Math.max(Math.round(body?.durationMs ?? 0), 0), MAX_DURATION_MS);

  if (!mimeType.startsWith("audio/")) {
    return NextResponse.json({ error: "Only audio uploads are accepted" }, { status: 400 });
  }
  if (!base64 || !/^[A-Za-z0-9+/=\r\n]+$/.test(base64)) {
    return NextResponse.json({ error: "Invalid upload body" }, { status: 400 });
  }
  const clean64 = base64.replace(/[\r\n]/g, "");
  const sizeBytes = Math.floor((clean64.length * 3) / 4);
  if (sizeBytes > MAX_BYTES) {
    return NextResponse.json({ error: "Voice note exceeds the 8 MB limit" }, { status: 413 });
  }

  const id = newId("med");
  let storageKey: string | null = null;
  let dataBase64: string | null = null;

  if (appConfig.storage.r2Enabled) {
    const bytes = Buffer.from(clean64, "base64");
    const stored = await storeObject(
      mediaKeys.voiceNote(id, extFromMime(mimeType)),
      new Uint8Array(bytes),
      mimeType,
    );
    if (stored) {
      storageKey = stored.storageKey;
    } else {
      dataBase64 = clean64;
    }
  } else {
    dataBase64 = clean64;
  }

  await db.insert(mediaAssets).values({
    id,
    ownerId: me.id,
    kind: "voice",
    mimeType,
    sizeBytes,
    durationMs: durationMs || null,
    storageKey,
    dataBase64,
  });

  return NextResponse.json({ asset_id: id, url: `/api/media/${id}`, size_bytes: sizeBytes }, { status: 201 });
}

export const runtime = "nodejs";
