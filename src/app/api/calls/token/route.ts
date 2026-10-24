import { NextResponse } from "next/server";
import { db } from "@/db";
import { calls } from "@/db/schema";
import { and, eq } from "drizzle-orm";
import { getSessionUser } from "@/lib/auth";
import { livekitConfigured, livekitUrl, mintCallToken } from "@/lib/livekit";
import { RULES, enforce } from "@/lib/rate-limit";

/** Server-minted, room-scoped LiveKit access token (5-min TTL).
 *  Caller must be authenticated AND a participant of this specific call.
 *  Blocking/authorization were enforced at invite time; only ringing or
 *  accepted calls are joinable — arbitrary room ids are rejected. */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const limited = enforce(RULES.callToken, me.id);
  if (limited) return limited;
  if (!livekitConfigured()) {
    return NextResponse.json({ error: "Calling is not configured on this server" }, { status: 503 });
  }
  const body = (await request.json().catch(() => null)) as {
    callId?: string;
  } | null;
  const callId = (body?.callId ?? "").trim();
  if (!callId) {
    return NextResponse.json({ error: "callId is required" }, { status: 400 });
  }

  // Authorization: the caller must be a participant of THIS call, and the
  // call must be in a joinable state (ringing | accepted). This closes the
  // "mint a token for an arbitrary room id" escalation.
  const [call] = await db.select().from(calls).where(eq(calls.id, callId)).limit(1);
  if (!call) return NextResponse.json({ error: "Call not found" }, { status: 404 });
  if (call.callerId !== me.id && call.calleeId !== me.id) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }
  if (call.status !== "ringing" && call.status !== "accepted") {
    return NextResponse.json({ error: "Call is not joinable" }, { status: 409 });
  }

  const identity = me.id;
  const token = mintCallToken({
    room: call.room,
    identity,
    name: me.displayName,
  });
  return NextResponse.json({
    token,
    url: livekitUrl(),
    room: call.room,
    identity,
    call_type: call.callType,
    expires_in: 300,
  });
}

export const runtime = "nodejs";
