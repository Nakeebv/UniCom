import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { mediaAssets, messages } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { isMember } from "@/lib/serialize";

export const dynamic = "force-dynamic";

type Params = { params: Promise<{ id: string }> };

/** Authorized download: owner or a verified member of the owning conversation. */
export async function GET(_request: Request, { params }: Params) {
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
