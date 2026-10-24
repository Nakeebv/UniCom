import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { fcmStatus, sendPushToUser } from "@/lib/fcm";
import { RULES, enforce } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

/** GET — reports whether FCM is configured (no secrets, no tokens). */
export async function GET() {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  return NextResponse.json(await fcmStatus(me.id));
}

/** POST — sends a test push to the caller's OWN registered devices only. */
export async function POST() {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const limited = enforce(RULES.report, `fcmtest:${me.id}`);
  if (limited) return limited;

  const result = await sendPushToUser(me.id, {
    title: "UniCom test",
    body: "This is a test notification from your own account.",
    channelId: "unicom_messages",
    data: { type: "test" },
  });
  return NextResponse.json({
    configured: result.configured,
    sent: result.sent,
    failed: result.failed,
  });
}

export const runtime = "nodejs";
