import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { issueSession, setSessionCookie, verifyPassword } from "@/lib/auth";
import { ensureSeed } from "@/db/seed";
import { RULES, clientIp, enforce } from "@/lib/rate-limit";

export async function POST(request: Request) {
  const limited = enforce(RULES.login, clientIp(request));
  if (limited) return limited;
  await ensureSeed();
  const body = (await request.json().catch(() => null)) as { username?: string; password?: string } | null;
  const username = (body?.username ?? "").trim().toLowerCase();
  const password = body?.password ?? "";

  const [user] = await db.select().from(users).where(eq(users.username, username)).limit(1);
  if (!user || !verifyPassword(password, user.passwordHash)) {
    return NextResponse.json({ error: "Invalid username or password" }, { status: 401 });
  }

  const token = await issueSession(user.id);
  const res = NextResponse.json({ ok: true, user_id: user.id });
  setSessionCookie(res, token);
  return res;
}
