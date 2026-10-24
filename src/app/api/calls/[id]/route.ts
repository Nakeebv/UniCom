import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { calls } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";

export const dynamic = "force-dynamic";

/** Authoritative call status — polled by both clients. Returns 404 for
 *  anyone who is not a participant (no room/password leakage). */
export async function GET(_r: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [call] = await db.select().from(calls).where(eq(calls.id, id)).limit(1);
  if (!call) return NextResponse.json({ error: "not found" }, { status: 404 });
  if (call.callerId !== me.id && call.calleeId !== me.id) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }

  return NextResponse.json({
    call_id: call.id,
    status: call.status,
    call_type: call.callType,
    room: call.room,
    caller_id: call.callerId,
    callee_id: call.calleeId,
  });
}

export const runtime = "nodejs";
