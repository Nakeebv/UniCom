/** Client-safe wire types mirroring the API serializers. */

export type PublicUser = {
  id: string;
  username: string;
  displayName: string;
  avatarHue: number;
  preferredLanguage: string;
  online: boolean;
  lastSeenAt: string | null;
};

export type Me = {
  id: string;
  username: string;
  displayName: string;
  avatarHue: number;
  bio: string | null;
  isPersona: boolean;
  preferredLanguage: string;
  speechLanguage: string | null;
  voiceId: string | null;
  showOriginal: boolean;
};

export type Contact = {
  id: string;
  username: string;
  displayName: string;
  avatarHue: number;
  bio: string | null;
  isPersona: boolean;
  preferredLanguage: string;
  online: boolean;
  lastSeenAt: string | null;
  blockedByMe: boolean;
  blockedMe: boolean;
};

export type TranslationView = {
  status: string; // queued | processing | completed | failed | stale
  text: string | null;
  provider: string | null;
  targetLanguage: string;
  updatedAt: string;
  sourceVersion: number;
};

export type VoiceJobView = { status: string; detail: string | null };

export type MessageView = {
  id: string;
  conversationId: string;
  senderId: string;
  type: "text" | "voice" | string;
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
    translation: TranslationView | null;
    voiceJob: VoiceJobView | null;
  };
  media: { id: string; mimeType: string; sizeBytes: number; durationMs: number | null } | null;
  receipts: { total: number; delivered: number; read: number; lastReadAt: string | null };
};

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

export type SyncPayload = {
  now: string;
  conversations: ConversationSummary[];
  messages?: MessageView[];
  initial?: MessageView[];
  typers: string[];
};
