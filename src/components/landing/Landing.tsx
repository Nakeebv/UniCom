"use client";

import Link from "next/link";
import {
  ArrowRight,
  AudioWaveform,
  Captions,
  FileAudio,
  Languages,
  Mic,
  MousePointerClick,
  ShieldCheck,
  Sparkles,
  Waves,
  Zap,
} from "lucide-react";
import HeroDemo from "@/components/landing/HeroDemo";
import Reveal from "@/components/Reveal";

export function LogoMark({ size = 36 }: { size?: number }) {
  return (
    <div
      className="relative flex items-center justify-center overflow-hidden rounded-[28%] bg-gradient-to-br from-iris-500 via-iris-400 to-cyanic-400 shadow-[0_8px_30px_-8px_rgba(124,92,255,0.7)]"
      style={{ width: size, height: size }}
    >
      <svg viewBox="0 0 24 24" width={size * 0.58} height={size * 0.58} fill="none" stroke="white" strokeWidth="2.1" strokeLinecap="round">
        <path d="M3 12h1.8M7.2 8.5v7M11 5.5v13M14.8 9v6M18.6 6.5v11M22 12h-0.8" opacity="0.95" />
      </svg>
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_20%,rgba(255,255,255,0.35),transparent_55%)]" />
    </div>
  );
}

const LANGUAGE_TAGS = [
  "Español", "Yorùbá", "Français", "Hausa", "العربية", "English", "Português",
  "es → yo", "fr → ha", "ar → en", "yo → es", "ha → fr", "en → ar", "pt → yo",
];

function Marquee() {
  const doubled = [...LANGUAGE_TAGS, ...LANGUAGE_TAGS];
  return (
    <div className="relative border-y border-white/6 bg-white/[0.015] py-5">
      <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-32 bg-gradient-to-r from-ink-950 to-transparent" />
      <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-32 bg-gradient-to-l from-ink-950 to-transparent" />
      <div className="flex w-max animate-marquee gap-3">
        {doubled.map((tag, i) => (
          <span
            key={`${tag}-${i}`}
            className="chip whitespace-nowrap !border-white/8 !py-1.5 !px-4 text-[11px] text-mist-400"
          >
            <Languages className="size-3 text-iris-300" />
            {tag}
          </span>
        ))}
      </div>
    </div>
  );
}

function FlowStep({
  index,
  icon,
  title,
  text,
  accent,
}: {
  index: string;
  icon: React.ReactNode;
  title: string;
  text: string;
  accent: string;
}) {
  return (
    <div className="glass card-hover relative overflow-hidden rounded-3xl p-6">
      <div className="absolute -right-6 -top-8 font-display text-[96px] font-bold leading-none text-white/[0.04]">
        {index}
      </div>
      <div
        className="mb-5 flex size-11 items-center justify-center rounded-2xl"
        style={{ background: `${accent}1f`, color: accent, border: `1px solid ${accent}40` }}
      >
        {icon}
      </div>
      <h3 className="font-display text-lg font-semibold">{title}</h3>
      <p className="mt-2 text-[13.5px] leading-relaxed text-mist-400">{text}</p>
    </div>
  );
}

const PIPELINE_STATES = [
  { label: "uploaded", tone: "text-mist-300 border-white/10" },
  { label: "queued", tone: "text-mist-300 border-white/10" },
  { label: "transcribing", tone: "text-cyanic-300 border-cyanic-400/30" },
  { label: "translating", tone: "text-iris-300 border-iris-400/30" },
  { label: "synthesizing", tone: "text-ambery-400 border-ambery-400/30" },
  { label: "completed", tone: "text-mint-300 border-mint-400/30" },
  { label: "failed_retryable", tone: "text-rose-400 border-rose-400/30" },
  { label: "partial", tone: "text-ambery-400 border-ambery-400/30" },
];

const PIPELINE_STEPS = [
  {
    icon: <Mic className="size-5" />,
    title: "Record",
    text: "The client captures audio and requests an authorized upload. Size, format and ownership are validated before it ever becomes a message.",
    accent: "#fb7185",
  },
  {
    icon: <Captions className="size-5" />,
    title: "Transcribe",
    text: "Speech-to-text produces the original transcript plus a detected language. Low confidence never silently passes as accurate.",
    accent: "#22d3ee",
  },
  {
    icon: <Languages className="size-5" />,
    title: "Translate",
    text: "One transcript fans out to exactly the target languages present in the conversation — never every language speculatively.",
    accent: "#8b7bff",
  },
  {
    icon: <AudioWaveform className="size-5" />,
    title: "Synthesize",
    text: "A natural voice in the recipient's language — not an imitation of the sender. Voice cloning stays a separate, consent-based capability.",
    accent: "#fbbf24",
  },
  {
    icon: <FileAudio className="size-5" />,
    title: "Deliver",
    text: "Recipients get original audio, translated transcript, generated speech and an explicit state for every step.",
    accent: "#34d399",
  },
];

