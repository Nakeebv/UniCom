"use client";

import { useEffect, useRef, useState } from "react";
import { AlertTriangle, FileAudio, Languages, Loader2, Pause, Play, Volume2 } from "lucide-react";
import type { MessageView } from "@/lib/types";
import { languageByCode } from "@/lib/i18n/languages";
import { formatDuration, waveBars, speak } from "./shared";

const JOB_LABELS: Record<string, string> = {
  queued: "Queued",
  transcribing: "Transcribing…",
  translating: "Translating…",
  synthesizing: "Synthesizing…",
  completed: "Ready",
  failed_retryable: "Retrying…",
  failed_permanent: "Unavailable",
  partial: "Transcript unavailable",
  cancelled: "Cancelled",
};

export default function VoicePlayer({
  message,
  isMine,
  showOriginal,
  onToggleOriginal,
}: {
  message: MessageView;
  isMine: boolean;
  showOriginal: boolean;
  onToggleOriginal: (id: string) => void;
}) {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [speaking, setSpeaking] = useState(false);
  const bars = waveBars(message.id, 24);

  const translation = message.viewer.translation;
  const job = message.viewer.voiceJob;
  const translatedText =
    !message.viewer.sameAsSource && translation?.status === "completed" ? translation.text : null;
  const transcript = showOriginal || !translatedText ? message.originalText : translatedText;
  const transcriptLang = showOriginal || !translatedText ? message.sourceLanguage : translation?.targetLanguage ?? message.sourceLanguage;
  const langDef = languageByCode(transcriptLang);
  const jobActive = job && !["completed", "partial", "failed_permanent", "cancelled"].includes(job.status);

  useEffect(() => {
    return () => {
      if (typeof speechSynthesis !== "undefined") speechSynthesis.cancel();
    };
  }, []);

  function toggleAudio() {
    const el = audioRef.current;
    if (!el) return;
    if (playing) {
      el.pause();
      setPlaying(false);
    } else {
      if (typeof speechSynthesis !== "undefined") speechSynthesis.cancel();
      setSpeaking(false);
      void el.play();
      setPlaying(true);
    }
  }

  function toggleSpeech() {
    if (!translatedText) return;
    if (speaking) {
      speechSynthesis.cancel();
      setSpeaking(false);
      return;
    }
    const el = audioRef.current;
    el?.pause();
    setPlaying(false);
    const langDef2 = languageByCode(translation?.targetLanguage ?? "en");
    const ok = speak(translatedText, langDef2?.speechLocale ?? "en-US", () => setSpeaking(false));
    if (ok) setSpeaking(true);
  }

  return (
    <div className="w-[min(300px,68vw)]">
      {/* audio row */}
      <div className="flex items-center gap-3">
        <button
          onClick={toggleAudio}
          className={`relative flex size-10 shrink-0 items-center justify-center rounded-full transition-transform active:scale-95 ${
            isMine ? "bg-white/90 text-iris-500" : "bg-gradient-to-br from-iris-500 to-cyanic-400 text-white"
          }`}
          aria-label={playing ? "Pause original audio" : "Play original audio"}
        >
          {playing ? <Pause className="size-4" fill="currentColor" /> : <Play className="ml-0.5 size-4" fill="currentColor" />}
        </button>
        <div className="flex h-8 flex-1 items-center gap-[2.5px]">
          {bars.map((b, i) => {
            const active = progress > i / bars.length;
            return (
              <span
                key={i}
                className={`w-[3px] rounded-full transition-colors duration-150 ${active ? (isMine ? "bg-white" : "bg-iris-300") : "bg-white/25"} ${playing ? "wave-bar" : ""}`}
                style={{ height: `${Math.max(18, b * 100)}%`, animationDelay: `${(i % 8) * 0.09}s` }}
              />
            );
          })}
        </div>
        <span className="shrink-0 font-mono text-[10px] text-mist-400">{formatDuration(message.media?.durationMs)}</span>
      </div>
      <audio
        ref={audioRef}
        src={message.media ? `/api/media/${message.media.id}` : undefined}
        preload="metadata"
        onTimeUpdate={(e) => {
          const el = e.currentTarget;
          if (el.duration) setProgress(el.currentTime / el.duration);
        }}
        onEnded={() => {
          setPlaying(false);
          setProgress(0);
        }}
      />

      {/* job state + translated speech */}
      <div className="mt-2.5 flex flex-wrap items-center gap-2">
        {jobActive && (
          <span className="chip !border-cyanic-400/30 text-[9px] text-cyanic-300">
            <Loader2 className="size-2.5 animate-spin" />
            {JOB_LABELS[job.status] ?? job.status}
          </span>
        )}
        {job?.status === "partial" && (
          <span className="chip !border-ambery-400/30 text-[9px] text-ambery-400">
            <AlertTriangle className="size-2.5" />
            {JOB_LABELS.partial}
          </span>
        )}
        {translatedText && (
          <button
            onClick={toggleSpeech}
            className={`chip text-[9px] transition-all ${
              speaking
                ? "!border-mint-400/50 !bg-mint-400/15 text-mint-300"
                : "!border-iris-400/30 text-iris-300 hover:!bg-iris-500/15"
            }`}
          >
            {speaking ? <Pause className="size-2.5" /> : <Volume2 className="size-2.5" />}
            {speaking ? "Stop" : `Play in ${languageByCode(message.viewer.language)?.name ?? message.viewer.language}`}
          </button>
        )}
      </div>

      {/* transcript */}
      {message.originalText != null && message.originalText !== "" && (
        <div className={`mt-2.5 rounded-xl border px-3 py-2 ${isMine ? "border-white/15 bg-white/8" : "border-white/8 bg-white/4"}`} dir={langDef?.dir ?? "ltr"}>
          <p className="flex items-center gap-1.5 text-[8.5px] font-bold uppercase tracking-[0.14em] text-mist-500">
            <FileAudio className="size-2.5" />
            {translatedText && !showOriginal ? `translated transcript · ${transcriptLang}` : `original transcript · ${transcriptLang}`}
          </p>
          <p className="mt-1 text-[12.5px] leading-relaxed text-white/90">{transcript}</p>
          {translatedText && (
            <button
              className="mt-1 flex items-center gap-1 text-[8.5px] font-semibold uppercase tracking-wider text-iris-300 hover:text-white"
              onClick={() => onToggleOriginal(message.id)}
            >
              <Languages className="size-2.5" />
              {showOriginal ? "show translated" : "show original"}
            </button>
          )}
        </div>
      )}
    </div>
  );
}
