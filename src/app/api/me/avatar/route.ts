import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { config as appConfig } from "@/lib/config";
import { deleteObject, extFromMime, mediaKeys, storeObject } from "@/lib/storage";

export const dynamic = "force-dynamic";

/** Real image-signature validation (magic bytes), not just extension sniffing. */
function imageKind(bytes: Uint8Array): "jpg" | "png" | "webp" | null {
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "jpg";
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return "png";
  if (
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
  ) return "webp";
  return null;
}

function toBytes(base64: string): Uint8Array {
  return new Uint8Array(Buffer.from(base64.replace(/[\r\n]/g, ""), "base64"));
}

const ALLOWED_MIME: Record<string, "jpg" | "png" | "webp"> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

/** POST — upload/replace the caller's avatar (R2, private). */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as {
    base64?: string;
    mimeType?: string;
  } | null;
  const mimeType = (body?.mimeType ?? "").toLowerCase();
  if (!ALLOWED_MIME[mimeType]) {
    return NextResponse.json({ error: "Only JPEG / PNG / WebP images are accepted" }, { status: 400 });
  }
  if (!body?.base64 || !/^[A-Za-z0-9+/=\r\n]+$/.test(body.base64)) {
    return NextResponse.json({ error: "Invalid upload body" }, { status: 400 });
  }
  const bytes = toBytes(body.base64);
  if (bytes.byteLength > appConfig.limits.maxAvatarBytes) {
    return NextResponse.json({ error: "Avatar exceeds the 2 MB limit" }, { status: 413 });
  }
  const sig = imageKind(bytes);
  if (!sig) {
    return NextResponse.json({ error: "File content is not a valid image" }, { status: 400 });
  }

  const oldKey = (await db.select({ k: users.avatarKey }).from(users).where(eq(users.id, me.id)).limit(1))[0]?.k;
  const ext = ALLOWED_MIME[mimeType];
  const key = mediaKeys.avatar(me.id, ext);

  const stored = appConfig.storage.r2Enabled ? await storeObject(key, bytes, mimeType) : null;
  if (!stored) {
    return NextResponse.json({ error: "Avatar storage is not configured on this deployment" }, { status: 503 });
  }

  await db.update(users).set({ avatarKey: stored.storageKey }).where(eq(users.id, me.id));

  // Cleanup: delete the replaced object when the extension changed.
  if (oldKey && oldKey !== stored.storageKey) {
    await deleteObject(oldKey).catch(() => {});
  }
  return NextResponse.json({ ok: true, avatar_url: `/api/users/${me.id}/avatar` });
}

/** DELETE — remove the caller's avatar and revert to the initials avatar. */
export async function DELETE() {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [row] = await db.select().from(users).where(eq(users.id, me.id)).limit(1);
  if (!row?.avatarKey) return NextResponse.json({ ok: true, removed: false });

  if (appConfig.storage.r2Enabled) await deleteObject(row.avatarKey).catch(() => {});
  await db.update(users).set({ avatarKey: null }).where(eq(users.id, me.id));
  return NextResponse.json({ ok: true, removed: true });
}

export const runtime = "nodejs";
