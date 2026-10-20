"use client";

import Link from "next/link";
import {
  ArrowRight,
  BellRing,
  Blocks,
  CheckCircle2,
  CircleCheck,
  Database,
  Globe2,
  Layers,
  Lock,
  MessagesSquare,
  Radio,
  RefreshCcw,
  Server,
  ShieldCheck,
  Users,
  Workflow,
} from "lucide-react";
import Reveal from "@/components/Reveal";

/* ── Modules bento ────────────────────────────────────────────────────────── */

const MODULES = [
  {
    icon: <Users className="size-5" />,
    title: "Identity & profiles",
    text: "Registration, verification, sessions, devices, and privacy settings — plus preferred display, speech and voice preferences per user.",
    accent: "#8b7bff",
    span: "lg:col-span-2",
    points: ["Argon2id-grade hashing", "Session revocation", "Per-conversation overrides"],
  },
  {
    icon: <MessagesSquare className="size-5" />,
    title: "Messaging",
    text: "1:1 and group conversations, idempotent submission, delivery / read receipts, edits, deletion, replies and forwards.",
    accent: "#22d3ee",
    span: "",
    points: ["Sent · delivered · read", "Edit → version bump", "Soft-delete tombstones"],
  },
  {
    icon: <Globe2 className="size-5" />,
    title: "Translation engine",
    text: "Detection, recipient-language resolution, caching where privacy permits, and explicit state for every attempt.",
    accent: "#34d399",
    span: "",
    points: ["(message, lang, version) unique", "Original-text fallback", "Provider metadata logged"],
  },
  {
    icon: <Radio className="size-5" />,
    title: "Voice processing",
    text: "Validated uploads, transcription, transcript translation and target-language speech, each with durable job states.",
    accent: "#fbbf24",
    span: "",
    points: ["Explicit 8-state machine", "On-demand variants", "Original audio always playable"],
  },
  {
    icon: <BellRing className="size-5" />,
    title: "Notifications & presence",
    text: "Unread counts, typing indicators, online presence and last-seen — with previews that respect privacy settings.",
    accent: "#f472b6",
    span: "",
    points: ["Live presence heartbeat", "Typing indicators", "Cross-device sync token"],
  },
  {
    icon: <ShieldCheck className="size-5" />,
    title: "Trust & safety",
    text: "Reports, blocking, rate limits, provider health switches and an auditable moderation trail.",
    accent: "#fb7185",
    span: "lg:col-span-2",
    points: ["Block & report flows", "AI spend + failure dashboards", "Emergency provider disable"],
  },
];

/* ── Data model ───────────────────────────────────────────────────────────── */

const MSG_JSON = `{
  "id": "msg_01",
  "conversation_id": "conv_01",
  "sender_id": "user_spanish",
  "type": "text",
  "source_language": "es",
  "original_text": "Hola, ¿cómo estás?",
  "created_at": "2026-10-19T12:00:00Z",
  "version": 1
}`;

const TRL_JSON = `{
  "message_id": "msg_01",
  "target_language": "yo",
  "translated_text": "Báwo ni, ṣé dáadáa ni?",
  "status": "completed",
  "provider": "configured-translation-provider"
}`;

const INTEGRITY_RULES = [
  "Never replace the original message with a translation",
  "Target language stored explicitly on every translation",
  "Unique (message_id, target_language, source_version)",
  "Edits version the source and invalidate stale translations",
  "Status is explicit state — not the presence of a text field",
  "Provider metadata + duration recorded for cost analysis",
  "Storage keys and private records never leak to clients",
];

/* ── Architecture diagram ─────────────────────────────────────────────────── */

function ArchBox({
  icon,
  title,
  items,
  accent,
  className = "",
}: {
  icon: React.ReactNode;
  title: string;
  items: string[];
  accent: string;
  className?: string;
}) {
  return (
    <div className={`glass card-hover rounded-3xl p-5 ${className}`}>
      <div className="flex items-center gap-2.5">
        <div
          className="flex size-9 items-center justify-center rounded-xl"
          style={{ background: `${accent}1c`, color: accent, border: `1px solid ${accent}3d` }}
        >
          {icon}
        </div>
        <h3 className="font-display text-[14.5px] font-semibold">{title}</h3>
      </div>
      <ul className="mt-3 space-y-1.5">
        {items.map((item) => (
          <li key={item} className="flex items-start gap-2 text-[12px] text-mist-500">
            <span className="mt-1.5 inline-block size-1 shrink-0 rounded-full" style={{ background: accent }} />
            {item}
          </li>
        ))}
      </ul>
    </div>
  );
}

