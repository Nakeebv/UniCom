import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { issueVerificationCode } from "@/lib/verification";
import { RULES, clientIp, enforce } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

/** Issues a fresh verification code for the signed-in user's email. */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const limited = enforce(RULES.register, `resend:${me.id}:${clientIp(request)}`);
  if (limited) return limited;

  const db_user_email = (me as unknown as { email?: string }).email ?? "";
  if (!db_user_email) {
    return NextResponse.json({ error: "No email on file for this account" }, { status: 400 });
  }

  const result = await issueVerificationCode(me.id, db_user_email);
  if (!result.ok) {
    return NextResponse.json(
      { error: "Could not send the code. Email delivery may not be configured yet." },
      { status: 503 },
    );
  }
  return NextResponse.json({ ok: true });
}

export const runtime = "nodejs";
