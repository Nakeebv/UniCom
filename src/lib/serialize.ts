import { and, asc, desc, eq, gt, inArray, isNull, ne, or, type SQL } from "drizzle-orm";
import { db } from "@/db";
import {
  conversationMembers,
  conversations,
  mediaAssets,
  messageContents,
  messageReceipts,
  messages,
  messageTranslations,
  userBlocks,
  userPreferences,
  users,
  voiceJobs,
} from "@/db/schema";

const ONLINE_WINDOW_MS = 30_000;

export type PublicUser = {
  id: string;
  username: string;
  displayName: string;
  avatarHue: number;
  preferredLanguage: string;
  online: boolean;
  lastSeenAt: string | null;
};

function toPublicUser(u: {
  id: string;
  username: string;
  displayName: string;
  avatarHue: number;
  lastSeenAt: Date | null;
  preferredLanguage?: string | null;
}): PublicUser {
  return {
    id: u.id,
    username: u.username,
    displayName: u.displayName,
    avatarHue: u.avatarHue,
    preferredLanguage: u.preferredLanguage ?? "en",
    online: !!u.lastSeenAt && Date.now() - u.lastSeenAt.getTime() < ONLINE_WINDOW_MS,
    lastSeenAt: u.lastSeenAt ? u.lastSeenAt.toISOString() : null,
  };
}

export async function loadPublicUsers(ids: string[]): Promise<Map<string, PublicUser>> {
  if (ids.length === 0) return new Map();
  const rows = await db
    .select({
      id: users.id,
      username: users.username,
      displayName: users.displayName,
      avatarHue: users.avatarHue,
      lastSeenAt: users.lastSeenAt,
      preferredLanguage: userPreferences.preferredLanguage,
    })
    .from(users)
    .leftJoin(userPreferences, eq(userPreferences.userId, users.id))
    .where(inArray(users.id, ids));
  return new Map(rows.map((r) => [r.id, toPublicUser(r)]));
}

export async function isMember(conversationId: string, userId: string): Promise<boolean> {
  const [row] = await db
    .select({ userId: conversationMembers.userId })
    .from(conversationMembers)
    .where(
      and(eq(conversationMembers.conversationId, conversationId), eq(conversationMembers.userId, userId)),
    )
    .limit(1);
  return !!row;
}

type MessageRow = typeof messages.$inferSelect;

export type MessageView = {
  id: string;
  conversationId: string;
  senderId: string;
  type: string;
  sourceLanguage: string;
  clientId: string | null;
  version: number;
  createdAt: string;
  editedAt: string | null;
  deleted: boolean;
  originalText: string | null;
  sender: { id: string; displayName: string; username: string; avatarHue: number };
  viewer: {
    language: string;
    sameAsSource: boolean;
    translation: {
      status: string;
      text: string | null;
      provider: string | null;
      targetLanguage: string;
      updatedAt: string;
      sourceVersion: number;
    } | null;
    voiceJob: { status: string; detail: string | null } | null;
  };
  media: { id: string; mimeType: string; sizeBytes: number; durationMs: number | null } | null;
  receipts: { total: number; delivered: number; read: number; lastReadAt: string | null };
};

