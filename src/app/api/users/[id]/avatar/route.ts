import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { presignGetUrl } from "@/lib/storage";

/**
 * Serves another user's avatar to the signed-in viewer: 302 → short-lived
 * presigned R2 URL (or 404 → client falls back to hue/initials avatar).
 */
export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [user] = await db.select().from(users).where(eq(users.id, id)).limit(1);
  if (!user?.avatarKey) return NextResponse.json({ error: "not found" }, { status: 404 });

  const url = await presignGetUrl(user.avatarKey, 600);
  return NextResponse.redirect(url, { status: 302 });
}

export const runtime = "nodejs";
