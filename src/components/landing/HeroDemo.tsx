"use client";

import { useEffect, useRef, useState } from "react";
import { Check, CheckCheck, Globe2, Languages, RefreshCcw } from "lucide-react";

type DemoMessage = {
  sender: string;
  hue: number;
  lang: string;
  texts: Record<string, string>;
};

const SCRIPT: DemoMessage[] = [
  {
    sender: "Sofía",
    hue: 28,
    lang: "es",
    texts: {
      es: "Hola, ¿cómo estás?",
      yo: "Báwo ni, ṣé dáadáa ni?",
      en: "Hello, how are you?",
      fr: "Salut, comment ça va ?",
    },
  },
  {
    sender: "Amara",
    hue: 152,
    lang: "yo",
    texts: {
      yo: "Ẹ káàrọ̀, sha daadaa ni",
      es: "Buenos días, todo bien",
      en: "Good morning, all good",
      fr: "Bonjour, tout va bien",
    },
  },
  {
    sender: "Sofía",
    hue: 28,
    lang: "es",
    texts: {
      es: "¿Nos vemos mañana a las diez?",
      yo: "Ǹjẹ́ a ó ríra lọ́la ní wákàtí mẹ́ẹ̀wáà?",
      en: "Shall we meet tomorrow at ten?",
      fr: "On se voit demain à dix heures ?",
    },
  },
  {
    sender: "Amara",
    hue: 152,
    lang: "yo",
    texts: {
      yo: "A ó ríra lọ́la. Ẹ ṣéú!",
      es: "Nos vemos mañana. ¡Gracias!",
      en: "See you tomorrow. Thanks!",
      fr: "À demain. Merci !",
    },
  },
];

const VIEWERS = [
  { code: "en", label: "You · English" },
  { code: "yo", label: "Amara · Yorùbá" },
  { code: "es", label: "Sofía · Español" },
  { code: "fr", label: "Pierre · Français" },
];

