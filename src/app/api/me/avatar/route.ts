import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { config as appConfig } from "@/lib/config";
import { extFromMime, mediaKeys, storeObject } from "@/lib/storage";

/**
 * Uploads the signed-in user's avatar.
 * Body: { base64, mimeType } (image/jpeg | png | webp, ≤2MB).
 * Stored in R2 when configured (private bucket); the read endpoint serves it
 * to other authenticated users via short-lived presigned redirects.
 */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as {
    base64?: string;
    mimeType?: string;
  } | null;

  const mimeType = (body?.mimeType ?? "image/jpeg").toLowerCase();
  const base64 = body?.base64 ?? "";
  if (!mimeType.startsWith("image/")) {
    return NextResponse.json({ error: "Only image uploads are accepted" }, { status: 400 });
  }
  if (!["image/jpeg", "image/png", "image/webp"].includes(mimeType)) {
    return NextResponse.json({ error: "Unsupported image format" }, { status: 400 });
  }
  if (!base64 || !/^[A-Za-z0-9+/=\r\n]+$/.test(base64)) {
    return NextResponse.json({ error: "Invalid upload body" }, { status: 400 });
  }
  const clean64 = base64.replace(/[\r\n]/g, "");
  const sizeBytes = Math.floor((clean64.length * 3) / 4);
  if (sizeBytes > appConfig.limits.maxAvatarBytes) {
    return NextResponse.json({ error: "Avatar exceeds the 2 MB limit" }, { status: 413 });
  }

  const key = mediaKeys.avatar(me.id, extFromMime(mimeType));
  let avatarKey: string | null = null;

  if (appConfig.storage.r2Enabled) {
    const stored = await storeObject(key, new Uint8Array(Buffer.from(clean64, "base64")), mimeType);
    if (stored) avatarKey = stored.storageKey;
  }

  if (!avatarKey) {
    // No R2 configured: keep old behavior (hue avatar) with an explicit,
    // honest response — we do not store image bytes in Postgres for avatars.
    return NextResponse.json(
      { error: "Avatar storage is not configured on this deployment" },
      { status: 503 },
    );
  }

  await db.update(users).set({ avatarKey }).where(eq(users.id, me.id));
  return NextResponse.json({
    ok: true,
    avatar_url: `/api/users/${me.id}/avatar`,
  });
}

export const runtime = "nodejs";
