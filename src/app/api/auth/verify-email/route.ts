import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { verifyCode } from "@/lib/verification";
import { RULES, clientIp, enforce } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

/** Confirms the emailed 6-digit code for the signed-in (unverified) user. */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const limited = enforce(RULES.login, `verify:${me.id}:${clientIp(request)}`);
  if (limited) return limited;

  const body = (await request.json().catch(() => null)) as { code?: string } | null;
  const code = (body?.code ?? "").trim();
  if (!/^\d{6}$/.test(code)) {
    return NextResponse.json({ error: "Enter the 6-digit code" }, { status: 400 });
  }

  const result = await verifyCode(me.id, code);
  switch (result) {
    case "ok":
      return NextResponse.json({ ok: true, verified: true });
    case "invalid":
      return NextResponse.json({ error: "That code is incorrect" }, { status: 400 });
    case "expired":
      return NextResponse.json({ error: "That code expired — request a new one" }, { status: 400 });
    case "too_many":
      return NextResponse.json({ error: "Too many attempts — request a new code" }, { status: 429 });
    case "none":
      return NextResponse.json({ error: "No active code — request a new one" }, { status: 400 });
  }
}

export const runtime = "nodejs";