/* ── API + reliability tables ─────────────────────────────────────────────── */

const API_ROWS: { method: string; path: string; purpose: string; live?: boolean }[] = [
  { method: "POST", path: "/auth/register", purpose: "Create account, choose language", live: true },
  { method: "GET", path: "/languages", purpose: "Capability registry", live: true },
  { method: "POST", path: "/conversations", purpose: "Create 1:1 or group", live: true },
  { method: "GET", path: "/conversations/:id/messages", purpose: "Cursor-paginated history", live: true },
  { method: "POST", path: "/conversations/:id/messages", purpose: "Send text or voice note", live: true },
  { method: "POST", path: "/messages/:id/translations", purpose: "Request a target language", live: true },
  { method: "POST", path: "/media", purpose: "Authorized media upload", live: true },
  { method: "POST", path: "/messages/:id/reports", purpose: "Report abuse", live: true },
  { method: "POST", path: "/users/:id/block", purpose: "Block a user", live: true },
  { method: "WS", path: "message.created · translation.completed", purpose: "Live events (polling fallback today)", live: false },
];

const FAILURE_ROWS = [
  { failure: "Provider timeout", behavior: "Retry with exponential backoff + jitter" },
  { failure: "Unsupported pair", behavior: "Show original with a clear limitation chip" },
  { failure: "Speech recognition fails", behavior: "Original audio stays playable" },
  { failure: "TTS fails", behavior: "Translated text renders without audio" },
  { failure: "Duplicate queue event", behavior: "Idempotent processing key" },
  { failure: "Worker crash", behavior: "Resume from durable job rows" },
  { failure: "All AI offline", behavior: "Messaging continues; translations queue" },
];

/* ── Stack ────────────────────────────────────────────────────────────────── */

const STACK_ROWS = [
  { layer: "Mobile", tech: "React Native + Expo", note: "one codebase, iOS + Android" },
  { layer: "Web", tech: "Next.js + TypeScript", note: "this build — landing, messaging, settings" },
  { layer: "API", tech: "Modular TypeScript backend", note: "auth, messaging, permissions" },
  { layer: "Data", tech: "PostgreSQL", note: "source of truth for accounts, messages, jobs" },
  { layer: "Realtime", tech: "WebSockets / event sync", note: "delivery, typing, translation-ready" },
  { layer: "Workers", tech: "Queue + background jobs", note: "translation and voice pipelines" },
  { layer: "Media", tech: "Private object storage", note: "voice notes and attachments" },
  { layer: "AI", tech: "Pluggable STT · MT · TTS", note: "vendor-agnostic adapters" },
];

/* ── Roadmap / MVP / decisions ────────────────────────────────────────────── */

const ROADMAP = [
  { n: "01", title: "Foundation & auth", text: "Monorepo, database, sessions, language preferences, API validation.", done: true },
  { n: "02", title: "Core chat", text: "Conversations, persistence, event delivery, receipts, blocking.", done: true },
  { n: "03", title: "Auto text translation", text: "Provider adapter, queue, language resolution, original toggle.", done: true },
  { n: "04", title: "Voice notes & speech", text: "Secure uploads, transcription, synthesized target-language audio.", done: true },
  { n: "05", title: "Production readiness", text: "Push, recovery, monitoring, cost limits, security testing, beta.", done: false },
];

const MVP_ITEMS = [
  "Registration & secure login",
  "One-to-one messaging",
  "Preferred language settings",
  "Automatic translated text",
  "View original message",
  "Voice-note recording & playback",
  "Transcription & translated audio",
  "Delivery & read receipts",
  "Push-style notifications",
  "Block & report users",
  "Usage limits & error states",
];

