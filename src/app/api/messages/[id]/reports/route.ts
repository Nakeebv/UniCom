import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { messages, reports } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { newId } from "@/lib/ids";
import { isMember } from "@/lib/serialize";

type Params = { params: Promise<{ id: string }> };

export async function POST(request: Request, { params }: Params) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [msg] = await db.select().from(messages).where(eq(messages.id, id)).limit(1);
  if (!msg) return NextResponse.json({ error: "not found" }, { status: 404 });
  if (!(await isMember(msg.conversationId, me.id))) return NextResponse.json({ error: "forbidden" }, { status: 403 });
  if (msg.senderId === me.id) return NextResponse.json({ error: "You cannot report your own message" }, { status: 400 });

  const body = (await request.json().catch(() => null)) as { reason?: string } | null;
  const reason = (body?.reason ?? "").trim().slice(0, 500) || "Abuse report";

  await db.insert(reports).values({
    id: newId("rpt"),
    reporterId: me.id,
    messageId: msg.id,
    targetUserId: msg.senderId,
    reason,
  });
  return NextResponse.json({ ok: true, status: "open" }, { status: 201 });
}
