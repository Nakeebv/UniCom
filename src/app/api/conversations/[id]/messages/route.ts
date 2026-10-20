import { NextResponse } from "next/server";
import { and, eq, ne } from "drizzle-orm";
import { db } from "@/db";
import {
  conversationMembers,
  conversations,
  mediaAssets,
  messageContents,
  messageReceipts,
  messages,
  outboxEvents,
  userBlocks,
} from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { newId } from "@/lib/ids";
import { isSupported } from "@/lib/i18n/languages";
import {
  enqueueTranslationsForMessage,
  enqueueVoiceJobs,
  ensureTranslationForReader,
  markOutboxPublished,
  planTargetLanguages,
} from "@/lib/queue";
import { isMember, loadRecentMessages } from "@/lib/serialize";

export const dynamic = "force-dynamic";

type Params = { params: Promise<{ id: string }> };

export async function GET(_request: Request, { params }: Params) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  if (!(await isMember(id, me.id))) return NextResponse.json({ error: "forbidden" }, { status: 403 });

  const views = await loadRecentMessages(id, me.preferredLanguage, 80);

  // Lazy, on-demand translation for messages the reader's language needs.
  await Promise.all(
    views
      .filter((v) => !v.deleted && !v.viewer.sameAsSource && !v.viewer.translation && !!v.originalText)
      .slice(0, 25)
      .map((v) => ensureTranslationForReader(v.id, me.preferredLanguage).catch(() => {})),
  );

  return NextResponse.json({ messages: views, now: new Date().toISOString() });
}

export async function POST(request: Request, { params }: Params) {
  const { id: conversationId } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  if (!(await isMember(conversationId, me.id))) return NextResponse.json({ error: "forbidden" }, { status: 403 });

  const body = (await request.json().catch(() => null)) as {
    type?: string;
    text?: string;
    mediaAssetId?: string;
    sourceLanguage?: string;
    clientId?: string;
  } | null;

  const type = body?.type === "voice" ? "voice" : "text";
  const text = (body?.text ?? "").trim();
  const clientId =
    (body?.clientId ?? request.headers.get("Idempotency-Key") ?? "").trim().slice(0, 80) || null;
  const sourceLanguage = body?.sourceLanguage && isSupported(body.sourceLanguage) ? body.sourceLanguage : me.preferredLanguage;

  if (type === "text" && (text.length < 1 || text.length > 4000)) {
    return NextResponse.json({ error: "Message text must be 1–4000 characters" }, { status: 400 });
  }
  if (type === "voice") {
    const mediaAssetId = body?.mediaAssetId ?? "";
    const [asset] = await db.select().from(mediaAssets).where(eq(mediaAssets.id, mediaAssetId)).limit(1);
    if (!asset || asset.ownerId !== me.id) {
      return NextResponse.json({ error: "Unknown or unauthorized media asset" }, { status: 400 });
    }
  }

  // Blocked relationships cannot exchange messages in direct conversations.
  const [conv] = await db.select().from(conversations).where(eq(conversations.id, conversationId)).limit(1);
  if (!conv) return NextResponse.json({ error: "not found" }, { status: 404 });
  if (conv.type === "direct") {
    const members = await db
      .select()
      .from(conversationMembers)
      .where(eq(conversationMembers.conversationId, conversationId));
    const peer = members.find((m) => m.userId !== me.id);
    if (peer) {
      const blockRows = await db
        .select()
        .from(userBlocks)
        .where(ne(userBlocks.blockerId, userBlocks.blockedId)); // all rows — small table
      const blocked = blockRows.some(
        (b) =>
          (b.blockerId === me.id && b.blockedId === peer.userId) ||
          (b.blockerId === peer.userId && b.blockedId === me.id),
      );
      if (blocked) {
        return NextResponse.json({ error: "Messaging is disabled between these accounts" }, { status: 403 });
      }
    }
  }

  // Idempotent submission: same (sender, clientId) returns the original record.
  if (clientId) {
    const [dup] = await db
      .select()
      .from(messages)
      .where(and(eq(messages.senderId, me.id), eq(messages.clientId, clientId)))
      .limit(1);
    if (dup) {
      return NextResponse.json({ message_id: dup.id, status: "duplicate", original_language: dup.sourceLanguage });
    }
  }

  const targets = await planTargetLanguages(conversationId, sourceLanguage);

  /* Commit message + outbox event + receipts atomically. */
  const messageId = newId("msg");
  const outboxId = newId("evt");
  await db.transaction(async (tx) => {
    await tx.insert(messages).values({
      id: messageId,
      conversationId,
      senderId: me.id,
      type,
      sourceLanguage,
      clientId,
      mediaAssetId: type === "voice" ? body?.mediaAssetId ?? null : null,
    });
    if (text) {
      await tx.insert(messageContents).values({ messageId, originalText: text });
    } else if (type === "voice") {
      await tx.insert(messageContents).values({ messageId, originalText: "" });
    }

    const members = await tx
      .select()
      .from(conversationMembers)
      .where(eq(conversationMembers.conversationId, conversationId));
    for (const member of members) {
      await tx.insert(messageReceipts).values({
        messageId,
        userId: member.userId,
        deliveredAt: member.userId === me.id ? new Date() : null,
        readAt: member.userId === me.id ? new Date() : null,
      });
    }

    await tx.insert(outboxEvents).values({
      id: outboxId,
      eventType: type === "voice" ? "voice.accepted" : "message.created",
      payload: { message_id: messageId, conversation_id: conversationId, sender_id: me.id, type, source_language: sourceLanguage },
    });
  });

  await markOutboxPublished(outboxId);
  if (type === "voice") {
    await enqueueVoiceJobs(messageId);
  } else {
    await enqueueTranslationsForMessage(messageId);
  }

  return NextResponse.json(
    {
      message_id: messageId,
      status: "accepted",
      original_language: sourceLanguage,
      translations: targets.map((language) => ({ language, status: "queued" })),
    },
    { status: 201 },
  );
}