export async function hydrateMessages(msgRows: MessageRow[], viewerLanguage: string): Promise<MessageView[]> {
  if (msgRows.length === 0) return [];
  const ids = msgRows.map((m) => m.id);

  const [contents, translations, jobs, receipts, media, senders] = await Promise.all([
    db.select().from(messageContents).where(inArray(messageContents.messageId, ids)),
    db.select().from(messageTranslations).where(inArray(messageTranslations.messageId, ids)),
    db.select().from(voiceJobs).where(inArray(voiceJobs.messageId, ids)),
    db.select().from(messageReceipts).where(inArray(messageReceipts.messageId, ids)),
    db
      .select({
        id: mediaAssets.id,
        mimeType: mediaAssets.mimeType,
        sizeBytes: mediaAssets.sizeBytes,
        durationMs: mediaAssets.durationMs,
      })
      .from(mediaAssets)
      .where(
        inArray(
          mediaAssets.id,
          msgRows.map((m) => m.mediaAssetId).filter((x): x is string => !!x).length
            ? msgRows.map((m) => m.mediaAssetId).filter((x): x is string => !!x)
            : ["__none__"],
        ),
      ),
    loadPublicUsers([...new Set(msgRows.map((m) => m.senderId))]),
  ]);

  const contentMap = new Map(contents.map((c) => [c.messageId, c.originalText]));
  const mediaMap = new Map(media.map((m) => [m.id, m]));

  const translationsByMsg = new Map<string, typeof translations>();
  for (const t of translations) {
    const list = translationsByMsg.get(t.messageId) ?? [];
    list.push(t);
    translationsByMsg.set(t.messageId, list);
  }
  const jobsByMsg = new Map<string, typeof jobs>();
  for (const j of jobs) {
    const list = jobsByMsg.get(j.messageId) ?? [];
    list.push(j);
    jobsByMsg.set(j.messageId, list);
  }
  const receiptsByMsg = new Map<string, typeof receipts>();
  for (const r of receipts) {
    const list = receiptsByMsg.get(r.messageId) ?? [];
    list.push(r);
    receiptsByMsg.set(r.messageId, list);
  }

  return msgRows.map((m) => {
    const sender = senders.get(m.senderId);
    const msgTranslations = (translationsByMsg.get(m.id) ?? []).filter(
      (t) => t.targetLanguage === viewerLanguage,
    );
    const exact = msgTranslations.find((t) => t.sourceVersion === m.version) ?? null;
    const latestAny = [...msgTranslations].sort((a, b) => b.sourceVersion - a.sourceVersion)[0] ?? null;
    const chosen = exact ?? latestAny;

    const msgJobs = jobsByMsg.get(m.id) ?? [];
    const job =
      msgJobs.find((j) => j.targetLanguage === viewerLanguage) ??
      msgJobs.find((j) => j.targetLanguage === "*") ??
      msgJobs[0] ??
      null;

    const msgReceipts = (receiptsByMsg.get(m.id) ?? []).filter((r) => r.userId !== m.senderId);
    const readReceipts = msgReceipts.filter((r) => !!r.readAt);
    const lastReadAt = readReceipts
      .map((r) => r.readAt!)
      .sort((a, b) => b.getTime() - a.getTime())[0] ?? null;

    return {
      id: m.id,
      conversationId: m.conversationId,
      senderId: m.senderId,
      type: m.type,
      sourceLanguage: m.sourceLanguage,
      clientId: m.clientId,
      version: m.version,
      createdAt: m.createdAt.toISOString(),
      editedAt: m.editedAt ? m.editedAt.toISOString() : null,
      deleted: !!m.deletedAt,
      originalText: m.deletedAt ? null : (contentMap.get(m.id) ?? null),
      sender: {
        id: m.senderId,
        displayName: sender?.displayName ?? "Unknown",
        username: sender?.username ?? "unknown",
        avatarHue: sender?.avatarHue ?? 220,
      },
      viewer: {
        language: viewerLanguage,
        sameAsSource: viewerLanguage === m.sourceLanguage,
        translation:
          chosen && chosen.targetLanguage === viewerLanguage
            ? {
                status: exact ? chosen.status : "stale",
                text: chosen.translatedText,
                provider: chosen.provider,
                targetLanguage: chosen.targetLanguage,
                updatedAt: chosen.updatedAt.toISOString(),
                sourceVersion: chosen.sourceVersion,
              }
            : null,
        voiceJob: job ? { status: job.status, detail: job.detail } : null,
      },
      media: m.mediaAssetId ? (mediaMap.get(m.mediaAssetId) ?? null) : null,
      receipts: {
        total: msgReceipts.length,
        delivered: msgReceipts.filter((r) => !!r.deliveredAt).length,
        read: readReceipts.length,
        lastReadAt: lastReadAt ? lastReadAt.toISOString() : null,
      },
    };
  });
}

export async function loadRecentMessages(
  conversationId: string,
  viewerLanguage: string,
  limit = 80,
): Promise<MessageView[]> {
  const rows = await db
    .select()
    .from(messages)
    .where(eq(messages.conversationId, conversationId))
    .orderBy(asc(messages.createdAt))
    .limit(limit * 3);
  const recent = rows.slice(-limit);
  return hydrateMessages(recent, viewerLanguage);
}

/** Incremental diff for event sync: created, edited, or translation/job/receipt-updated rows. */
export async function loadChangedMessages(
  conversationId: string,
  viewerLanguage: string,
  since: Date,
): Promise<MessageView[]> {
  const conditions: SQL[] = [
    gt(messages.createdAt, since),
    gt(messages.editedAt, since),
    gt(messages.deletedAt, since),
  ];
  const changedBase = await db
    .select({ id: messages.id })
    .from(messages)
    .where(and(eq(messages.conversationId, conversationId), or(...conditions)))
    .limit(200);

  const ids = new Set(changedBase.map((r) => r.id));

  const convMessages = await db
    .select({ id: messages.id, createdAt: messages.createdAt })
    .from(messages)
    .where(eq(messages.conversationId, conversationId))
    .orderBy(desc(messages.createdAt))
    .limit(120);
  const candidateIds = convMessages.map((m) => m.id);
  if (candidateIds.length > 0) {
    const [tUpdated, jUpdated, rUpdated] = await Promise.all([
      db
        .select({ messageId: messageTranslations.messageId })
        .from(messageTranslations)
        .where(and(inArray(messageTranslations.messageId, candidateIds), gt(messageTranslations.updatedAt, since))),
      db
        .select({ messageId: voiceJobs.messageId })
        .from(voiceJobs)
        .where(and(inArray(voiceJobs.messageId, candidateIds), gt(voiceJobs.updatedAt, since))),
      db
        .select({ messageId: messageReceipts.messageId })
        .from(messageReceipts)
        .where(
          and(
            inArray(messageReceipts.messageId, candidateIds),
            or(gt(messageReceipts.deliveredAt, since), gt(messageReceipts.readAt, since)),
          ),
        ),
    ]);
    for (const r of tUpdated) ids.add(r.messageId);
    for (const r of jUpdated) ids.add(r.messageId);
    for (const r of rUpdated) ids.add(r.messageId);
  }

  if (ids.size === 0) return [];
  const rows = await db
    .select()
    .from(messages)
    .where(inArray(messages.id, [...ids]))
    .orderBy(asc(messages.createdAt));
  return hydrateMessages(rows, viewerLanguage);
}

