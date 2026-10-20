import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { createUser, issueSession, setSessionCookie } from "@/lib/auth";
import { isSupported, DEFAULT_LANGUAGE } from "@/lib/i18n/languages";
import { ensureSeed } from "@/db/seed";

export async function POST(request: Request) {
  await ensureSeed();
  const body = (await request.json().catch(() => null)) as {
    username?: string;
    displayName?: string;
    password?: string;
    preferredLanguage?: string;
  } | null;

  const username = (body?.username ?? "").trim().toLowerCase();
  const displayName = (body?.displayName ?? "").trim();
  const password = body?.password ?? "";
  const preferredLanguage = body?.preferredLanguage ?? DEFAULT_LANGUAGE;

  if (!/^[a-z0-9_]{3,24}$/.test(username)) {
    return NextResponse.json({ error: "Username must be 3–24 chars: a–z, 0–9, _" }, { status: 400 });
  }
  if (displayName.length < 2 || displayName.length > 48) {
    return NextResponse.json({ error: "Display name must be 2–48 characters" }, { status: 400 });
  }
  if (password.length < 8) {
    return NextResponse.json({ error: "Password must be at least 8 characters" }, { status: 400 });
  }
  if (!isSupported(preferredLanguage)) {
    return NextResponse.json({ error: "Unsupported language" }, { status: 400 });
  }

  const [taken] = await db.select({ id: users.id }).from(users).where(eq(users.username, username)).limit(1);
  if (taken) {
    return NextResponse.json({ error: "That username is taken" }, { status: 409 });
  }

  const userId = await createUser({ username, displayName, password, preferredLanguage });
  const token = await issueSession(userId);
  const res = NextResponse.json({ ok: true, user_id: userId }, { status: 201 });
  setSessionCookie(res, token);
  return res;
}
