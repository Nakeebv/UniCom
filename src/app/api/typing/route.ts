import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { isMember } from "@/lib/serialize";
import { recordTyping } from "@/lib/typing";

export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as { conversationId?: string } | null;
  const conversationId = body?.conversationId ?? "";
  if (!conversationId || !(await isMember(conversationId, me.id))) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }
  recordTyping(conversationId, me.id, me.displayName);
  return NextResponse.json({ ok: true });
}
