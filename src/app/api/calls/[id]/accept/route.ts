import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { calls } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { publish } from "@/lib/realtime";

export const dynamic = "force-dynamic";

/** Callee accepts: only from ringing and before expiry. */
export async function POST(_r: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [call] = await db.select().from(calls).where(eq(calls.id, id)).limit(1);
  if (!call) return NextResponse.json({ error: "not found" }, { status: 404 });
  if (call.calleeId !== me.id) return NextResponse.json({ error: "forbidden" }, { status: 403 });
  if (call.status !== "ringing") return NextResponse.json({ error: "Call is not ringing" }, { status: 409 });
  if (call.expiresAt.getTime() < Date.now()) {
    await db.update(calls).set({ status: "missed", endedAt: new Date() }).where(eq(calls.id, id));
    return NextResponse.json({ error: "Call expired" }, { status: 410 });
  }
  await db
    .update(calls)
    .set({ status: "accepted", answeredAt: new Date() })
    .where(and(eq(calls.id, id), eq(calls.status, "ringing")));
  publish({ kind: "call", conversationId: "", callId: id, status: "accepted", participants: [call.callerId, call.calleeId] } as never);
  return NextResponse.json({ ok: true, room: call.room, call_type: call.callType });
}

export const runtime = "nodejs";
