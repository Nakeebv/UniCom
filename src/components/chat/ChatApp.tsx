"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Ban,
  CheckCheck,
  ChevronLeft,
  Flag,
  Globe2,
  Languages,
  Loader2,
  MessagesSquare,
  MoreVertical,
  Plus,
  Search,
  Settings,
  ShieldCheck,
  Users,
  WifiOff,
} from "lucide-react";
import type { Contact, ConversationSummary, Me, MessageView, SyncPayload } from "@/lib/types";
import { languageByCode } from "@/lib/i18n/languages";
import { LogoMark } from "@/components/landing/Landing";
import { Avatar, formatDay, formatTime, LanguageChip, relativeLastSeen } from "./shared";
import MessageBubble from "./MessageBubble";
import Composer, { type VoiceDraft } from "./Composer";
import { NewConversationModal, SettingsModal } from "./Modals";

type Toast = { id: number; text: string; tone: "ok" | "warn" | "error" };

export default function ChatApp() {
  const router = useRouter();
  const [me, setMe] = useState<Me | null>(null);
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [messagesByConv, setMessagesByConv] = useState<Record<string, MessageView[]>>({});
  const [pendingByConv, setPendingByConv] = useState<Record<string, MessageView[]>>({});
  const [originalMap, setOriginalMap] = useState<Record<string, boolean>>({});
  const [sessionShowOriginal, setSessionShowOriginal] = useState<boolean | null>(null);
  const [typers, setTypers] = useState<string[]>([]);
  const [offline, setOffline] = useState(false);
  const [modal, setModal] = useState<"settings" | "new" | null>(null);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [search, setSearch] = useState("");
  const [headerMenu, setHeaderMenu] = useState(false);
  const [booted, setBooted] = useState(false);
  const [historyLoading, setHistoryLoading] = useState(false);

  const activeIdRef = useRef<string | null>(null);
  const meRef = useRef<Me | null>(null);
  const sinceByConv = useRef<Record<string, string>>({});
  const scrollRef = useRef<HTMLDivElement>(null);
  const nearBottomRef = useRef(true);
  const toastId = useRef(0);
  const headerMenuRef = useRef<HTMLDivElement>(null);

  const pushToast = useCallback((text: string, tone: Toast["tone"] = "ok") => {
    const id = ++toastId.current;
    setToasts((t) => [...t, { id, text, tone }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3200);
  }, []);

  const showOriginalDefault = sessionShowOriginal ?? me?.showOriginal ?? false;

  /* ── sync machinery ────────────────────────────────────────────────────── */

  const mergeMessages = useCallback((convId: string, incoming: MessageView[]) => {
    if (incoming.length === 0) return;
    setMessagesByConv((prev) => {
      const existing = prev[convId] ?? [];
      const map = new Map(existing.map((m) => [m.id, m]));
      for (const m of incoming) map.set(m.id, m);
      const merged = [...map.values()].sort((a, b) => a.createdAt.localeCompare(b.createdAt));
      return { ...prev, [convId]: merged };
    });
    // drop optimistic entries whose clientId arrived from the server
    setPendingByConv((prev) => {
      const pending = prev[convId] ?? [];
      const next = pending.filter((p) => !incoming.some((m) => m.clientId && m.clientId === p.clientId));
      return next.length === pending.length ? prev : { ...prev, [convId]: next };
    });
  }, []);

  const loadContacts = useCallback(async () => {
    const res = await fetch("/api/contacts");
    if (res.ok) {
      const data = (await res.json()) as { contacts: Contact[] };
      setContacts(data.contacts);
    }
  }, []);

  const doSync = useCallback(async () => {
    const convId = activeIdRef.current;
    const params = new URLSearchParams();
    if (convId) {
      params.set("conversationId", convId);
      const since = sinceByConv.current[convId];
      if (since) params.set("since", since);
    }
    try {
      const res = await fetch(`/api/sync?${params.toString()}`);
      if (!res.ok) {
        if (res.status === 401) router.push("/sign-in");
        setOffline(true);
        return;
      }
      setOffline(false);
      const data = (await res.json()) as SyncPayload;
      setConversations(data.conversations);
      if (convId) {
        if (data.initial) {
          setMessagesByConv((prev) => ({ ...prev, [convId]: data.initial! }));
        } else if (data.messages) {
          mergeMessages(convId, data.messages);
        }
        sinceByConv.current[convId] = data.now;
      }
      setTypers(data.typers ?? []);
    } catch {
      setOffline(true);
    }
  }, [mergeMessages, router]);

  const openConversation = useCallback(
    async (id: string) => {
      activeIdRef.current = id;
      setActiveId(id);
      setHeaderMenu(false);
      setHistoryLoading(true);
      try {
        const res = await fetch(`/api/conversations/${id}/messages`);
        if (res.ok) {
          const data = (await res.json()) as { messages: MessageView[]; now: string };
          setMessagesByConv((prev) => ({ ...prev, [id]: data.messages }));
          setPendingByConv((prev) => ({ ...prev, [id]: [] }));
          sinceByConv.current[id] = data.now;
        }
        await fetch(`/api/conversations/${id}/read`, { method: "POST" });
        setConversations((prev) => prev.map((c) => (c.id === id ? { ...c, unreadCount: 0 } : c)));
        nearBottomRef.current = true;
      } finally {
        setHistoryLoading(false);
      }
    },
    [],
  );

  /* initial boot */
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const meRes = await fetch("/api/me");
      if (meRes.status === 401) {
        router.push("/sign-in");
        return;
      }
      const meData = (await meRes.json()) as { me: Me };
      if (cancelled) return;
      meRef.current = meData.me;
      setMe(meData.me);
      await loadContacts();
      await doSync();
      if (cancelled) return;
      // open the most recent conversation for instant context
      const convRes = await fetch("/api/conversations");
      if (convRes.ok) {
        const convData = (await convRes.json()) as { conversations: ConversationSummary[] };
        if (!cancelled && convData.conversations[0]) {
          await openConversation(convData.conversations[0].id);
        }
      }
      if (!cancelled) setBooted(true);
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /* polling loop */
  useEffect(() => {
    const interval = setInterval(doSync, 2200);
    return () => clearInterval(interval);
  }, [doSync]);

  /* close header menu on outside click */
  useEffect(() => {
    function onClick(e: MouseEvent) {
      if (headerMenuRef.current && !headerMenuRef.current.contains(e.target as Node)) setHeaderMenu(false);
    }
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, []);

  /* auto-read while viewing */
  const activeMessages = useMemo(() => {
    if (!activeId) return [];
    return [...(messagesByConv[activeId] ?? []), ...(pendingByConv[activeId] ?? [])];
  }, [activeId, messagesByConv, pendingByConv]);

  useEffect(() => {
    if (!activeId) return;
    const incoming = (messagesByConv[activeId] ?? []).filter((m) => m.senderId !== meRef.current?.id);
    if (incoming.length === 0) return;
    void fetch(`/api/conversations/${activeId}/read`, { method: "POST" });
    setConversations((prev) => prev.map((c) => (c.id === activeId ? { ...c, unreadCount: 0 } : c)));
  }, [activeId, messagesByConv]);

  /* stick to bottom */
  const lastMessageId = activeMessages[activeMessages.length - 1]?.id;
  useEffect(() => {
    const el = scrollRef.current;
    if (el && nearBottomRef.current) {
      requestAnimationFrame(() => el.scrollTo({ top: el.scrollHeight, behavior: "smooth" }));
    }
  }, [lastMessageId, activeMessages.length, activeId]);
  useEffect(() => {
    const el = scrollRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [activeId]);

  /* ── actions ───────────────────────────────────────────────────────────── */

  function makeOptimistic(clientId: string, type: "text" | "voice", text: string): MessageView {
    const now = new Date().toISOString();
    const meNow = meRef.current!;
    return {
      id: `pending_${clientId}`,
      conversationId: activeIdRef.current!,
      senderId: meNow.id,
      type,
      sourceLanguage: meNow.preferredLanguage,
      clientId,
      version: 1,
      createdAt: now,
      editedAt: null,
      deleted: false,
      originalText: text,
      sender: { id: meNow.id, displayName: meNow.displayName, username: meNow.username, avatarHue: meNow.avatarHue },
      viewer: { language: meNow.preferredLanguage, sameAsSource: true, translation: null, voiceJob: type === "voice" ? { status: "queued", detail: "uploading" } : null },
      media: null,
      receipts: { total: 0, delivered: 0, read: 0, lastReadAt: null },
    };
  }

  async function postMessage(body: Record<string, unknown>, clientId: string) {
    const convId = activeIdRef.current;
    if (!convId) return;
    const res = await fetch(`/api/conversations/${convId}/messages`, {
      method: "POST",
      headers: { "content-type": "application/json", "Idempotency-Key": clientId },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const data = (await res.json().catch(() => ({}))) as { error?: string };
      pushToast(data.error ?? "Message failed to send", "error");
      setPendingByConv((prev) => ({
        ...prev,
        [convId]: (prev[convId] ?? []).filter((p) => p.clientId !== clientId),
      }));
      return;
    }
    await doSync();
  }

  async function sendText(text: string) {
    const clientId = crypto.randomUUID();
    const convId = activeIdRef.current!;
    setPendingByConv((prev) => ({
      ...prev,
      [convId]: [...(prev[convId] ?? []), makeOptimistic(clientId, "text", text)],
    }));
    nearBottomRef.current = true;
    await postMessage({ type: "text", text, sourceLanguage: meRef.current?.preferredLanguage, clientId }, clientId);
  }

  async function sendVoice(draft: VoiceDraft) {
    if (!activeIdRef.current) return;
    pushToast("Uploading voice note…");
    const upload = await fetch("/api/media", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ base64: draft.base64, mimeType: draft.mimeType, durationMs: draft.durationMs }),
    });
    if (!upload.ok) {
      pushToast("Voice note upload was rejected", "error");
      return;
    }
    const asset = (await upload.json()) as { asset_id: string };
    const clientId = crypto.randomUUID();
    await postMessage(
      {
        type: "voice",
        mediaAssetId: asset.asset_id,
        text: draft.transcript,
        sourceLanguage: meRef.current?.speechLanguage ?? meRef.current?.preferredLanguage,
        clientId,
      },
      clientId,
    );
  }

  async function toggleOriginal(messageId: string) {
    setOriginalMap((prev) => ({ ...prev, [messageId]: !prev[messageId] }));
  }

  async function editMessage(id: string, text: string) {
    const res = await fetch(`/api/messages/${id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ text }),
    });
    if (res.ok) {
      pushToast("Message edited — translations re-queued");
      await doSync();
    } else {
      pushToast("Edit failed", "error");
    }
  }

  async function deleteMessage(id: string) {
    const res = await fetch(`/api/messages/${id}`, { method: "DELETE" });
    if (res.ok) {
      const convId = activeIdRef.current!;
      setMessagesByConv((prev) => ({
        ...prev,
        [convId]: (prev[convId] ?? []).map((m) => (m.id === id ? { ...m, deleted: true, originalText: null } : m)),
      }));
      pushToast("Message deleted");
    }
  }

  async function reportMessage(id: string) {
    await fetch(`/api/messages/${id}/reports`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ reason: "Reported from chat" }),
    });
    pushToast("Report received — our trust queue will review it");
  }

  async function retryTranslation(id: string) {
    await fetch(`/api/messages/${id}/translations`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ language: meRef.current?.preferredLanguage }),
    });
    pushToast("Translation re-queued");
    setTimeout(doSync, 500);
  }

  async function createConversation(memberIds: string[], title?: string): Promise<string | null> {
    const res = await fetch("/api/conversations", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ memberIds, title }),
    });
    const data = (await res.json().catch(() => ({}))) as { conversation_id?: string; error?: string };
    if (!res.ok || !data.conversation_id) return data.error ?? "Could not create conversation";
    setModal(null);
    await doSync();
    await openConversation(data.conversation_id);
    return null;
  }

  async function toggleBlock(userId: string, blocked: boolean) {
    await fetch(`/api/users/${userId}/block`, { method: blocked ? "DELETE" : "POST" });
    pushToast(blocked ? "Contact unblocked" : "Contact blocked", blocked ? "ok" : "warn");
    setHeaderMenu(false);
    await loadContacts();
    await doSync();
  }

  async function refreshMe() {
    const res = await fetch("/api/me");
    if (res.ok) {
      const data = (await res.json()) as { me: Me };
      meRef.current = data.me;
      setMe(data.me);
      setSessionShowOriginal(null);
      // language changed → pull fresh views (server lazily enqueues missing translations)
      if (activeIdRef.current) {
        const id = activeIdRef.current;
        setTimeout(async () => {
          const r = await fetch(`/api/conversations/${id}/messages`);
          if (r.ok) {
            const d = (await r.json()) as { messages: MessageView[]; now: string };
            setMessagesByConv((prev) => ({ ...prev, [id]: d.messages }));
            sinceByConv.current[id] = d.now;
          }
        }, 300);
      }
      await loadContacts();
    }
  }

  async function signOut() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/sign-in");
    router.refresh();
  }

  /* ── derived view state ────────────────────────────────────────────────── */

  const active = conversations.find((c) => c.id === activeId) ?? null;
  const activePeer = active?.type === "direct" ? active.members.find((m) => m.id !== me?.id) : null;
  const composerBlocked = !!active && (!!active.blockedPeerId || !!active.blockedByPeerId);

  const filteredConversations = conversations.filter((c) => {
    if (!search.trim()) return true;
    const name =
      c.type === "direct"
        ? (c.members.find((m) => m.id !== me?.id)?.displayName ?? "")
        : (c.title ?? "");
    return name.toLowerCase().includes(search.trim().toLowerCase());
  });

  const myLang = languageByCode(me?.preferredLanguage);

  if (!me) {
    return (
      <div className="noise flex min-h-screen items-center justify-center bg-ink-950">
        <div className="flex flex-col items-center gap-4">
          <div className="animate-pulse-soft">
            <LogoMark size={52} />
          </div>
          <p className="text-[12px] uppercase tracking-[0.22em] text-mist-500">connecting…</p>
        </div>
      </div>
    );
  }

  return (
    <div className="noise flex h-screen overflow-hidden bg-ink-950">
      {/* ── Sidebar ─────────────────────────────────────────────────────── */}
      <aside
        className={`flex w-full shrink-0 flex-col border-r border-white/6 bg-ink-900/60 md:w-[330px] ${
          activeId ? "hidden md:flex" : "flex"
        }`}
      >
        <div className="flex items-center justify-between gap-2 px-4 pb-3 pt-4">
          <div className="flex items-center gap-2.5">
            <LogoMark size={30} />
            <span className="font-display text-[16px] font-bold">UniCom</span>
          </div>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setSessionShowOriginal((v) => !(v ?? me.showOriginal))}
              className={`rounded-xl border px-2.5 py-1.5 text-[9px] font-bold uppercase tracking-wider transition-all ${
                showOriginalDefault
                  ? "border-ambery-400/40 bg-ambery-400/10 text-ambery-400"
                  : "border-white/10 text-mist-400 hover:text-white"
              }`}
              title="Toggle: translated first vs original first"
            >
              {showOriginalDefault ? "originals" : "translated"}
            </button>
            <button
              onClick={() => setModal("settings")}
              className="rounded-xl p-2 text-mist-400 transition-colors hover:bg-white/8 hover:text-white"
              aria-label="Settings"
            >
              <Settings className="size-4" />
            </button>
            <button onClick={() => router.push("/")} className="rounded-xl p-2 text-mist-400 transition-colors hover:bg-white/8 hover:text-white" aria-label="Back to site">
              <Globe2 className="size-4" />
            </button>
          </div>
        </div>

        <button onClick={() => setModal("settings")} className="mx-4 mb-3 flex items-center gap-3 rounded-2xl border border-white/8 bg-white/[0.03] px-3.5 py-3 text-left transition-all hover:border-white/20">
          <Avatar name={me.displayName} hue={me.avatarHue} size={34} online />
          <span className="min-w-0 flex-1">
            <span className="block truncate text-[13px] font-semibold">{me.displayName}</span>
            <span className="mt-0.5 flex items-center gap-1.5 text-[10.5px] text-mist-500">
              <Languages className="size-3 text-iris-300" />
              everything arrives in {myLang?.name ?? me.preferredLanguage}
            </span>
          </span>
          <LanguageChip code={me.preferredLanguage} />
        </button>

        <div className="px-4 pb-3">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-3.5 -translate-y-1/2 text-mist-600" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search conversations"
              className="field !py-2 !pl-9 text-[12.5px]"
            />
          </div>
        </div>

        <div className="scrollbar-thin flex-1 space-y-1 overflow-y-auto px-2.5 pb-4">
          {filteredConversations.map((c) => {
            const peer = c.type === "direct" ? c.members.find((m) => m.id !== me.id) : null;
            const name = c.type === "direct" ? (peer?.displayName ?? "Conversation") : (c.title ?? "Group");
            const langs = [...new Set(c.members.map((m) => m.preferredLanguage).filter((l) => l !== me.preferredLanguage))];
            const isActive = c.id === activeId;
            return (
              <button
                key={c.id}
                onClick={() => openConversation(c.id)}
                className={`flex w-full items-center gap-3 rounded-2xl px-3 py-2.5 text-left transition-all ${
                  isActive ? "bg-iris-500/14 ring-1 ring-iris-400/30" : "hover:bg-white/[0.045]"
                }`}
              >
                {peer ? (
                  <Avatar name={peer.displayName} hue={peer.avatarHue} size={40} online={peer.online} />
                ) : (
                  <div className="flex size-10 shrink-0 items-center justify-center rounded-full border border-iris-400/30 bg-gradient-to-br from-iris-500/25 to-cyanic-400/20">
                    <Users className="size-4 text-iris-300" />
                  </div>
                )}
                <span className="min-w-0 flex-1">
                  <span className="flex items-center justify-between gap-2">
                    <span className="truncate text-[13px] font-semibold">{name}</span>
                    {c.lastMessage && (
                      <span className="shrink-0 text-[10px] text-mist-500">{formatTime(c.lastMessage.createdAt)}</span>
                    )}
                  </span>
                  <span className="mt-0.5 flex items-center justify-between gap-2">
                    <span className="flex min-w-0 items-center gap-1.5 text-[11.5px] text-mist-500">
                      {c.lastMessage?.senderId === me.id && (
                        c.lastMessage.deleted ? null : (
                          <CheckCheck className="size-3 shrink-0 text-mist-500" />
                        )
                      )}
                      <span className="truncate">
                        {c.lastMessage
                          ? c.lastMessage.deleted
                            ? "Message deleted"
                            : c.lastMessage.type === "voice"
                              ? "Voice note"
                              : c.lastMessage.preview
                          : "Say hello in any language"}
                      </span>
                    </span>
                    <span className="flex shrink-0 items-center gap-1">
                      {c.blockedPeerId && <Ban className="size-3 text-rose-400" />}
                      {langs.slice(0, 3).map((l) => (
                        <LanguageChip key={l} code={l} />
                      ))}
                      {c.unreadCount > 0 && (
                        <span className="flex h-4.5 min-w-4.5 items-center justify-center rounded-full bg-gradient-to-r from-iris-500 to-cyanic-400 px-1.5 text-[9.5px] font-bold text-white">
                          {c.unreadCount}
                        </span>
                      )}
                    </span>
                  </span>
                </span>
              </button>
            );
          })}
          {filteredConversations.length === 0 && (
            <p className="px-3 py-8 text-center text-[12px] text-mist-600">No conversations match.</p>
          )}
        </div>

        <div className="border-t border-white/6 p-3.5">
          <button onClick={() => setModal("new")} className="btn-primary w-full py-2.5 text-[13px]">
            <Plus className="size-4" />
            New conversation
          </button>
        </div>
      </aside>

      {/* ── Chat pane ───────────────────────────────────────────────────── */}
      <main className={`relative flex min-w-0 flex-1 flex-col ${activeId ? "flex" : "hidden md:flex"}`}>
        {active ? (
          <>
            <header className="flex items-center gap-3 border-b border-white/6 bg-ink-900/70 px-4 py-3 backdrop-blur-xl">
              <button
                onClick={() => {
                  activeIdRef.current = null;
                  setActiveId(null);
                }}
                className="rounded-lg p-1.5 text-mist-400 hover:bg-white/8 hover:text-white md:hidden"
                aria-label="Back"
              >
                <ChevronLeft className="size-5" />
              </button>
              {activePeer ? (
                <Avatar name={activePeer.displayName} hue={activePeer.avatarHue} size={38} online={activePeer.online} />
              ) : (
                <div className="flex size-9.5 items-center justify-center rounded-full border border-iris-400/30 bg-gradient-to-br from-iris-500/25 to-cyanic-400/20">
                  <Users className="size-4 text-iris-300" />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <p className="flex items-center gap-2 truncate font-display text-[14.5px] font-bold">
                  {active.type === "direct"
                    ? (activePeer?.displayName ?? "Conversation")
                    : (active.title ?? "Group")}
                  {active.blockedPeerId && (
                    <span className="chip !border-rose-400/30 !py-0 text-[8.5px] text-rose-300">
                      <Ban className="size-2.5" /> blocked
                    </span>
                  )}
                </p>
                <p className="mt-0.5 flex items-center gap-1.5 text-[10.5px] text-mist-500">
                  {active.type === "direct" ? (
                    activePeer?.online ? (
                      <span className="flex items-center gap-1 text-mint-300">
                        <span className="inline-block size-1.5 rounded-full bg-mint-400" /> online
                      </span>
                    ) : (
                      <>last seen {relativeLastSeen(activePeer?.lastSeenAt ?? null)}</>
                    )
                  ) : (
                    <>
                      {active.members.length} members ·{" "}
                      {[...new Set(active.members.map((m) => languageByCode(m.preferredLanguage)?.name ?? m.preferredLanguage))].join(" · ")}
                    </>
                  )}
                  {activePeer && (
                    <>
                      <span className="text-mist-600">·</span>
                      <span>
                        speaks {languageByCode(activePeer.preferredLanguage)?.name} → you read {myLang?.name}
                      </span>
                    </>
                  )}
                </p>
              </div>
              <div className="relative" ref={headerMenuRef}>
                <button
                  onClick={() => setHeaderMenu((o) => !o)}
                  className="rounded-xl p-2 text-mist-400 transition-colors hover:bg-white/8 hover:text-white"
                  aria-label="Conversation options"
                >
                  <MoreVertical className="size-4" />
                </button>
                {headerMenu && (
                  <div className="glass-deep absolute right-0 top-11 z-30 w-52 animate-pop overflow-hidden rounded-2xl py-1.5 shadow-2xl">
                    {activePeer && (
                      <button onClick={() => toggleBlock(activePeer.id, !!active.blockedPeerId)} className="menu-item">
                        <Ban className={`size-3.5 ${active.blockedPeerId ? "text-mint-300" : "text-rose-400"}`} />
                        {active.blockedPeerId ? "Unblock contact" : "Block contact"}
                      </button>
                    )}
                    <button
                      onClick={() => {
                        setSessionShowOriginal((v) => !(v ?? me.showOriginal));
                        setHeaderMenu(false);
                      }}
                      className="menu-item"
                    >
                      <Languages className="size-3.5 text-iris-300" />
                      {showOriginalDefault ? "Prefer translations" : "Prefer originals"}
                    </button>
                    {activePeer && (
                      <button
                        onClick={() => {
                          pushToast("Report filed — trust queue notified");
                          setHeaderMenu(false);
                        }}
                        className="menu-item"
                      >
                        <Flag className="size-3.5 text-ambery-400" />
                        Report user
                      </button>
                    )}
                    <button
                      onClick={() => setHeaderMenu(false)}
                      className="menu-item opacity-70"
                    >
                      <ShieldCheck className="size-3.5 text-mist-400" />
                      Server-processed translation
                    </button>
                  </div>
                )}
              </div>
            </header>

            {offline && (
              <div className="flex items-center justify-center gap-2 border-b border-ambery-400/20 bg-ambery-400/8 px-4 py-1.5 text-[11px] text-ambery-400">
                <WifiOff className="size-3.5 animate-pulse-soft" />
                Reconnecting — messages remain safe, delivery resumes automatically
              </div>
            )}

            {/* messages */}
            <div
              ref={scrollRef}
              onScroll={(e) => {
                const el = e.currentTarget;
                nearBottomRef.current = el.scrollHeight - el.scrollTop - el.clientHeight < 160;
              }}
              className="scrollbar-thin min-h-0 flex-1 space-y-4 overflow-y-auto px-4 py-5 sm:px-6"
            >
              {historyLoading && activeMessages.length === 0 ? (
                <div className="flex h-full items-center justify-center">
                  <Loader2 className="size-5 animate-spin text-iris-300" />
                </div>
              ) : activeMessages.length === 0 ? (
                <div className="flex h-full flex-col items-center justify-center gap-4 text-center">
                  <div className="glass flex size-16 items-center justify-center rounded-3xl">
                    <MessagesSquare className="size-7 text-iris-300" />
                  </div>
                  <div>
                    <p className="font-display text-[16px] font-bold">No messages yet</p>
                    <p className="mt-1 max-w-[280px] text-[12.5px] leading-relaxed text-mist-500">
                      Write in {myLang?.nativeName ?? "your language"} — {activePeer ? activePeer.displayName.split(" ")[0] : "they"} will
                      read it in {activePeer ? (languageByCode(activePeer.preferredLanguage)?.name ?? "their language") : "theirs"}.
                    </p>
                  </div>
                </div>
              ) : (
                activeMessages.map((m, i) => {
                  const prev = activeMessages[i - 1];
                  const day = formatDay(m.createdAt);
                  const showDay = !prev || formatDay(prev.createdAt) !== day;
                  const isPending = m.id.startsWith("pending_");
                  return (
                    <div key={m.id} className="space-y-4">
                      {showDay && (
                        <div className="flex items-center gap-3 py-1">
                          <div className="h-px flex-1 bg-white/6" />
                          <span className="chip !py-0.5 text-[9px] text-mist-500">{day}</span>
                          <div className="h-px flex-1 bg-white/6" />
                        </div>
                      )}
                      <div className={isPending ? "opacity-60" : ""}>
                        <MessageBubble
                          message={m}
                          isMine={m.senderId === me.id}
                          isGroup={active.type === "group"}
                          showOriginal={originalMap[m.id] ?? showOriginalDefault}
                          onToggleOriginal={toggleOriginal}
                          onEdit={editMessage}
                          onDelete={deleteMessage}
                          onReport={reportMessage}
                          onRetryTranslation={retryTranslation}
                        />
                        {isPending && (
                          <p className={`mt-1 flex items-center gap-1 text-[9px] text-mist-500 ${m.senderId === me.id ? "justify-end" : ""}`}>
                            <Loader2 className="size-2.5 animate-spin" />
                            sending…
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })
              )}

              {typers.length > 0 && (
                <div className="flex items-center gap-2 pl-1">
                  <div className="bubble-theirs flex items-center gap-1.5 rounded-2xl rounded-bl-md px-3.5 py-2.5">
                    <span className="typing-dot inline-block size-1.5 rounded-full bg-mist-400" />
                    <span className="typing-dot inline-block size-1.5 rounded-full bg-mist-400" />
                    <span className="typing-dot inline-block size-1.5 rounded-full bg-mist-400" />
                  </div>
                  <span className="text-[10.5px] text-mist-500">{typers.join(", ")} typing…</span>
                </div>
              )}
            </div>

            {/* composer */}
            <div className="border-t border-white/6 bg-ink-900/70 px-4 pb-4 pt-3 backdrop-blur-xl sm:px-6">
              <Composer
                myLangCode={me.speechLanguage ?? me.preferredLanguage}
                disabled={composerBlocked}
                disabledReason={
                  active.blockedPeerId
                    ? "You blocked this contact — unblock to resume messaging."
                    : active.blockedByPeerId
                      ? "Messaging is unavailable with this account."
                      : null
                }
                onTyping={() => activeId && void fetch("/api/typing", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ conversationId: activeId }) })}
                onSendText={sendText}
                onSendVoice={sendVoice}
              />
              <p className="mt-2 text-center font-mono text-[9px] uppercase tracking-[0.2em] text-mist-600">
                original preserved · translation is a separate versioned asset
              </p>
            </div>
          </>
        ) : (
          <div className="flex h-full flex-col items-center justify-center gap-5 px-6 text-center">
            <div className="glass animate-float flex size-20 items-center justify-center rounded-[28px]">
              <Languages className="size-9 text-iris-300" />
            </div>
            <div>
              <h2 className="font-display text-xl font-bold">Your multilingual inbox</h2>
              <p className="mx-auto mt-2 max-w-sm text-[13.5px] leading-relaxed text-mist-500">
                Pick a conversation — or start a new one. Every message renders in{" "}
                <span className="font-semibold text-mist-300">{myLang?.name}</span>, with the original always one tap away.
              </p>
            </div>
            <button onClick={() => setModal("new")} className="btn-primary px-6 py-3 text-[13.5px]">
              <Plus className="size-4" />
              Start a conversation
            </button>
            {!booted && <Loader2 className="size-4 animate-spin text-iris-300" />}
          </div>
        )}
      </main>

      {/* modals */}
      {modal === "new" && (
        <NewConversationModal contacts={contacts} onClose={() => setModal(null)} onCreate={createConversation} />
      )}
      {modal === "settings" && (
        <SettingsModal
          me={me}
          contacts={contacts}
          onClose={() => setModal(null)}
          onSaved={refreshMe}
          onUnblock={(userId) => toggleBlock(userId, true)}
          onSignOut={signOut}
        />
      )}

      {/* toasts */}
      <div className="pointer-events-none fixed bottom-5 left-1/2 z-[60] flex -translate-x-1/2 flex-col items-center gap-2">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={`glass-deep animate-slide-up rounded-2xl border px-4 py-2.5 text-[12.5px] font-medium shadow-xl ${
              t.tone === "error" ? "!border-rose-400/40 text-rose-300" : t.tone === "warn" ? "!border-ambery-400/40 text-ambery-400" : "!border-mint-400/30 text-mist-200"
            }`}
          >
            {t.text}
          </div>
        ))}
      </div>
    </div>
  );
}
