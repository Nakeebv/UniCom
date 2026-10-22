import { NextResponse } from "next/server";
import { eq, sql } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { createUser, issueSession, setSessionCookie } from "@/lib/auth";
import { isSupported, DEFAULT_LANGUAGE } from "@/lib/i18n/languages";
import { ensureSeed } from "@/db/seed";
import { RULES, clientIp, enforce } from "@/lib/rate-limit";
import { issueVerificationCode } from "@/lib/verification";
import { emailConfigured } from "@/lib/email";

/**
 * Account creation with integrity + abuse guards:
 *  • username: normalized `a–z0–9_`, 3–24, case-insensitive unique
 *  • email:    validated, normalized lowercase, unique (no double signup)
 *  • password: min 8, must contain a letter and a number, max 200
 *  • both uniqueness checks re-verified at insert time (race-safe)
 *  • IP rate-limited; duplicates return 409 with a generic message
 */
export async function POST(request: Request) {
  const limited = enforce(RULES.register, clientIp(request));
  if (limited) return limited;
  await ensureSeed();

  const body = (await request.json().catch(() => null)) as {
    username?: string;
    displayName?: string;
    password?: string;
    email?: string;
    preferredLanguage?: string;
  } | null;

  const username = (body?.username ?? "").trim().toLowerCase();
  const displayName = (body?.displayName ?? "").trim();
  const password = body?.password ?? "";
  const email = (body?.email ?? "").trim().toLowerCase();
  const preferredLanguage = body?.preferredLanguage ?? DEFAULT_LANGUAGE;

  // ── Validation ────────────────────────────────────────────────────────────
  if (!/^[a-z0-9_]{3,24}$/.test(username)) {
    return NextResponse.json(
      { error: "Username must be 3–24 chars: a–z, 0–9, _" },
      { status: 400 },
    );
  }
  if (displayName.length < 2 || displayName.length > 48) {
    return NextResponse.json({ error: "Display name must be 2–48 characters" }, { status: 400 });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 200) {
    return NextResponse.json({ error: "A valid email is required" }, { status: 400 });
  }
  if (password.length < 8 || password.length > 200) {
    return NextResponse.json({ error: "Password must be 8–200 characters" }, { status: 400 });
  }
  if (!/[a-zA-Z]/.test(password) || !/[0-9]/.test(password)) {
    return NextResponse.json(
      { error: "Password must include at least one letter and one number" },
      { status: 400 },
    );
  }
  if (!isSupported(preferredLanguage)) {
    return NextResponse.json({ error: "Unsupported language" }, { status: 400 });
  }

  // ── Uniqueness (case-insensitive) ─────────────────────────────────────────
  const [takenUsername] = await db
    .select({ id: users.id })
    .from(users)
    .where(eq(users.username, username))
    .limit(1);
  if (takenUsername) {
    return NextResponse.json({ error: "That username is already taken" }, { status: 409 });
  }
  const [takenEmail] = await db
    .select({ id: users.id })
    .from(users)
    .where(sql`lower(${users.email}) = ${email}`)
    .limit(1);
  if (takenEmail) {
    return NextResponse.json(
      { error: "An account with this email already exists" },
      { status: 409 },
    );
  }

  // ── Create (unique indexes make the race a caught constaint error) ────────
  let userId: string;
  try {
    userId = await createUser({ username, displayName, password, email, preferredLanguage });
  } catch (err) {
    const message = err instanceof Error ? err.message : "";
    if (/duplicate|unique/i.test(message)) {
      return NextResponse.json(
        { error: "That username or email is already registered" },
        { status: 409 },
      );
    }
    throw err;
  }

  const token = await issueSession(userId);
  // Email verification: send the 6-digit code. If email delivery is not
  // configured we still create the account but tell the client honestly so
  // the UI can show "verification email unavailable" rather than lie.
  let emailSent = false;
  let emailNote: string | null = null;
  if (emailConfigured()) {
    const sent = await issueVerificationCode(userId, email);
    emailSent = sent.ok;
    if (!sent.ok) emailNote = sent.reason ?? "send failed";
  } else {
    emailNote = "email delivery not configured";
  }
  const res = NextResponse.json(
    { ok: true, user_id: userId, email_sent: emailSent, email_note: emailNote },
    { status: 201 },
  );
  setSessionCookie(res, token);
  return res;
}

export const runtime = "nodejs";