export default function HeroDemo() {
  const [viewer, setViewer] = useState("en");
  const [step, setStep] = useState(0);
  const [settledTick, setSettledTick] = useState(0);
  const [showOriginal, setShowOriginal] = useState<Record<string, boolean>>({});
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout>;
    if (step < SCRIPT.length) {
      timer = setTimeout(() => setStep((s) => s + 1), step === 0 ? 1100 : 2600);
    } else {
      timer = setTimeout(() => {
        setStep(0);
        setShowOriginal({});
      }, 6000);
    }
    return () => clearTimeout(timer);
  }, [step, viewer]);

  useEffect(() => {
    setSettledTick(0);
    const timer = setTimeout(() => setSettledTick(1), 1050);
    return () => clearTimeout(timer);
  }, [step, viewer]);

  useEffect(() => {
    const el = scrollRef.current;
    if (el) el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
  }, [step, settledTick, showOriginal]);

  const visible = SCRIPT.slice(0, step);

  return (
    <div className="glass-deep relative overflow-hidden rounded-3xl shadow-[0_40px_120px_-40px_rgba(124,92,255,0.45)]">
      {/* header */}
      <div className="flex items-center justify-between gap-3 border-b border-white/8 px-5 py-3.5">
        <div className="flex items-center gap-2.5">
          <div className="flex size-8 items-center justify-center rounded-xl bg-gradient-to-br from-iris-500 to-cyanic-400">
            <Languages className="size-4 text-white" strokeWidth={2.2} />
          </div>
          <div>
            <p className="font-display text-[13px] font-semibold leading-none">Sofía × Amara</p>
            <p className="mt-1 flex items-center gap-1.5 text-[10.5px] text-mint-300">
              <span className="inline-block size-1.5 rounded-full bg-mint-400 animate-pulse-soft" />
              live auto-translation
            </p>
          </div>
        </div>
        <div className="flex items-center gap-1 rounded-full border border-white/10 bg-white/4 p-1">
          {VIEWERS.map((v) => (
            <button
              key={v.code}
              onClick={() => {
                setViewer(v.code);
                setStep(0);
                setShowOriginal({});
              }}
              className={`rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wider transition-all ${
                viewer === v.code ? "bg-gradient-to-r from-iris-500 to-cyanic-400 text-white" : "text-mist-400 hover:text-white"
              }`}
            >
              {v.code}
            </button>
          ))}
        </div>
      </div>

      {/* messages */}
      <div ref={scrollRef} className="scrollbar-thin h-[300px] space-y-3.5 overflow-y-auto px-5 py-4 sm:h-[340px]">
        {visible.map((msg, i) => {
          const isLatest = i === visible.length - 1;
          const needsTranslation = msg.lang !== viewer;
          const translating = needsTranslation && isLatest && settledTick === 0;
          const text = needsTranslation && !showOriginal[i] ? msg.texts[viewer] : msg.texts[msg.lang];
          const mine = false;
          return (
            <div key={`${step > i ? "m" : "n"}-${i}`} className="animate-slide-up">
              <p className="mb-1 flex items-center gap-1.5 text-[10px] font-medium tracking-wide text-mist-500">
                <span className="inline-block size-1.5 rounded-full" style={{ background: `hsl(${msg.hue} 80% 60%)` }} />
                {msg.sender}
                <span className="chip !px-1.5 !py-0 text-[8.5px] uppercase">{msg.lang}</span>
              </p>
              <div className={`max-w-[85%] rounded-2xl rounded-tl-md px-3.5 py-2.5 ${mine ? "bubble-mine" : "bubble-theirs"}`}>
                {translating ? (
                  <div className="space-y-2 py-0.5">
                    <p className="text-[13.5px] leading-relaxed text-white/90">{msg.texts[msg.lang]}</p>
                    <div className="h-1.5 w-3/4 overflow-hidden rounded-full bg-white/6">
                      <div className="shimmer-line h-full w-full rounded-full" />
                    </div>
                    <p className="flex items-center gap-1 text-[9.5px] font-semibold uppercase tracking-wider text-cyanic-300">
                      <RefreshCcw className="size-2.5 animate-spin-slow" /> translating…
                    </p>
                  </div>
                ) : (
                  <>
                    <p className="text-[13.5px] leading-relaxed text-white/95">{text}</p>
                    <div className="mt-1.5 flex items-center justify-between gap-3">
                      {needsTranslation ? (
                        <button
                          onClick={() => setShowOriginal((prev) => ({ ...prev, [i]: !prev[i] }))}
                          className="flex items-center gap-1 text-[9.5px] font-semibold uppercase tracking-wider text-iris-300 transition-colors hover:text-white"
                        >
                          <Globe2 className="size-2.5" />
                          {showOriginal[i] ? `original · ${msg.lang}` : `translated · ${msg.lang}→${viewer}`}
                        </button>
                      ) : (
                        <span className="text-[9.5px] font-semibold uppercase tracking-wider text-mist-500">original</span>
                      )}
                      <span className="flex items-center gap-1 text-[9px] text-mist-500">
                        12:0{i}
                        <CheckCheck className="size-3 text-cyanic-400" />
                      </span>
                    </div>
                  </>
                )}
              </div>
            </div>
          );
        })}
        {step < SCRIPT.length && (
          <div className="flex items-center gap-1.5 pl-1 pt-1">
            <span className="typing-dot inline-block size-1.5 rounded-full bg-mist-400" />
            <span className="typing-dot inline-block size-1.5 rounded-full bg-mist-400" />
            <span className="typing-dot inline-block size-1.5 rounded-full bg-mist-400" />
          </div>
        )}
      </div>

      {/* composer hint */}
      <div className="border-t border-white/8 px-5 py-3">
        <div className="flex items-center gap-2 rounded-xl border border-white/8 bg-white/3 px-3.5 py-2.5">
          <p className="flex-1 text-[12px] text-mist-500">
            Write in {VIEWERS.find((v) => v.code === viewer)?.label.split("·")[1]?.trim() ?? "your language"} — they read theirs.
          </p>
          <Check className="size-3.5 text-mist-500" />
        </div>
      </div>
    </div>
  );
}
