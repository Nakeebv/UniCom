import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { mediaAssets, messages } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { isMember } from "@/lib/serialize";
import { presignGetUrl } from "@/lib/storage";

/**
 * Serves a private media asset to conversation members.
 *
 * With R2 configured this responds 302 → short-lived presigned URL (bytes
 * stream straight from the bucket, never through the server). Without R2 it
 * streams the demo-tier inline bytes. Ownership / membership checks are
 * identical for both tiers.
 */
export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [asset] = await db.select().from(mediaAssets).where(eq(mediaAssets.id, id)).limit(1);
  if (!asset) return NextResponse.json({ error: "not found" }, { status: 404 });

  if (asset.ownerId !== me.id) {
    const [msg] = await db.select().from(messages).where(eq(messages.mediaAssetId, id)).limit(1);
    if (!msg || !(await isMember(msg.conversationId, me.id))) {
      return NextResponse.json({ error: "forbidden" }, { status: 403 });
    }
  }

  const wantsJsonUrl = new URL(request.url).searchParams.get("url") === "1";

  if (asset.storageKey) {
    const url = await presignGetUrl(asset.storageKey, 120);
    if (wantsJsonUrl) {
      return NextResponse.json({ url, expires_in: 120, mime_type: asset.mimeType });
    }
    return NextResponse.redirect(url, { status: 302 });
  }

  if (!asset.dataBase64) {
    return NextResponse.json({ error: "asset has no data" }, { status: 410 });
  }
  const bytes = Buffer.from(asset.dataBase64, "base64");
  return new NextResponse(new Uint8Array(bytes), {
    headers: {
      "content-type": asset.mimeType,
      "content-length": String(bytes.length),
      "cache-control": "private, max-age=3600",
      "x-content-type-options": "nosniff",
    },
  });
}

export const runtime = "nodejs";
