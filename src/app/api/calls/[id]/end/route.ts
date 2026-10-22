import { NextResponse } from "next/server";
import { eq, or } from "drizzle-orm";
import { db } from "@/db";
import { calls } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { publish } from "@/lib/realtime";

export const dynamic = "force-dynamic";

export async function POST(_r: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const [call] = await db.select().from(calls).where(eq(calls.id, id)).limit(1);
  if (!call) return NextResponse.json({ error: "not found" }, { status: 404 });
  if (call.calleeId !== me.id && call.callerId !== me.id) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }
  await db
    .update(calls)
    .set({ status: "ended", endedAt: new Date() })
    .where(or(eq(calls.id, id), eq(calls.id, id)));
  publish({ kind: "call", conversationId: "", callId: id, status: "ended", participants: [call.callerId, call.calleeId] } as never);
  return NextResponse.json({ ok: true });
}

export const runtime = "nodejs";
