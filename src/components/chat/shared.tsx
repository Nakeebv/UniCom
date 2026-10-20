"use client";

import { languageByCode } from "@/lib/i18n/languages";

export function Avatar({
  name,
  hue,
  size = 38,
  online,
}: {
  name: string;
  hue: number;
  size?: number;
  online?: boolean;
}) {
  const initials = name
    .split(" ")
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join("")
    .toUpperCase();
  return (
    <div className="relative shrink-0" style={{ width: size, height: size }}>
      <div
        className="flex items-center justify-center rounded-full font-display font-bold text-white"
        style={{
          width: size,
          height: size,
          fontSize: size * 0.36,
          background: `linear-gradient(140deg, hsl(${hue} 72% 55%), hsl(${hue + 42} 68% 40%))`,
        }}
      >
        {initials}
      </div>
      {online !== undefined && (
        <span
          className={`absolute -bottom-0.5 -right-0.5 size-2.5 rounded-full border-2 border-ink-900 ${
            online ? "bg-mint-400" : "bg-mist-600"
          }`}
        />
      )}
    </div>
  );
}

export function LanguageChip({ code, className = "" }: { code: string; className?: string }) {
  const lang = languageByCode(code);
  return (
    <span
      className={`chip !py-0 !px-1.5 font-mono text-[8.5px] uppercase ${className}`}
      style={{ color: lang?.accent ?? "#a6adc1", borderColor: `${lang?.accent ?? "#a6adc1"}38` }}
      title={lang?.name ?? code}
    >
      {code}
    </span>
  );
}

export function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

export function formatDay(iso: string): string {
  const d = new Date(iso);
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  if (d.toDateString() === today.toDateString()) return "Today";
  if (d.toDateString() === yesterday.toDateString()) return "Yesterday";
  return d.toLocaleDateString([], { month: "short", day: "numeric" });
}

export function relativeLastSeen(iso: string | null): string {
  if (!iso) return "offline";
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return new Date(iso).toLocaleDateString([], { month: "short", day: "numeric" });
}

/** Deterministic pseudo-random waveform for voice notes. */
export function waveBars(seed: string, count = 22): number[] {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  const bars: number[] = [];
  for (let i = 0; i < count; i++) {
    h = (h * 1103515245 + 12345) >>> 0;
    const v = ((h >> 8) % 1000) / 1000;
    bars.push(0.25 + 0.75 * Math.abs(Math.sin(i * 0.8) * 0.5 + v * 0.5));
  }
  return bars;
}

export function formatDuration(ms: number | null | undefined): string {
  if (!ms) return "0:00";
  const total = Math.round(ms / 1000);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

export const STT = {
  supported(): boolean {
    return typeof window !== "undefined" && ("webkitSpeechRecognition" in window || "SpeechRecognition" in window);
  },
  create(langLocale: string) {
    const Ctor =
      (window as unknown as { SpeechRecognition?: new () => SpeechRecognitionLike }).SpeechRecognition ??
      (window as unknown as { webkitSpeechRecognition?: new () => SpeechRecognitionLike }).webkitSpeechRecognition;
    if (!Ctor) return null;
    const rec = new Ctor();
    rec.lang = langLocale;
    rec.continuous = true;
    rec.interimResults = true;
    return rec;
  },
};

export type SpeechRecognitionLike = {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onerror: (() => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
  abort: () => void;
};

export type SpeechRecognitionEventLike = {
  results: ArrayLike<{ isFinal: boolean; 0: { transcript: string } }>;
};

/** Pick the best on-device voice for a language (on-device TTS provider). */
export function pickVoice(langCode: string): SpeechSynthesisVoice | null {
  if (typeof speechSynthesis === "undefined") return null;
  const voices = speechSynthesis.getVoices();
  const exact = voices.find((v) => v.lang.toLowerCase().startsWith(langCode.toLowerCase()));
  return exact ?? null;
}

export function speak(text: string, langLocale: string, onEnd: () => void): boolean {
  if (typeof speechSynthesis === "undefined") return false;
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = langLocale;
  const prefix = langLocale.split("-")[0];
  const voice = pickVoice(prefix);
  if (voice) utterance.voice = voice;
  utterance.rate = 0.98;
  utterance.onend = onEnd;
  utterance.onerror = onEnd;
  speechSynthesis.cancel();
  speechSynthesis.speak(utterance);
  return true;
}
