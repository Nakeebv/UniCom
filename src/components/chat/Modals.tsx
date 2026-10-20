"use client";

import { useState } from "react";
import { Ban, Check, Languages, Loader2, LogOut, ShieldCheck, Volume2, X } from "lucide-react";
import type { Contact, Me } from "@/lib/types";
import { SUPPORTED_LANGUAGES } from "@/lib/i18n/languages";
import { Avatar, LanguageChip } from "./shared";

function ModalShell({ children, onClose, title }: { children: React.ReactNode; onClose: () => void; title: string }) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink-950/70 p-0 backdrop-blur-sm sm:items-center sm:p-4" onClick={onClose}>
      <div
        className="glass-deep max-h-[88vh] w-full max-w-md animate-slide-up overflow-y-auto rounded-t-3xl p-6 scrollbar-thin sm:rounded-3xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-display text-[17px] font-bold">{title}</h2>
          <button onClick={onClose} className="rounded-lg p-1.5 text-mist-400 transition-colors hover:bg-white/8 hover:text-white" aria-label="Close">
            <X className="size-4" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function NewConversationModal({
  contacts,
  onClose,
  onCreate,
}: {
  contacts: Contact[];
  onClose: () => void;
  onCreate: (memberIds: string[], title?: string) => Promise<string | null>;
}) {
  const [selected, setSelected] = useState<string[]>([]);
  const [title, setTitle] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const available = contacts.filter((c) => !c.blockedByMe && !c.blockedMe);

  function toggle(id: string) {
    setSelected((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  }

  async function create() {
    setBusy(true);
    setError(null);
    const err = await onCreate(selected, title.trim() || undefined);
    setBusy(false);
    if (err) setError(err);
  }

  return (
    <ModalShell onClose={onClose} title="New conversation">
      <p className="-mt-3 mb-4 text-[12px] text-mist-500">
        Pick one person for a direct chat, or several for a multilingual group — UniCom renders each language for the right member.
      </p>
      <div className="space-y-2">
        {available.map((c) => {
          const active = selected.includes(c.id);
          return (
            <button
              key={c.id}
              onClick={() => toggle(c.id)}
              className={`flex w-full items-center gap-3 rounded-2xl border px-3.5 py-3 text-left transition-all ${
                active ? "border-iris-400/50 bg-iris-500/10" : "border-white/8 bg-white/[0.02] hover:border-white/20"
              }`}
            >
              <Avatar name={c.displayName} hue={c.avatarHue} size={36} online={c.online} />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13px] font-semibold">{c.displayName}</span>
                <span className="mt-0.5 flex items-center gap-1 text-[10.5px] text-mist-500">
                  {c.online ? "online" : "offline"} · speaks{" "}
                  {SUPPORTED_LANGUAGES.find((l) => l.code === c.preferredLanguage)?.name ?? c.preferredLanguage}
                </span>
              </span>
              <LanguageChip code={c.preferredLanguage} />
              {active && <Check className="size-4 shrink-0 text-iris-300" />}
            </button>
          );
        })}
      </div>
      {selected.length > 1 && (
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Group name (optional)"
          className="field mt-4"
        />
      )}
      {error && <p className="mt-3 rounded-xl border border-rose-400/25 bg-rose-400/10 px-3 py-2 text-[12px] text-rose-300">{error}</p>}
      <button onClick={create} disabled={selected.length === 0 || busy} className="btn-primary mt-5 w-full py-3 text-[13.5px]">
        {busy ? <Loader2 className="size-4 animate-spin" /> : <Languages className="size-4" />}
        Start {selected.length > 1 ? `group (${selected.length + 1})` : "conversation"}
      </button>
    </ModalShell>
  );
}

export function SettingsModal({
  me,
  contacts,
  onClose,
  onSaved,
  onUnblock,
  onSignOut,
}: {
  me: Me;
  contacts: Contact[];
  onClose: () => void;
  onSaved: () => void;
  onUnblock: (userId: string) => void;
  onSignOut: () => void;
}) {
  const [lang, setLang] = useState(me.preferredLanguage);
  const [speechLang, setSpeechLang] = useState(me.speechLanguage ?? me.preferredLanguage);
  const [showOriginal, setShowOriginal] = useState(me.showOriginal);
  const [busy, setBusy] = useState(false);
  const [savedFlash, setSavedFlash] = useState(false);

  const blocked = contacts.filter((c) => c.blockedByMe);

  async function save() {
    setBusy(true);
    await fetch("/api/me", {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ preferredLanguage: lang, speechLanguage: speechLang, showOriginal }),
    });
    setBusy(false);
    setSavedFlash(true);
    setTimeout(() => setSavedFlash(false), 1600);
    onSaved();
  }

  return (
    <ModalShell onClose={onClose} title="Settings">
      <div className="mb-6 flex items-center gap-3.5 rounded-2xl border border-white/8 bg-white/[0.03] p-4">
        <Avatar name={me.displayName} hue={me.avatarHue} size={44} />
        <div className="min-w-0">
          <p className="truncate font-display text-[15px] font-bold">{me.displayName}</p>
          <p className="font-mono text-[11px] text-mist-500">@{me.username}</p>
        </div>
        {me.isPersona && <span className="chip ml-auto !py-0.5 text-[9px] text-cyanic-300">demo persona</span>}
      </div>

      <div className="space-y-5">
        <div>
          <label className="mb-2 flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider text-mist-500">
            <Languages className="size-3.5 text-iris-300" />
            Display language — incoming messages render in it
          </label>
          <select value={lang} onChange={(e) => setLang(e.target.value)} className="field">
            {SUPPORTED_LANGUAGES.map((l) => (
              <option key={l.code} value={l.code}>
                {l.nativeName} · {l.name}
                {l.status === "beta" ? " (beta)" : ""}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="mb-2 flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider text-mist-500">
            <Volume2 className="size-3.5 text-cyanic-300" />
            Speech language — used for voice-note transcription
          </label>
          <select value={speechLang} onChange={(e) => setSpeechLang(e.target.value)} className="field">
            {SUPPORTED_LANGUAGES.map((l) => (
              <option key={l.code} value={l.code}>
                {l.nativeName} · {l.name}
                {!l.capabilities.stt ? " (typed transcript)" : ""}
              </option>
            ))}
          </select>
        </div>

        <button
          onClick={() => setShowOriginal(!showOriginal)}
          className="flex w-full items-center justify-between gap-4 rounded-2xl border border-white/8 bg-white/[0.03] px-4 py-3.5 text-left"
        >
          <span>
            <span className="block text-[13px] font-semibold">Show originals by default</span>
            <span className="mt-0.5 block text-[11px] text-mist-500">
              Off: translated text first, original one tap away (recommended)
            </span>
          </span>
          <span className={`relative h-6 w-11 shrink-0 rounded-full transition-colors ${showOriginal ? "bg-iris-500" : "bg-ink-600"}`}>
            <span
              className={`absolute top-0.5 size-5 rounded-full bg-white transition-all ${showOriginal ? "left-[22px]" : "left-0.5"}`}
            />
          </span>
        </button>

        {blocked.length > 0 && (
          <div>
            <label className="mb-2 flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider text-mist-500">
              <ShieldCheck className="size-3.5 text-rose-400" />
              Blocked contacts
            </label>
            <div className="space-y-2">
              {blocked.map((c) => (
                <div key={c.id} className="flex items-center gap-3 rounded-2xl border border-rose-400/15 bg-rose-400/5 px-3.5 py-2.5">
                  <Ban className="size-3.5 text-rose-400" />
                  <span className="flex-1 truncate text-[12.5px]">{c.displayName}</span>
                  <button
                    onClick={() => onUnblock(c.id)}
                    className="btn-ghost px-3 py-1.5 text-[11px] font-semibold"
                  >
                    Unblock
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex gap-2.5 pt-1">
          <button onClick={save} disabled={busy} className="btn-primary flex-1 py-3 text-[13px]">
            {busy ? <Loader2 className="size-4 animate-spin" /> : savedFlash ? <Check className="size-4" /> : null}
            {savedFlash ? "Saved" : "Save preferences"}
          </button>
          <button onClick={onSignOut} className="btn-ghost px-4 py-3 text-[13px] font-semibold !text-rose-300 hover:!border-rose-400/40">
            <LogOut className="size-4" />
            Sign out
          </button>
        </div>
        <p className="text-center font-mono text-[10px] text-mist-600">
          Changing language requests missing translations on demand — no speculative synthesis.
        </p>
      </div>
    </ModalShell>
  );
}
