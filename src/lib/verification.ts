import crypto from "crypto";
import { and, desc, eq, isNull } from "drizzle-orm";
import { db } from "@/db";
import { emailVerifications, users } from "@/db/schema";
import { newId } from "@/lib/ids";
import { emailConfigured, sendEmail, verificationEmail } from "@/lib/email";

const CODE_TTL_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS = 6;

function hashCode(userId: string, code: string): string {
  // Codes are short-lived + attempt-bounded; bind to the user id so a code
  // only validates for its own account.
  return crypto.createHash("sha256").update(`${userId}:${code}`).digest("hex");
}

/** Generates + emails a fresh 6-digit code (invalidating older ones). */
export async function issueVerificationCode(userId: string, email: string): Promise<{
  ok: boolean;
  reason?: string;
}> {
  if (!emailConfigured()) {
    return { ok: false, reason: "email delivery is not configured on this server" };
  }
  const code = String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");

  // Invalidate any outstanding codes for this user.
  await db
    .update(emailVerifications)
    .set({ consumedAt: new Date() })
    .where(and(eq(emailVerifications.userId, userId), isNull(emailVerifications.consumedAt)));

  await db.insert(emailVerifications).values({
    id: newId("evf"),
    userId,
    codeHash: hashCode(userId, code),
    expiresAt: new Date(Date.now() + CODE_TTL_MS),
  });

  const body = verificationEmail(code);
  const sent = await sendEmail({ to: email, ...body });
  if (!sent.ok) return { ok: false, reason: sent.reason };
  return { ok: true };
}

export type VerifyResult = "ok" | "invalid" | "expired" | "too_many" | "none";

/** Validates a submitted code and, on success, marks the account verified. */
export async function verifyCode(userId: string, code: string): Promise<VerifyResult> {
  const [row] = await db
    .select()
    .from(emailVerifications)
    .where(and(eq(emailVerifications.userId, userId), isNull(emailVerifications.consumedAt)))
    .orderBy(desc(emailVerifications.createdAt))
    .limit(1);

  if (!row) return "none";
  if (row.expiresAt.getTime() < Date.now()) {
    await db
      .update(emailVerifications)
      .set({ consumedAt: new Date() })
      .where(eq(emailVerifications.id, row.id));
    return "expired";
  }
  if (row.attempts >= MAX_ATTEMPTS) return "too_many";

  const candidate = hashCode(userId, code.trim());
  const expected = row.codeHash;
  const match =
    candidate.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(candidate), Buffer.from(expected));

  if (!match) {
    await db
      .update(emailVerifications)
      .set({ attempts: row.attempts + 1 })
      .where(eq(emailVerifications.id, row.id));
    return "invalid";
  }

  await db.transaction(async (tx) => {
    await tx
      .update(emailVerifications)
      .set({ consumedAt: new Date() })
      .where(eq(emailVerifications.id, row.id));
    await tx.update(users).set({ emailVerifiedAt: new Date() }).where(eq(users.id, userId));
  });
  return "ok";
}