const PROVIDER_CODE = `export interface SpeechToTextProvider {
  transcribe(input: { audioUrl: string; sourceLanguage?: string }):
    Promise<{ text: string; detectedLanguage?: string }>;
}

export interface TranslationProvider {
  translate(input: { text: string; sourceLanguage?: string; targetLanguage: string }):
    Promise<{ translatedText: string; detectedSourceLanguage?: string }>;
}

export interface TextToSpeechProvider {
  synthesize(input: { text: string; language: string; voiceId?: string }):
    Promise<{ audioBuffer: Uint8Array; contentType: string }>;
}`;

export default function Landing() {
  return (
    <div className="noise relative min-h-screen overflow-clip bg-ink-950">
      {/* ambient background */}
      <div className="pointer-events-none absolute inset-0">
        <div className="grid-bg absolute inset-x-0 top-0 h-[900px]" />
        <div className="absolute -top-40 left-1/2 h-[560px] w-[860px] -translate-x-1/2 animate-aurora rounded-full bg-[radial-gradient(closest-side,rgba(124,92,255,0.22),transparent)] blur-3xl" />
        <div className="absolute right-[-10%] top-[30%] h-[480px] w-[560px] animate-aurora-2 rounded-full bg-[radial-gradient(closest-side,rgba(34,211,238,0.13),transparent)] blur-3xl" />
        <div className="absolute left-[-12%] top-[62%] h-[420px] w-[520px] animate-aurora rounded-full bg-[radial-gradient(closest-side,rgba(52,211,153,0.1),transparent)] blur-3xl" />
      </div>

      {/* ── Nav ─────────────────────────────────────────────────────────── */}
      <header className="fixed inset-x-0 top-0 z-50">
        <div className="mx-auto mt-4 flex max-w-6xl items-center justify-between rounded-2xl border border-white/8 bg-ink-950/70 px-4 py-2.5 backdrop-blur-xl sm:px-5">
          <Link href="/" className="flex items-center gap-2.5">
            <LogoMark size={32} />
            <span className="font-display text-[17px] font-bold tracking-tight">UniCom</span>
            <span className="chip hidden !text-[9px] uppercase text-cyanic-300 sm:inline-flex">beta</span>
          </Link>
          <nav className="hidden items-center gap-7 text-[13px] font-medium text-mist-400 md:flex">
            <a href="#pipeline" className="transition-colors hover:text-white">Pipeline</a>
            <a href="#modules" className="transition-colors hover:text-white">Modules</a>
            <a href="#architecture" className="transition-colors hover:text-white">Architecture</a>
            <a href="#roadmap" className="transition-colors hover:text-white">Roadmap</a>
          </nav>
          <div className="flex items-center gap-2">
            <Link href="/sign-in" className="btn-ghost px-4 py-2 text-[13px] font-semibold">
              Sign in
            </Link>
            <Link href="/sign-in" className="btn-primary px-4 py-2 text-[13px]">
              Launch app
              <ArrowRight className="size-3.5" />
            </Link>
          </div>
        </div>
      </header>

      {/* ── Hero ────────────────────────────────────────────────────────── */}
      <section className="relative mx-auto grid max-w-6xl gap-14 px-5 pb-24 pt-36 sm:pt-44 lg:grid-cols-[1.05fr_0.95fr] lg:items-center">
        <div>
          <div className="animate-fade-up inline-flex items-center gap-2 rounded-full border border-iris-400/25 bg-iris-500/10 px-3.5 py-1.5 text-[11px] font-semibold tracking-wide text-iris-300">
            <Sparkles className="size-3.5" />
            Multilingual messaging, rebuilt around translation
          </div>
          <h1
            className="mt-6 animate-fade-up font-display text-[44px] font-bold leading-[1.02] tracking-[-0.03em] sm:text-[62px]"
            style={{ animationDelay: "80ms" }}
          >
            Speak your language.
            <br />
            <span className="text-grad">Be heard in theirs.</span>
          </h1>
          <p
            className="mt-6 max-w-xl animate-fade-up text-[15.5px] leading-relaxed text-mist-400 sm:text-[17px]"
            style={{ animationDelay: "160ms" }}
          >
            UniCom translates every message and voice note into each recipient&apos;s chosen language —
            automatically, asynchronously, and without ever touching the original. Seven launch
            languages, provider-agnostic AI, and delivery receipts end to end.
          </p>
          <div className="mt-9 flex animate-fade-up flex-wrap items-center gap-3" style={{ animationDelay: "240ms" }}>
            <Link href="/sign-in" className="btn-primary px-7 py-3.5 text-[14.5px]">
              Try the live demo
              <ArrowRight className="size-4" />
            </Link>
            <a href="#pipeline" className="btn-ghost px-6 py-3.5 text-[14px] font-semibold">
              <MousePointerClick className="size-4" />
              See the pipeline
            </a>
          </div>
          <div className="mt-12 grid max-w-md animate-fade-up grid-cols-3 gap-6" style={{ animationDelay: "320ms" }}>
            {[
              { value: "7", label: "launch languages" },
              { value: "3", label: "swappable AI providers" },
              { value: "v1+", label: "originals always preserved" },
            ].map((stat) => (
              <div key={stat.label}>
                <p className="font-display text-3xl font-bold text-grad">{stat.value}</p>
                <p className="mt-1 text-[11.5px] font-medium uppercase tracking-[0.12em] text-mist-500">
                  {stat.label}
                </p>
              </div>
            ))}
          </div>
        </div>

        <div className="relative animate-fade-up lg:animate-none" style={{ animationDelay: "240ms" }}>
          <div className="absolute -inset-8 rounded-[40px] bg-gradient-to-br from-iris-500/12 via-transparent to-cyanic-400/12 blur-2xl" />
          <div className="relative animate-float">
            <HeroDemo />
          </div>
          <div className="glass absolute -left-6 -top-6 hidden items-center gap-2 rounded-2xl px-3.5 py-2.5 sm:flex">
            <ShieldCheck className="size-4 text-mint-300" />
            <span className="text-[11px] font-semibold text-mist-300">Original preserved · v1</span>
          </div>
          <div className="glass absolute -bottom-5 -right-4 hidden items-center gap-2 rounded-2xl px-3.5 py-2.5 sm:flex">
            <Zap className="size-4 text-ambery-400" />
            <span className="text-[11px] font-semibold text-mist-300">p95 &lt; 2s translation target</span>
          </div>
        </div>
      </section>

      <Marquee />

      {/* ── How it flows ────────────────────────────────────────────────── */}
      <section className="relative mx-auto max-w-6xl px-5 py-24 sm:py-32">
        <Reveal>
          <p className="text-[11.5px] font-bold uppercase tracking-[0.22em] text-cyanic-300">The defining loop</p>
          <h2 className="mt-3 max-w-2xl font-display text-3xl font-bold tracking-tight sm:text-[42px] sm:leading-[1.1]">
            One canonical message.
            <span className="text-grad"> A language-specific rendering for everyone.</span>
          </h2>
          <p className="mt-4 max-w-2xl text-[15px] leading-relaxed text-mist-400">
            The original message is committed to PostgreSQL in one transaction and acknowledged instantly.
            Translation never delays delivery — it arrives as a separate, versioned asset moments later.
          </p>
        </Reveal>
        <div className="mt-12 grid gap-5 md:grid-cols-3">
          <Reveal delay={0}>
            <FlowStep
              index="01"
              icon={<Waves className="size-5" />}
              accent="#fbbf24"
              title="You write — or speak"
              text="Sofía types «Hola, ¿cómo estás?» or records a voice note. The backend authenticates, authorizes membership, deduplicates on the idempotency key, and commits."
            />
          </Reveal>
          <Reveal delay={120}>
            <FlowStep
              index="02"
              icon={<RefreshIcon />}
              accent="#8b7bff"
              title="Workers translate, async"
              text="A transactional outbox guarantees the translation job exists. The worker resolves each recipient's language and calls whichever translation provider is healthiest — with retries, backoff and a dead-letter policy."
            />
          </Reveal>
          <Reveal delay={240}>
            <FlowStep
              index="03"
              icon={<Languages className="size-5" />}
              accent="#34d399"
              title="They read and hear theirs"
              text="Amara reads «Báwo ni, ṣé dáadáa ni?» and can tap to reveal the Spanish original, play the original audio, or listen to synthesized Yorùbá speech."
            />
          </Reveal>
        </div>
      </section>

      {/* ── Voice pipeline ──────────────────────────────────────────────── */}
      <section id="pipeline" className="relative border-t border-white/6 bg-white/[0.013] py-24 sm:py-32">
        <div className="mx-auto max-w-6xl px-5">
          <Reveal>
            <div className="flex flex-wrap items-end justify-between gap-6">
              <div>
                <p className="text-[11.5px] font-bold uppercase tracking-[0.22em] text-iris-300">Voice processing</p>
                <h2 className="mt-3 max-w-xl font-display text-3xl font-bold tracking-tight sm:text-[42px] sm:leading-[1.1]">
                  A voice note is a pipeline, <span className="text-grad">not a file.</span>
                </h2>
              </div>
              <p className="max-w-md text-[14px] leading-relaxed text-mist-400">
                Every stage is an explicit, observable state. When AI providers degrade, audio stays playable
                and text stays readable — the app never pretends otherwise.
              </p>
            </div>
          </Reveal>

          <div className="mt-10 flex flex-wrap gap-2">
            {PIPELINE_STATES.map((s) => (
              <span key={s.label} className={`chip border !py-1 !px-3 font-mono text-[10.5px] ${s.tone}`}>
                {s.label}
              </span>
            ))}
          </div>

          <div className="mt-10 grid gap-5 md:grid-cols-2 lg:grid-cols-5">
            {PIPELINE_STEPS.map((stepItem, i) => (
              <Reveal key={stepItem.title} delay={i * 90}>
                <div className="glass card-hover relative h-full rounded-3xl p-5">
                  <div
                    className="mb-4 flex size-10 items-center justify-center rounded-xl"
                    style={{ background: `${stepItem.accent}1c`, color: stepItem.accent, border: `1px solid ${stepItem.accent}3d` }}
                  >
                    {stepItem.icon}
                  </div>
                  <h3 className="font-display text-[15px] font-semibold">{stepItem.title}</h3>
                  <p className="mt-2 text-[12px] leading-relaxed text-mist-500">{stepItem.text}</p>
                  {i < PIPELINE_STEPS.length - 1 && (
                    <div className="absolute -right-3 top-1/2 hidden h-px w-6 bg-gradient-to-r from-white/25 to-transparent lg:block" />
                  )}
                </div>
              </Reveal>
            ))}
          </div>

          <Reveal delay={100}>
            <div className="mt-12 grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
              <div className="glass-deep overflow-hidden rounded-3xl">
                <div className="flex items-center gap-2 border-b border-white/8 px-5 py-3">
                  <span className="size-2.5 rounded-full bg-rose-400/70" />
                  <span className="size-2.5 rounded-full bg-ambery-400/70" />
                  <span className="size-2.5 rounded-full bg-mint-400/70" />
                  <span className="ml-3 font-mono text-[11px] text-mist-500">packages/shared-types/providers.ts</span>
                </div>
                <pre className="scrollbar-thin overflow-x-auto p-5 font-mono text-[11.5px] leading-[1.75] text-mist-300">
                  {PROVIDER_CODE}
                </pre>
              </div>
              <div className="flex flex-col justify-center gap-5">
                <div className="glass rounded-3xl p-6">
                  <h3 className="flex items-center gap-2.5 font-display text-[17px] font-semibold">
                    <Mic className="size-4.5 text-rose-400" />
                    Provider-agnostic by contract
                  </h3>
                  <p className="mt-2.5 text-[13.5px] leading-relaxed text-mist-400">
                    Business logic talks to three interfaces, never to a vendor. This web build ships a working
                    set: browser speech recognition, a cascading translation adapter (MyMemory → Google → an offline
                    reviewed phrasebook), and on-device speech synthesis.
                  </p>
                </div>
                <div className="glass rounded-3xl p-6">
                  <h3 className="flex items-center gap-2.5 font-display text-[17px] font-semibold">
                    <AudioWaveform className="size-4.5 text-ambery-400" />
                    Generate on demand, reuse when safe
                  </h3>
                  <p className="mt-2.5 text-[13.5px] leading-relaxed text-mist-400">
                    Processing keys like <code className="font-mono text-[11px] text-cyanic-300">(message, target, sourceVersion, voice)</code>{" "}
                    prevent duplicate synthesis. A four-language group produces exactly four variants — or fewer when
                    recipients share a language.
                  </p>
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>
    </div>
  );
}

function RefreshIcon() {
  return (
    <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 12a9 9 0 1 1-3-6.7" />
      <path d="M21 3v6h-6" />
    </svg>
  );
}
