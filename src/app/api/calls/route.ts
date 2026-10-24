import { NextResponse } from "next/server";
import { and, desc, eq, lt, ne, or } from "drizzle-orm";
import { db } from "@/db";
import { calls, conversationMembers, userBlocks } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { newId } from "@/lib/ids";
import { publish } from "@/lib/realtime";
import { sendPushToUser } from "@/lib/fcm";
import { RULES, enforce } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

const RING_TTL_MS = 45_000;

/** Creates a ringing call invitation and notifies the callee over SSE. */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const limited = enforce(RULES.callToken, me.id);
  if (limited) return limited;

  const body = (await request.json().catch(() => null)) as {
    calleeId?: string;
    callType?: "audio" | "video";
  } | null;
  const calleeId = (body?.calleeId ?? "").trim();
  const callType = body?.callType === "video" ? "video" : "audio";
  if (!calleeId || calleeId === me.id) {
    return NextResponse.json({ error: "Invalid callee" }, { status: 400 });
  }

  // Authorization: share a conversation with the callee, and not be blocked.
  const myConvs = await db
    .select({ cid: conversationMembers.conversationId })
    .from(conversationMembers)
    .where(eq(conversationMembers.userId, me.id));
  let sharedConv: string | null = null;
  for (const c of myConvs) {
    const [peer] = await db
      .select({ userId: conversationMembers.userId })
      .from(conversationMembers)
      .where(and(eq(conversationMembers.conversationId, c.cid), eq(conversationMembers.userId, calleeId)))
      .limit(1);
    if (peer) {
      sharedConv = c.cid;
      break;
    }
  }
  if (!sharedConv) return NextResponse.json({ error: "forbidden" }, { status: 403 });

  const blocks = await db
    .select()
    .from(userBlocks)
    .where(
      or(
        and(eq(userBlocks.blockerId, me.id), eq(userBlocks.blockedId, calleeId)),
        and(eq(userBlocks.blockerId, calleeId), eq(userBlocks.blockedId, me.id)),
      ),
    );
  if (blocks.length > 0) {
    return NextResponse.json({ error: "Messaging is disabled between these accounts" }, { status: 403 });
  }

  // Supersede any still-ringing calls between exactly this pair (never
  // touch other people's incoming calls).
  await db
    .update(calls)
    .set({ status: "cancelled", endedAt: new Date() })
    .where(
      and(
        eq(calls.status, "ringing"),
        or(
          and(eq(calls.callerId, me.id), eq(calls.calleeId, calleeId)),
          and(eq(calls.callerId, calleeId), eq(calls.calleeId, me.id)),
        ),
      ),
    );

  const id = newId("call");
  const room = id; // id already carries the call_ prefix
  await db.insert(calls).values({
    id,
    callerId: me.id,
    calleeId,
    callType,
    room,
    status: "ringing",
    expiresAt: new Date(Date.now() + RING_TTL_MS),
  });
  publish({
    kind: "call",
    conversationId: sharedConv ?? "",
    callId: id,
    status: "ringing",
    participants: [me.id, calleeId],
  } as never);

  // Push the callee so they ring even outside the app (best-effort; no-op
  // when FCM is unconfigured — never claimed as delivered).
  void sendPushToUser(calleeId, {
    title: callType === "video" ? "Incoming video call" : "Incoming voice call",
    body: `${me.displayName} is calling…`,
    channelId: "unicom_calls",
    highPriority: true,
    data: {
      type: "call",
      call_id: id,
      caller_id: me.id,
      call_type: callType,
      room,
    },
  }).catch(() => {});

  return NextResponse.json({ call_id: id, room, call_type: callType }, { status: 201 });
}

/** Poll/inspect the current call for the user (incoming or active). */
export async function GET() {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  // Sweep: expired rings are 'missed' so stale overlays can't resurrect.
  await db
    .update(calls)
    .set({ status: "missed", endedAt: new Date() })
    .where(and(eq(calls.status, "ringing"), lt(calls.expiresAt, new Date())));
  const [incoming] = await db
    .select()
    .from(calls)
    .where(and(eq(calls.calleeId, me.id), eq(calls.status, "ringing")))
    .orderBy(desc(calls.createdAt))
    .limit(1);
  const [active] = await db
    .select()
    .from(calls)
    .where(and(eq(calls.status, "accepted"), or(eq(calls.callerId, me.id), eq(calls.calleeId, me.id))))
    .orderBy(desc(calls.answeredAt))
    .limit(1);
  return NextResponse.json({
    incoming: incoming
      ? { call_id: incoming.id, caller_id: incoming.callerId, call_type: incoming.callType, room: incoming.room }
      : null,
    active: active
      ? { call_id: active.id, caller_id: active.callerId, callee_id: active.calleeId, call_type: active.callType, room: active.room }
      : null,
  });
}

export const runtime = "nodejs";
