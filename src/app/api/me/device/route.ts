import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { deviceTokens } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";

export const dynamic = "force-dynamic";

/**
 * Registers (or refreshes) the caller's FCM device token. Authenticated: the
 * token is bound to the session user only — never to a client-supplied id.
 */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as {
    token?: string;
    platform?: string;
  } | null;
  const token = (body?.token ?? "").trim();
  const platform = (body?.platform ?? "android").trim().slice(0, 12);
  if (token.length < 20 || token.length > 4096) {
    return NextResponse.json({ error: "Invalid device token" }, { status: 400 });
  }

  // Upsert: one row per token, always owned by the current session user so a
  // token can never be reassigned to another account silently.
  const existing = await db
    .select({ token: deviceTokens.token })
    .from(deviceTokens)
    .where(eq(deviceTokens.token, token))
    .limit(1);
  if (existing.length > 0) {
    await db
      .update(deviceTokens)
      .set({ userId: me.id, platform, updatedAt: new Date() })
      .where(eq(deviceTokens.token, token));
  } else {
    await db.insert(deviceTokens).values({ token, userId: me.id, platform });
  }
  return NextResponse.json({ ok: true });
}

export const runtime = "nodejs";
