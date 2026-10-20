import { NextResponse } from "next/server";
import { and, eq, inArray, isNull, ne } from "drizzle-orm";
import { db } from "@/db";
import { conversationMembers, messageReceipts, messages } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { isMember } from "@/lib/serialize";

type Params = { params: Promise<{ id: string }> };

/** Mark everything in the conversation read for the caller. */
export async function POST(_request: Request, { params }: Params) {
  const { id: conversationId } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  if (!(await isMember(conversationId, me.id))) return NextResponse.json({ error: "forbidden" }, { status: 403 });

  const incoming = await db
    .select({ id: messages.id })
    .from(messages)
    .where(and(eq(messages.conversationId, conversationId), ne(messages.senderId, me.id)))
    .limit(500);

  if (incoming.length > 0) {
    await db
      .update(messageReceipts)
      .set({ readAt: new Date(), deliveredAt: new Date() })
      .where(
        and(
          inArray(messageReceipts.messageId, incoming.map((m) => m.id)),
          eq(messageReceipts.userId, me.id),
          isNull(messageReceipts.readAt),
        ),
      );
  }

  await db
    .update(conversationMembers)
    .set({ lastReadAt: new Date() })
    .where(
      and(eq(conversationMembers.conversationId, conversationId), eq(conversationMembers.userId, me.id)),
    );

  return NextResponse.json({ ok: true });
}
