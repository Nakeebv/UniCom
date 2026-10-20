import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { conversationMembers, conversations, userBlocks, users } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { newId } from "@/lib/ids";
import { getConversationSummaries } from "@/lib/serialize";
import { ensureSeed } from "@/db/seed";

export const dynamic = "force-dynamic";

export async function GET() {
  await ensureSeed();
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const list = await getConversationSummaries(me.id, me.preferredLanguage);
  return NextResponse.json({ conversations: list });
}

export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as {
    memberIds?: string[];
    title?: string;
  } | null;
  const memberIds = [...new Set((body?.memberIds ?? []).filter((x) => typeof x === "string"))].filter(
    (id) => id !== me.id,
  );
  if (memberIds.length === 0) {
    return NextResponse.json({ error: "Select at least one member" }, { status: 400 });
  }

  // Verify every member exists.
  for (const id of memberIds) {
    const [u] = await db.select({ id: users.id }).from(users).where(eq(users.id, id)).limit(1);
    if (!u) return NextResponse.json({ error: "Unknown member" }, { status: 400 });
  }

  // Blocking either way prevents new direct conversations.
  const blockRows = await db.select().from(userBlocks);
  const blocked = blockRows.some(
    (b) =>
      (b.blockerId === me.id && memberIds.includes(b.blockedId)) ||
      (memberIds.includes(b.blockerId) && b.blockedId === me.id),
  );
  if (blocked && memberIds.length === 1) {
    return NextResponse.json({ error: "You cannot start a conversation with this user" }, { status: 403 });
  }

  const isDirect = memberIds.length === 1;

  // Direct de-dup: reuse the existing 1:1 room.
  if (isDirect) {
    const myDirects = await db
      .select({ conversationId: conversationMembers.conversationId })
      .from(conversationMembers)
      .innerJoin(conversations, eq(conversations.id, conversationMembers.conversationId))
      .where(and(eq(conversationMembers.userId, me.id), eq(conversations.type, "direct")));
    for (const row of myDirects) {
      const members = await db
        .select()
        .from(conversationMembers)
        .where(eq(conversationMembers.conversationId, row.conversationId));
      const set = new Set(members.map((m) => m.userId));
      if (set.size === 2 && set.has(memberIds[0])) {
        return NextResponse.json({ conversation_id: row.conversationId, existing: true });
      }
    }
  }

  const id = newId("conv");
  await db.insert(conversations).values({
    id,
    type: isDirect ? "direct" : "group",
    title: isDirect ? null : (body?.title ?? "").trim().slice(0, 60) || "Group conversation",
    createdBy: me.id,
  });
  await db.insert(conversationMembers).values(
    [me.id, ...memberIds].map((userId) => ({
      conversationId: id,
      userId,
      role: userId === me.id ? "admin" : "member",
    })),
  );

  return NextResponse.json({ conversation_id: id, existing: false }, { status: 201 });
}
