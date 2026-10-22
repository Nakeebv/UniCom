import { NextResponse } from "next/server";
import { eq, sql } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { RULES, clientIp, enforce } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

/**
 * Public availability probe used by the signup form (debounced).
 * Returns ONLY booleans — never which account exists, no PII. Rate-limited
 * per IP so it cannot be used to enumerate accounts at speed.
 */
export async function GET(request: Request) {
  const limited = enforce(RULES.search, `check:${clientIp(request)}`);
  if (limited) return limited;

  const { searchParams } = new URL(request.url);
  const username = (searchParams.get("username") ?? "").trim().toLowerCase();
  const email = (searchParams.get("email") ?? "").trim().toLowerCase();

  const result: { username_ok?: boolean; email_ok?: boolean } = {};

  if (username) {
    const valid = /^[a-z0-9_]{3,24}$/.test(username);
    if (valid) {
      const [row] = await db
        .select({ id: users.id })
        .from(users)
        .where(eq(users.username, username))
        .limit(1);
      result.username_ok = !row;
    } else {
      result.username_ok = false;
    }
  }

  if (email) {
    const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    if (valid) {
      const [row] = await db
        .select({ id: users.id })
        .from(users)
        .where(sql`lower(${users.email}) = ${email}`)
        .limit(1);
      result.email_ok = !row;
    } else {
      result.email_ok = false;
    }
  }

  return NextResponse.json(result, { headers: { "cache-control": "no-store" } });
}

export const runtime = "nodejs";
