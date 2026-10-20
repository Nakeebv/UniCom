import {
  pgTable,
  text,
  timestamp,
  integer,
  boolean,
  primaryKey,
  uniqueIndex,
  index,
  jsonb,
} from "drizzle-orm/pg-core";

/* ── Identity ─────────────────────────────────────────────────────────────── */

export const users = pgTable("users", {
  id: text("id").primaryKey(),
  username: text("username").notNull().unique(),
  displayName: text("display_name").notNull(),
  passwordHash: text("password_hash").notNull(),
  avatarHue: integer("avatar_hue").notNull().default(220),
  bio: text("bio"),
  isPersona: boolean("is_persona").notNull().default(false),
  lastSeenAt: timestamp("last_seen_at", { withTimezone: true, mode: "date" }),
  createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
});

export const userPreferences = pgTable("user_preferences", {
  userId: text("user_id")
    .primaryKey()
    .references(() => users.id, { onDelete: "cascade" }),
  preferredLanguage: text("preferred_language").notNull().default("en"),
  speechLanguage: text("speech_language"),
  voiceId: text("voice_id"),
  showOriginal: boolean("show_original").notNull().default(false),
  updatedAt: timestamp("updated_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
});

export const sessions = pgTable(
  "sessions",
  {
    token: text("token").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true, mode: "date" }).notNull(),
  },
  (t) => [index("ix_sessions_user").on(t.userId)],
);

/* ── Conversations ────────────────────────────────────────────────────────── */

export const conversations = pgTable("conversations", {
  id: text("id").primaryKey(),
  type: text("type").notNull().default("direct"), // direct | group
  title: text("title"),
  createdBy: text("created_by").references(() => users.id),
  createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
});

export const conversationMembers = pgTable(
  "conversation_members",
  {
    conversationId: text("conversation_id")
      .notNull()
      .references(() => conversations.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    role: text("role").notNull().default("member"),
    joinedAt: timestamp("joined_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
    lastReadAt: timestamp("last_read_at", { withTimezone: true, mode: "date" }),
  },
  (t) => [
    primaryKey({ columns: [t.conversationId, t.userId] }),
    index("ix_members_user").on(t.userId),
  ],
);

/* ── Messages — the original record is never overwritten by translations ──── */

export const messages = pgTable(
  "messages",
  {
    id: text("id").primaryKey(),
    conversationId: text("conversation_id")
      .notNull()
      .references(() => conversations.id, { onDelete: "cascade" }),
    senderId: text("sender_id")
      .notNull()
      .references(() => users.id),
    type: text("type").notNull().default("text"), // text | voice
    sourceLanguage: text("source_language").notNull(),
    clientId: text("client_id"), // idempotent submission key (Idempotency-Key)
    mediaAssetId: text("media_asset_id").references(() => mediaAssets.id, { onDelete: "set null" }),
    version: integer("version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
    editedAt: timestamp("edited_at", { withTimezone: true, mode: "date" }),
    deletedAt: timestamp("deleted_at", { withTimezone: true, mode: "date" }),
  },
  (t) => [
    index("ix_messages_conv_created").on(t.conversationId, t.createdAt),
    uniqueIndex("uq_messages_sender_client").on(t.senderId, t.clientId),
  ],
);

export const messageContents = pgTable("message_contents", {
  messageId: text("message_id")
    .primaryKey()
    .references(() => messages.id, { onDelete: "cascade" }),
  originalText: text("original_text").notNull(),
});

/**
 * Per-language translation assets. Unique on (message, language, sourceVersion)
 * so edits simply create a new version row and stale ones are invalidated,
 * never silently replaced.
 */
export const messageTranslations = pgTable(
  "message_translations",
  {
    id: text("id").primaryKey(),
    messageId: text("message_id")
      .notNull()
      .references(() => messages.id, { onDelete: "cascade" }),
    targetLanguage: text("target_language").notNull(),
    translatedText: text("translated_text"),
    status: text("status").notNull().default("queued"), // queued|processing|completed|failed|stale
    provider: text("provider"),
    detail: text("detail"),
    attempts: integer("attempts").notNull().default(0),
    sourceVersion: integer("source_version").notNull().default(1),
    createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex("uq_translation_msg_lang_version").on(t.messageId, t.targetLanguage, t.sourceVersion),
    index("ix_translations_msg").on(t.messageId),
  ],
);

/* ── Media + voice processing ─────────────────────────────────────────────── */

export const mediaAssets = pgTable("media_assets", {
  id: text("id").primaryKey(),
  ownerId: text("owner_id")
    .notNull()
    .references(() => users.id),
  mimeType: text("mime_type").notNull(),
  sizeBytes: integer("size_bytes").notNull(),
  durationMs: integer("duration_ms"),
  // Demo-tier object storage: bytes live in the DB; production uses S3 keys.
  dataBase64: text("data_base64").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
});

export const voiceJobs = pgTable(
  "voice_processing_jobs",
  {
    id: text("id").primaryKey(),
    messageId: text("message_id")
      .notNull()
      .references(() => messages.id, { onDelete: "cascade" }),
    targetLanguage: text("target_language").notNull(),
    // uploaded|queued|transcribing|translating|synthesizing|completed|
    // failed_retryable|failed_permanent|cancelled|partial
    status: text("status").notNull().default("queued"),
    attempts: integer("attempts").notNull().default(0),
    detail: text("detail"),
    createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
  },
  (t) => [uniqueIndex("uq_voice_job_msg_lang").on(t.messageId, t.targetLanguage)],
);

/* ── Receipts, safety, outbox ─────────────────────────────────────────────── */

export const messageReceipts = pgTable(
  "message_receipts",
  {
    messageId: text("message_id")
      .notNull()
      .references(() => messages.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    deliveredAt: timestamp("delivered_at", { withTimezone: true, mode: "date" }),
    readAt: timestamp("read_at", { withTimezone: true, mode: "date" }),
  },
  (t) => [
    primaryKey({ columns: [t.messageId, t.userId] }),
    index("ix_receipts_msg").on(t.messageId),
  ],
);

export const userBlocks = pgTable("user_blocks", {
  blockerId: text("blocker_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  blockedId: text("blocked_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
});

export const reports = pgTable("reports", {
  id: text("id").primaryKey(),
  reporterId: text("reporter_id")
    .notNull()
    .references(() => users.id),
  messageId: text("message_id").references(() => messages.id, { onDelete: "set null" }),
  targetUserId: text("target_user_id").references(() => users.id, { onDelete: "set null" }),
  reason: text("reason").notNull(),
  status: text("status").notNull().default("open"),
  createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
});

/** Transactional outbox: message commit + event record happen atomically. */
export const outboxEvents = pgTable(
  "outbox_events",
  {
    id: text("id").primaryKey(),
    eventType: text("event_type").notNull(),
    payload: jsonb("payload").$type<Record<string, unknown>>().notNull(),
    createdAt: timestamp("created_at", { withTimezone: true, mode: "date" }).notNull().defaultNow(),
    publishedAt: timestamp("published_at", { withTimezone: true, mode: "date" }),
  },
  (t) => [index("ix_outbox_unpublished").on(t.publishedAt)],
);
