import { NextResponse } from "next/server";
import { db } from "@/db";
import { mediaAssets } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { newId } from "@/lib/ids";

const MAX_BYTES = 8 * 1024 * 1024; // voice notes only: small, private uploads
const MAX_DURATION_MS = 3 * 60 * 1000;

/**
 * Upload-intent equivalent for the single-process tier: validated base64 audio
 * bodies. Production UniCom issues short-lived, scoped pre-signed URLs to a
 * private bucket — the same ownership + completion checks apply here.
 */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

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
  const sizeBytes = Math.floor((base64.length * 3) / 4);
  if (sizeBytes > MAX_BYTES) {
    return NextResponse.json({ error: "Voice note exceeds the 8 MB limit" }, { status: 413 });
  }

  const id = newId("med");
  await db.insert(mediaAssets).values({
    id,
    ownerId: me.id,
    mimeType,
    sizeBytes,
    durationMs: durationMs || null,
    dataBase64: base64,
  });

  return NextResponse.json({ asset_id: id, url: `/api/media/${id}`, size_bytes: sizeBytes }, { status: 201 });
}
