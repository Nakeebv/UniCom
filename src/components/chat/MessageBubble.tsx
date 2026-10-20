"use client";

import { useEffect, useRef, useState } from "react";
import {
  Ban,
  Check,
  CheckCheck,
  Flag,
  Globe2,
  Loader2,
  MoreHorizontal,
  Pencil,
  RefreshCcw,
  Trash2,
} from "lucide-react";
import type { MessageView } from "@/lib/types";
import { languageByCode } from "@/lib/i18n/languages";
import VoicePlayer from "./VoicePlayer";
import { Avatar, formatTime, LanguageChip } from "./shared";

export default function MessageBubble({
  message,
  isMine,
  isGroup,
  showOriginal,
  onToggleOriginal,
  onEdit,
  onDelete,
  onReport,
  onRetryTranslation,
}: {
  message: MessageView;
  isMine: boolean;
  isGroup: boolean;
  showOriginal: boolean;
  onToggleOriginal: (id: string) => void;
  onEdit: (id: string, text: string) => void;
  onDelete: (id: string) => void;
  onReport: (id: string) => void;
  onRetryTranslation: (id: string) => void;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  const [deleting, setDeleting] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const translation = message.viewer.translation;
  const same = message.viewer.sameAsSource;
  const completed = !same && translation?.status === "completed" && !!translation.text;
  const pending =
    !same && !message.deleted && (!translation || ["queued", "processing"].includes(translation.status));
  const failed = !same && !!translation && ["failed", "stale"].includes(translation.status);
  const showTrans = completed && !showOriginal;

  const bodyText = showTrans ? translation!.text : message.originalText;
  const bodyLang = showTrans ? translation!.targetLanguage : message.sourceLanguage;
  const dir = languageByCode(bodyLang)?.dir ?? "ltr";

  const receipts = message.receipts;
  const allDelivered = receipts.total > 0 && receipts.delivered >= receipts.total;
  const allRead = receipts.total > 0 && receipts.read >= receipts.total;

  const sourceLangName = languageByCode(message.sourceLanguage)?.name ?? message.sourceLanguage;
  const targetLangName = languageByCode(message.viewer.language)?.name ?? message.viewer.language;

  useEffect(() => {
    function onDocClick(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
        setDeleting(false);
      }
    }
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  const speakerName = message.sender.displayName.split(" ")[0];

  function startEdit() {
    setDraft(message.originalText ?? "");
    setEditing(true);
    setMenuOpen(false);
  }

  const menu = (
    <div ref={menuRef} className={`relative ${isMine ? "order-first" : "order-last"}`}>
      <button
        onClick={() => setMenuOpen((o) => !o)}
        className="invisible rounded-lg border border-white/10 bg-ink-800/90 p-1.5 text-mist-400 opacity-0 shadow-lg transition-all hover:text-white group-hover:visible group-hover:opacity-100"
        aria-label="Message actions"
      >
        <MoreHorizontal className="size-3.5" />
      </button>
      {menuOpen && (
        <div className="glass-deep absolute top-8 z-30 w-44 animate-pop overflow-hidden rounded-2xl py-1.5 shadow-2xl" style={{ [isMine ? "right" : "left"]: 0 } as React.CSSProperties}>
          {isMine && !message.deleted && (message.originalText ?? "") !== "" && (
            <button onClick={startEdit} className="menu-item">
              <Pencil className="size-3.5 text-cyanic-300" />
              Edit {message.type === "voice" ? "transcript" : "message"}
            </button>
          )}
          {!message.deleted && !same && (
            <button
              onClick={() => {
                onRetryTranslation(message.id);
                setMenuOpen(false);
              }}
              className="menu-item"
            >
              <RefreshCcw className="size-3.5 text-iris-300" />
              Retry translation
            </button>
          )}
          {isMine && !message.deleted && (
            deleting ? (
              <button
                onClick={() => {
                  onDelete(message.id);
                  setMenuOpen(false);
                }}
                className="menu-item !text-rose-300"
              >
                <Trash2 className="size-3.5" />
                Confirm delete
              </button>
            ) : (
              <button onClick={() => setDeleting(true)} className="menu-item">
                <Trash2 className="size-3.5 text-rose-400" />
                Delete
              </button>
            )
          )}
          {!isMine && (
            <>
              <button
                onClick={() => {
                  onReport(message.id);
                  setMenuOpen(false);
                }}
                className="menu-item"
              >
                <Flag className="size-3.5 text-ambery-400" />
                Report message
              </button>
              <button onClick={() => setMenuOpen(false)} className="menu-item opacity-60">
                <Ban className="size-3.5 text-mist-500" />
                Block from header
              </button>
            </>
          )}
        </div>
      )}
    </div>
  );

  return (
    <div className={`group flex w-full items-end gap-2.5 ${isMine ? "flex-row-reverse" : "flex-row"}`}>
      {!isMine && (
        <div className="hidden shrink-0 sm:block">
          <Avatar name={message.sender.displayName} hue={message.sender.avatarHue} size={30} />
        </div>
      )}

      <div className={`flex max-w-[80%] items-center gap-1.5 sm:max-w-[70%] ${isMine ? "flex-row-reverse" : ""}`}>
        <div className={`flex min-w-0 flex-col ${isMine ? "items-end" : "items-start"}`}>
          {isGroup && !isMine && (
            <p className="mb-1 flex items-center gap-1.5 pl-1 text-[10.5px] font-semibold text-mist-500">
              <span style={{ color: `hsl(${message.sender.avatarHue} 75% 65%)` }}>{speakerName}</span>
              <LanguageChip code={message.sourceLanguage} />
            </p>
          )}

          <div
            className={`min-w-0 rounded-[1.3rem] px-4 py-3 ${
              isMine ? "bubble-mine rounded-br-md" : "bubble-theirs rounded-bl-md"
            } ${message.deleted ? "opacity-70" : ""}`}
            dir={dir}
          >
            {message.deleted ? (
              <p className="flex items-center gap-2 text-[13px] italic text-mist-500">
                <Ban className="size-3.5" />
                This message was deleted
              </p>
            ) : message.type === "voice" ? (
              <VoicePlayer message={message} isMine={isMine} showOriginal={showOriginal} onToggleOriginal={onToggleOriginal} />
            ) : editing ? (
              <div className="min-w-[min(320px,60vw)]">
                <textarea
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  className="field min-h-[72px] !bg-ink-900/60 text-[13px]"
                  autoFocus
                />
                <div className="mt-2 flex justify-end gap-2">
                  <button onClick={() => setEditing(false)} className="btn-ghost px-3 py-1.5 text-[11px] font-semibold">
                    Cancel
                  </button>
                  <button
                    onClick={() => {
                      if (draft.trim()) onEdit(message.id, draft.trim());
                      setEditing(false);
                    }}
                    className="btn-primary px-3.5 py-1.5 text-[11px]"
                  >
                    <Check className="size-3" />
                    Save v{message.version + 1}
                  </button>
                </div>
                <p className="mt-1.5 text-[9.5px] text-mist-500">
                  Saving bumps the version and re-translates every recipient language.
                </p>
              </div>
            ) : (
              <>
                <p className="whitespace-pre-wrap break-words text-[13.5px] leading-relaxed text-white/95">
                  {bodyText}
                </p>

                {/* translation status line */}
                {message.type === "text" && (completed || pending || failed || same) && (
                  <div className="mt-1.5 space-y-1.5" dir="ltr">
                    {pending && (
                      <div className="space-y-1.5">
                        <div className="h-1 w-36 overflow-hidden rounded-full bg-white/8">
                          <div className="shimmer-line h-full w-full rounded-full" />
                        </div>
                        <p className="flex items-center gap-1 text-[8.5px] font-semibold uppercase tracking-[0.14em] text-cyanic-300">
                          <Loader2 className="size-2.5 animate-spin" />
                          Translating {sourceLangName} → {targetLangName}…
                        </p>
                      </div>
                    )}
                    {completed && (
                      <button
                        onClick={() => onToggleOriginal(message.id)}
                        className={`flex items-center gap-1 text-[8.5px] font-semibold uppercase tracking-[0.14em] transition-colors ${
                          isMine ? "text-white/70 hover:text-white" : "text-iris-300 hover:text-white"
                        }`}
                        title={translation!.provider ? `provider: ${translation!.provider}` : undefined}
                      >
                        <Globe2 className="size-2.5" />
                        {showOriginal
                          ? `original · ${sourceLangName} — tap for translation`
                          : `translated ${message.sourceLanguage}→${translation!.targetLanguage} · ${translation!.provider ?? "provider"}`}
                      </button>
                    )}
                    {failed && (
                      <p className="flex items-center gap-1.5 text-[8.5px] font-semibold uppercase tracking-[0.14em] text-rose-300">
                        <span>Translation unavailable — original shown</span>
                        <button
                          onClick={() => onRetryTranslation(message.id)}
                          className="flex items-center gap-0.5 rounded-full border border-rose-400/30 px-1.5 py-0.5 text-[8px] transition-colors hover:bg-rose-400/10"
                        >
                          <RefreshCcw className="size-2" />
                          retry
                        </button>
                      </p>
                    )}
                    {same && !isMine && (
                      <p className="text-[8.5px] font-semibold uppercase tracking-[0.14em] text-mist-500">
                        Original · {sourceLangName}
                      </p>
                    )}
                  </div>
                )}
              </>
            )}

            {/* meta row */}
            <div className={`mt-1.5 flex items-center gap-1.5 ${isMine ? "justify-end" : "justify-start"}`} dir="ltr">
              {message.editedAt && !message.deleted && (
                <span className="text-[9px] italic text-mist-500" title={`version ${message.version}`}>
                  edited v{message.version}
                </span>
              )}
              <span className="text-[9.5px] text-mist-500">{formatTime(message.createdAt)}</span>
              {isMine && !message.deleted && (
                <span
                  title={
                    allRead
                      ? receipts.total > 1
                        ? `Seen by all (${receipts.read}/${receipts.total})`
                        : "Seen"
                      : allDelivered
                        ? "Delivered"
                        : "Sent"
                  }
                >
                  {allRead ? (
                    <CheckCheck className="size-3.5 text-cyanic-300" />
                  ) : allDelivered ? (
                    <CheckCheck className="size-3.5 text-mist-400" />
                  ) : (
                    <Check className="size-3.5 text-mist-400" />
                  )}
                </span>
              )}
            </div>
          </div>
        </div>

        {menu}
      </div>
    </div>
  );
}