export type ConversationSummary = {
  id: string;
  type: string;
  title: string | null;
  createdAt: string;
  members: PublicUser[];
  lastMessage: {
    id: string;
    type: string;
    senderId: string;
    preview: string;
    createdAt: string;
    deleted: boolean;
  } | null;
  unreadCount: number;
  blockedPeerId: string | null;
  blockedByPeerId: string | null;
};

export async function getConversationSummaries(
  userId: string,
  viewerLanguage: string,
): Promise<ConversationSummary[]> {
  const memberships = await db
    .select()
    .from(conversationMembers)
    .where(eq(conversationMembers.userId, userId));
  if (memberships.length === 0) return [];

  const convIds = memberships.map((m) => m.conversationId);
  const convRows = await db.select().from(conversations).where(inArray(conversations.id, convIds));
  const allMembers = await db
    .select()
    .from(conversationMembers)
    .where(inArray(conversationMembers.conversationId, convIds));
  const publicUsers = await loadPublicUsers([...new Set(allMembers.map((m) => m.userId))]);
  const myBlocks = await db.select().from(userBlocks).where(eq(userBlocks.blockerId, userId));
  const blocksOfMe = await db.select().from(userBlocks).where(eq(userBlocks.blockedId, userId));
  const myBlockSet = new Set(myBlocks.map((b) => b.blockedId));
  const blockedMeSet = new Set(blocksOfMe.map((b) => b.blockerId));

  const summaries: ConversationSummary[] = [];
  for (const conv of convRows) {
    const members = allMembers
      .filter((m) => m.conversationId === conv.id)
      .map((m) => publicUsers.get(m.userId))
      .filter((u): u is PublicUser => !!u);
    const me = memberships.find((m) => m.conversationId === conv.id);

    const lastRows = await db
      .select()
      .from(messages)
      .where(eq(messages.conversationId, conv.id))
      .orderBy(desc(messages.createdAt))
      .limit(1);
    const last = lastRows[0] ?? null;

    let lastView: ConversationSummary["lastMessage"] = null;
    if (last) {
      const [content] = await db
        .select()
        .from(messageContents)
        .where(eq(messageContents.messageId, last.id))
        .limit(1);
      const [translated] = await db
        .select()
        .from(messageTranslations)
        .where(
          and(
            eq(messageTranslations.messageId, last.id),
            eq(messageTranslations.targetLanguage, viewerLanguage),
            eq(messageTranslations.status, "completed"),
          ),
        )
        .limit(1);
      const raw = last.deletedAt
        ? "Message deleted"
        : (translated?.translatedText ?? content?.originalText ?? (last.type === "voice" ? "Voice note" : ""));
      lastView = {
        id: last.id,
        type: last.type,
        senderId: last.senderId,
        preview: raw.length > 90 ? `${raw.slice(0, 90)}…` : raw,
        createdAt: last.createdAt.toISOString(),
        deleted: !!last.deletedAt,
      };
    }

    const unreadBase: SQL = and(
      eq(messages.conversationId, conv.id),
      ne(messages.senderId, userId),
      isNull(messages.deletedAt),
      me?.lastReadAt ? gt(messages.createdAt, me.lastReadAt) : gt(messages.createdAt, new Date(0)),
    )!;
    const unreadRows = await db.select({ id: messages.id }).from(messages).where(unreadBase).limit(500);
    const unread = unreadRows.length;

    const peer = conv.type === "direct" ? members.find((m) => m.id !== userId) : undefined;
    summaries.push({
      id: conv.id,
      type: conv.type,
      title: conv.title,
      createdAt: conv.createdAt.toISOString(),
      members,
      lastMessage: lastView,
      unreadCount: unread,
      blockedPeerId: peer && myBlockSet.has(peer.id) ? peer.id : null,
      blockedByPeerId: peer && blockedMeSet.has(peer.id) ? peer.id : null,
    });
  }

  summaries.sort((a, b) => {
    const at = a.lastMessage?.createdAt ?? a.createdAt;
    const bt = b.lastMessage?.createdAt ?? b.createdAt;
    return bt.localeCompare(at);
  });
  return summaries;
}
