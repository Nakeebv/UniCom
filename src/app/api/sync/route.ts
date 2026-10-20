import { NextResponse } from "next/server";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "@/db";
import { messageReceipts, users } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import {
  getConversationSummaries,
  isMember,
  loadChangedMessages,
  loadRecentMessages,
} from "@/lib/serialize";
import { getTypers } from "@/lib/typing";
import { ensureSeed } from "@/db/seed";

export const dynamic = "force-dynamic";

/**
 * Event-sync endpoint. WebSockets are the production transport; the single-
 * process web tier uses lightweight polling against the same authoritative
 * state, with a `since` cursor so reconnecting clients only fetch the delta.
 */
export async function GET(request: Request) {
  await ensureSeed();
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { searchParams } = new URL(request.url);
  const conversationId = searchParams.get("conversationId") || null;
  const sinceParam = searchParams.get("since");
  const since = sinceParam && !Number.isNaN(Date.parse(sinceParam)) ? new Date(sinceParam) : null;

  // Presence heartbeat.
  await db.update(users).set({ lastSeenAt: new Date() }).where(eq(users.id, me.id));

  // Mark everything addressed to this device as delivered (single queue, idempotent).
  await db
    .update(messageReceipts)
    .set({ deliveredAt: new Date() })
    .where(and(eq(messageReceipts.userId, me.id), isNull(messageReceipts.deliveredAt)));

  const conversations = await getConversationSummaries(me.id, me.preferredLanguage);

  let changed: Awaited<ReturnType<typeof loadChangedMessages>> = [];
  let full: Awaited<ReturnType<typeof loadRecentMessages>> | null = null;
  let typers: string[] = [];
  if (conversationId && (await isMember(conversationId, me.id))) {
    if (since) {
      changed = await loadChangedMessages(conversationId, me.preferredLanguage, since);
    } else {
      full = await loadRecentMessages(conversationId, me.preferredLanguage, 80);
    }
    typers = getTypers(conversationId, me.id);
  }

  return NextResponse.json({
    now: new Date().toISOString(),
    conversations,
    messages: changed.length > 0 ? changed : undefined,
    initial: full ?? undefined,
    typers,
  });
}