const DECISIONS = [
  "Translated by default, original one tap away",
  "Few tested pairs over universal claims",
  "Server-processed translation, never advertised as E2E",
  "Neutral synthetic voice — never sender imitation by default",
  "Per-user and global AI spend limits",
  "Version translations; never mutate the original",
  "Chat survives total AI provider outage",
];

export default function LandingRest() {
  return (
    <div className="noise relative bg-ink-950">
      {/* ── Modules ─────────────────────────────────────────────────────── */}
      <section id="modules" className="relative mx-auto max-w-6xl px-5 py-24 sm:py-32">
        <Reveal>
          <p className="text-[11.5px] font-bold uppercase tracking-[0.22em] text-mint-300">Modular monolith</p>
          <h2 className="mt-3 max-w-2xl font-display text-3xl font-bold tracking-tight sm:text-[42px] sm:leading-[1.1]">
            Six modules. One backend. <span className="text-grad">Zero rewrites ahead.</span>
          </h2>
          <p className="mt-4 max-w-2xl text-[15px] leading-relaxed text-mist-400">
            API, messaging, language and identity ship together; workers run separately because audio
            processing needs independent scaling. Each module can split into a service when traffic justifies it.
          </p>
        </Reveal>
        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {MODULES.map((m, i) => (
            <Reveal key={m.title} delay={(i % 3) * 90} className={m.span}>
              <div className="glass card-hover h-full rounded-3xl p-6">
                <div className="flex items-center gap-3">
                  <div
                    className="flex size-10 items-center justify-center rounded-xl"
                    style={{ background: `${m.accent}1c`, color: m.accent, border: `1px solid ${m.accent}3d` }}
                  >
                    {m.icon}
                  </div>
                  <h3 className="font-display text-[16px] font-semibold">{m.title}</h3>
                </div>
                <p className="mt-3 text-[13px] leading-relaxed text-mist-400">{m.text}</p>
                <div className="mt-4 flex flex-wrap gap-1.5">
                  {m.points.map((p) => (
                    <span key={p} className="chip !py-0.5 text-[9.5px] text-mist-400">
                      {p}
                    </span>
                  ))}
                </div>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      {/* ── Data model ──────────────────────────────────────────────────── */}
      <section className="relative border-t border-white/6 bg-white/[0.013] py-24 sm:py-32">
        <div className="mx-auto max-w-6xl px-5">
          <Reveal>
            <p className="text-[11.5px] font-bold uppercase tracking-[0.22em] text-ambery-400">Data integrity</p>
            <h2 className="mt-3 max-w-2xl font-display text-3xl font-bold tracking-tight sm:text-[42px] sm:leading-[1.1]">
              The original is sacred. <span className="text-grad-warm">Translations are assets.</span>
            </h2>
          </Reveal>
          <div className="mt-12 grid gap-6 lg:grid-cols-2">
            <Reveal>
              <div className="glass-deep overflow-hidden rounded-3xl">
                <div className="flex items-center justify-between border-b border-white/8 px-5 py-3">
                  <span className="font-mono text-[11px] text-mist-500">messages · canonical record</span>
                  <span className="chip !py-0.5 text-[9px] text-cyanic-300">never mutated</span>
                </div>
                <pre className="overflow-x-auto p-5 font-mono text-[11.5px] leading-[1.8] text-mist-300">{MSG_JSON}</pre>
              </div>
            </Reveal>
            <Reveal delay={120}>
              <div className="glass-deep overflow-hidden rounded-3xl">
                <div className="flex items-center justify-between border-b border-white/8 px-5 py-3">
                  <span className="font-mono text-[11px] text-mist-500">message_translations · per language</span>
                  <span className="chip !py-0.5 text-[9px] text-mint-300">versioned asset</span>
                </div>
                <pre className="overflow-x-auto p-5 font-mono text-[11.5px] leading-[1.8] text-mist-300">{TRL_JSON}</pre>
              </div>
            </Reveal>
          </div>
          <Reveal delay={80}>
            <div className="glass mt-6 rounded-3xl p-6 sm:p-8">
              <h3 className="font-display text-[16px] font-semibold">Seven integrity rules, enforced in schema</h3>
              <div className="mt-5 grid gap-x-8 gap-y-3 sm:grid-cols-2">
                {INTEGRITY_RULES.map((rule) => (
                  <p key={rule} className="flex items-start gap-2.5 text-[13px] leading-relaxed text-mist-400">
                    <CheckCircle2 className="mt-0.5 size-4 shrink-0 text-mint-400" />
                    {rule}
                  </p>
                ))}
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ── Architecture ────────────────────────────────────────────────── */}
      <section id="architecture" className="relative mx-auto max-w-6xl px-5 py-24 sm:py-32">
        <Reveal>
          <p className="text-[11.5px] font-bold uppercase tracking-[0.22em] text-cyanic-300">System shape</p>
          <h2 className="mt-3 max-w-2xl font-display text-3xl font-bold tracking-tight sm:text-[42px] sm:leading-[1.1]">
            Event-driven, but <span className="text-grad">boring where it counts.</span>
          </h2>
          <p className="mt-4 max-w-2xl text-[15px] leading-relaxed text-mist-400">
            Logical components, not mandatory microservices. The transactional outbox sits between
            {` `}“message saved” and “job queued” so nothing is ever acknowledged without its follow-up work.
          </p>
        </Reveal>
        <div className="mt-12 grid gap-5 lg:grid-cols-3">
          <Reveal>
            <ArchBox
              icon={<Layers className="size-4.5" />}
              accent="#8b7bff"
              title="Clients"
              items={["iOS · Android · Web · Desktop later", "HTTPS · WebSocket · WebRTC when needed", "Deduplicate events, fetch authoritative state"]}
            />
          </Reveal>
          <Reveal delay={90}>
            <ArchBox
              icon={<Server className="size-4.5" />}
              accent="#22d3ee"
              title="API gateway"
              items={["Authentication & sessions", "Rate limits + validation", "Versioned REST prefix /api/v1-style"]}
            />
          </Reveal>
          <Reveal delay={180}>
            <ArchBox
              icon={<Workflow className="size-4.5" />}
              accent="#34d399"
              title="Domain modules"
              items={["Messaging · receipts · access control", "Language · preferences · detection", "Voice · transcription · synthesis", "Identity · blocks · reports · privacy"]}
            />
          </Reveal>
          <Reveal delay={120}>
            <ArchBox
              icon={<Radio className="size-4.5" />}
              accent="#fbbf24"
              title="Event queue + workers"
              items={["Transactional outbox publisher", "Translation jobs · audio jobs", "Bounded retries · dead-letter queue", "Independent scaling by queue depth"]}
            />
          </Reveal>
          <Reveal delay={210}>
            <ArchBox
              icon={<Database className="size-4.5" />}
              accent="#f472b6"
              title="Persistence"
              items={["PostgreSQL — source of truth", "Redis — cache, presence, limits", "Private object storage — audio & attachments"]}
            />
          </Reveal>
          <Reveal delay={300}>
            <ArchBox
              icon={<RefreshCcw className="size-4.5" />}
              accent="#fb7185"
              title="External AI providers"
              items={["Speech recognition (STT)", "Machine translation (MT)", "Text-to-speech (TTS)", "Health monitors + disable switches"]}
            />
          </Reveal>
        </div>
        <Reveal delay={100}>
          <div className="mt-6 grid gap-5 md:grid-cols-2">
            <div className="glass flex items-start gap-4 rounded-3xl p-6">
              <Lock className="mt-1 size-5 shrink-0 text-iris-300" />
              <div>
                <h3 className="font-display text-[15.5px] font-semibold">Honest privacy model</h3>
                <p className="mt-1.5 text-[13px] leading-relaxed text-mist-400">
                  UniCom uses server-processed translation: content is protected in transit and at rest,
                  but the server can access it to translate. It is never advertised as end-to-end encrypted.
                </p>
              </div>
            </div>
            <div className="glass flex items-start gap-4 rounded-3xl p-6">
              <Blocks className="mt-1 size-5 shrink-0 text-mint-300" />
              <div>
                <h3 className="font-display text-[15.5px] font-semibold">Authorized, not just identifiable</h3>
                <p className="mt-1.5 text-[13px] leading-relaxed text-mist-400">
                  Every endpoint, event and media URL checks membership. A conversation id is never an
                  access credential.
                </p>
              </div>
            </div>
          </div>
        </Reveal>
      </section>

      {/* ── API + reliability ───────────────────────────────────────────── */}
      <section className="relative border-t border-white/6 bg-white/[0.013] py-24 sm:py-32">
        <div className="mx-auto max-w-6xl px-5">
          <div className="grid gap-10 lg:grid-cols-[1.05fr_0.95fr]">
            <Reveal>
              <div>
                <p className="text-[11.5px] font-bold uppercase tracking-[0.22em] text-iris-300">API surface</p>
                <h3 className="mt-3 font-display text-2xl font-bold tracking-tight sm:text-3xl">
                  Versioned, validated, <span className="text-grad">idempotent.</span>
                </h3>
                <div className="glass-deep mt-6 overflow-hidden rounded-3xl">
                  {API_ROWS.map((row, i) => (
                    <div
                      key={row.path + i}
                      className={`flex items-center gap-3 px-5 py-3 ${i % 2 === 1 ? "bg-white/[0.022]" : ""}`}
                    >
                      <span
                        className={`chip w-12 justify-center !px-0 font-mono text-[9.5px] ${
                          row.method === "WS" ? "text-ambery-400" : row.method === "GET" ? "text-cyanic-300" : "text-iris-300"
                        }`}
                      >
                        {row.method}
                      </span>
                      <code className="flex-1 truncate font-mono text-[11px] text-mist-300">{row.path}</code>
                      <span className="hidden text-[11px] text-mist-500 md:block">{row.purpose}</span>
                      {row.live && (
                        <span className="chip !border-mint-400/30 !py-0 text-[8.5px] text-mint-300">live here</span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </Reveal>
            <Reveal delay={140}>
              <div>
                <p className="text-[11.5px] font-bold uppercase tracking-[0.22em] text-mint-300">Reliability</p>
                <h3 className="mt-3 font-display text-2xl font-bold tracking-tight sm:text-3xl">
                  Failure is a <span className="text-grad">first-class state.</span>
                </h3>
                <div className="glass-deep mt-6 overflow-hidden rounded-3xl">
                  {FAILURE_ROWS.map((row, i) => (
                    <div key={row.failure} className={`flex gap-4 px-5 py-3.5 ${i % 2 === 1 ? "bg-white/[0.022]" : ""}`}>
                      <span className="w-40 shrink-0 text-[12px] font-semibold text-rose-400/90">{row.failure}</span>
                      <span className="text-[12px] leading-relaxed text-mist-400">{row.behavior}</span>
                    </div>
                  ))}
                </div>
              </div>
            </Reveal>
          </div>

          <Reveal delay={80}>
            <div className="glass mt-10 rounded-3xl p-6 sm:p-8">
              <h3 className="font-display text-[16px] font-semibold">Recommended stack — and what runs here</h3>
              <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                {STACK_ROWS.map((row) => (
                  <div key={row.layer} className="rounded-2xl border border-white/8 bg-white/[0.02] p-4">
                    <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-mist-500">{row.layer}</p>
                    <p className="mt-1.5 font-display text-[13.5px] font-semibold text-mist-200">{row.tech}</p>
                    <p className="mt-1 text-[11px] leading-snug text-mist-500">{row.note}</p>
                  </div>
                ))}
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ── Roadmap ─────────────────────────────────────────────────────── */}
      <section id="roadmap" className="relative mx-auto max-w-6xl px-5 py-24 sm:py-32">
        <div className="grid gap-12 lg:grid-cols-[0.95fr_1.05fr]">
          <Reveal>
            <div>
              <p className="text-[11.5px] font-bold uppercase tracking-[0.22em] text-cyanic-300">Build order</p>
              <h3 className="mt-3 font-display text-2xl font-bold tracking-tight sm:text-3xl">
                Defining feature early, <span className="text-grad">infrastructure late.</span>
              </h3>
              <div className="relative mt-8 space-y-2 border-l border-white/10 pl-0">
                {ROADMAP.map((r) => (
                  <div key={r.n} className="group relative flex gap-5 py-3 pl-8">
                    <span
                      className={`absolute -left-[7px] top-5 size-3.5 rounded-full border-2 ${
                        r.done ? "border-mint-400 bg-mint-400/30" : "border-iris-400 bg-ink-950"
                      }`}
                    />
                    <span className="font-display text-[13px] font-bold text-mist-500">{r.n}</span>
                    <div>
                      <p className="flex items-center gap-2 font-display text-[15px] font-semibold">
                        {r.title}
                        {r.done && <CircleCheck className="size-3.5 text-mint-400" />}
                      </p>
                      <p className="mt-1 text-[12.5px] leading-relaxed text-mist-500">{r.text}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </Reveal>
          <div className="space-y-6">
            <Reveal delay={100}>
              <div className="glass rounded-3xl p-6 sm:p-8">
                <h3 className="font-display text-[16px] font-semibold">MVP checklist — shipped in this build</h3>
                <div className="mt-5 grid gap-x-6 gap-y-2.5 sm:grid-cols-2">
                  {MVP_ITEMS.map((item) => (
                    <p key={item} className="flex items-center gap-2.5 text-[13px] text-mist-300">
                      <CheckCircle2 className="size-4 shrink-0 text-mint-400" />
                      {item}
                    </p>
                  ))}
                </div>
              </div>
            </Reveal>
            <Reveal delay={200}>
              <div className="glass rounded-3xl p-6 sm:p-8">
                <h3 className="font-display text-[16px] font-semibold">Decisions locked before launch</h3>
                <div className="mt-5 space-y-2.5">
                  {DECISIONS.map((item, i) => (
                    <p key={item} className="flex items-start gap-3 text-[13px] leading-relaxed text-mist-400">
                      <span className="font-mono text-[11px] font-semibold text-iris-300">{String(i + 1).padStart(2, "0")}</span>
                      {item}
                    </p>
                  ))}
                </div>
              </div>
            </Reveal>
          </div>
        </div>
      </section>

      {/* ── CTA + footer ────────────────────────────────────────────────── */}
      <section className="relative border-t border-white/6">
        <div className="pointer-events-none absolute inset-0">
          <div className="absolute bottom-0 left-1/2 h-[380px] w-[720px] -translate-x-1/2 animate-aurora rounded-full bg-[radial-gradient(closest-side,rgba(124,92,255,0.18),transparent)] blur-3xl" />
        </div>
        <div className="relative mx-auto max-w-6xl px-5 py-28 text-center sm:py-36">
          <Reveal>
            <h2 className="mx-auto max-w-3xl font-display text-4xl font-bold leading-[1.05] tracking-tight sm:text-6xl">
              The conversation is global. <span className="text-grad">So is every reply.</span>
            </h2>
            <p className="mx-auto mt-6 max-w-xl text-[15.5px] leading-relaxed text-mist-400">
              Sign in as one of six personas — Sofía writes in Spanish, Amara answers in Yorùbá,
              Pierre in French — and watch every rendering land in your language.
            </p>
            <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
              <Link href="/sign-in" className="btn-primary px-8 py-4 text-[15px]">
                Open the web app
                <ArrowRight className="size-4" />
              </Link>
              <Link href="/register" className="btn-ghost px-7 py-4 text-[14.5px] font-semibold">
                Create an account
              </Link>
            </div>
            <p className="mt-6 font-mono text-[11px] text-mist-500">
              demo personas: sofia · amara · pierre · ibrahim · layla · alex — password “demo12345”
            </p>
          </Reveal>
        </div>
        <footer className="relative border-t border-white/6 py-8">
          <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-5">
            <p className="flex items-center gap-2.5 text-[13px] text-mist-500">
              <span className="font-display font-bold text-white">UniCom</span>
              Unified Global Communications
            </p>
            <p className="font-mono text-[10.5px] text-mist-600">
              originals preserved · translations versioned · providers swappable
            </p>
          </div>
        </footer>
      </section>
    </div>
  );
}
