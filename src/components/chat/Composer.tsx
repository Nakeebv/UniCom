"use client";

import { useEffect, useRef, useState } from "react";
import { AlertTriangle, Mic, Play, Pause, SendHorizonal, Square, Trash2, Waves } from "lucide-react";
import { languageByCode } from "@/lib/i18n/languages";
import { formatDuration, STT, waveBars, type SpeechRecognitionLike } from "./shared";

export type VoiceDraft = {
  base64: string;
  mimeType: string;
  durationMs: number;
  transcript: string;
};

export default function Composer({
  myLangCode,
  disabled,
  disabledReason,
  onTyping,
  onSendText,
  onSendVoice,
}: {
  myLangCode: string;
  disabled: boolean;
  disabledReason: string | null;
  onTyping: () => void;
  onSendText: (text: string) => void;
  onSendVoice: (draft: VoiceDraft) => void;
}) {
  const [text, setText] = useState("");
  const [recording, setRecording] = useState(false);
  const [recordMs, setRecordMs] = useState(0);
  const [draft, setDraft] = useState<(VoiceDraft & { url: string }) | null>(null);
  const [sttNotice, setSttNotice] = useState<string | null>(null);
  const [previewPlaying, setPreviewPlaying] = useState(false);
  const [micError, setMicError] = useState<string | null>(null);

  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const startTimeRef = useRef(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const transcriptRef = useRef("");
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const lastTypingRef = useRef(0);

  const langDef = languageByCode(myLangCode);
  const canStt = STT.supported() && (langDef?.capabilities.stt ?? false);

  useEffect(() => {
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      recorderRef.current?.stream.getTracks().forEach((t) => t.stop());
      recognitionRef.current?.abort();
    };
  }, []);

  function autoGrow() {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "0px";
    el.style.height = `${Math.min(el.scrollHeight, 140)}px`;
  }

  function handleChange(value: string) {
    setText(value);
    autoGrow();
    const now = Date.now();
    if (now - lastTypingRef.current > 1600 && value.trim()) {
      lastTypingRef.current = now;
      onTyping();
    }
  }

  function submitText() {
    const value = text.trim();
    if (!value || disabled) return;
    onSendText(value);
    setText("");
    requestAnimationFrame(autoGrow);
  }

  async function startRecording() {
    setMicError(null);
    setSttNotice(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mime = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
        ? "audio/webm;codecs=opus"
        : MediaRecorder.isTypeSupported("audio/mp4")
          ? "audio/mp4"
          : "";
      const recorder = new MediaRecorder(stream, mime ? { mimeType: mime } : undefined);
      recorderRef.current = recorder;
      chunksRef.current = [];
      transcriptRef.current = "";
      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };
      recorder.start(250);
      startTimeRef.current = Date.now();
      setRecordMs(0);
      timerRef.current = setInterval(() => setRecordMs(Date.now() - startTimeRef.current), 200);
      setRecording(true);

      if (canStt && langDef) {
        const recognition = STT.create(langDef.speechLocale);
        if (recognition) {
          recognitionRef.current = recognition;
          recognition.onresult = (event) => {
            let finalText = "";
            let interim = "";
            for (let i = 0; i < event.results.length; i++) {
              const result = event.results[i];
              if (result.isFinal) finalText += result[0].transcript + " ";
              else interim += result[0].transcript;
            }
            transcriptRef.current = (finalText + interim).trim();
          };
          recognition.onerror = () => setSttNotice("Browser transcription stopped — you can type the transcript instead.");
          try {
            recognition.start();
          } catch {
            /* browser refused — typed fallback remains */
          }
        }
      } else if (langDef && !langDef.capabilities.stt) {
        setSttNotice(
          `On-device transcription is not yet validated for ${langDef.name} (beta registry) — type the transcript so recipients still get a translation.`,
        );
      }
    } catch {
      setMicError("Microphone access was denied. Check browser permissions.");
    }
  }

  function stopRecording(save: boolean) {
    const recorder = recorderRef.current;
    if (!recorder) return;
    if (timerRef.current) clearInterval(timerRef.current);
    recognitionRef.current?.stop();
    const duration = Date.now() - startTimeRef.current;
    recorder.onstop = () => {
      recorder.stream.getTracks().forEach((t) => t.stop());
      if (!save) {
        setRecording(false);
        return;
      }
      const blob = new Blob(chunksRef.current, { type: recorder.mimeType || "audio/webm" });
      const reader = new FileReader();
      reader.onloadend = () => {
        const dataUrl = String(reader.result ?? "");
        const base64 = dataUrl.split(",")[1] ?? "";
        setDraft({
          base64,
          mimeType: recorder.mimeType || "audio/webm",
          durationMs: duration,
          transcript: transcriptRef.current,
          url: URL.createObjectURL(blob),
        });
      };
      reader.readAsDataURL(blob);
      setRecording(false);
    };
    recorder.stop();
  }

  function togglePreview() {
    const el = audioRef.current;
    if (!el) return;
    if (previewPlaying) {
      el.pause();
      setPreviewPlaying(false);
    } else {
      void el.play();
      setPreviewPlaying(true);
    }
  }

  function sendVoice() {
    if (!draft || disabled) return;
    onSendVoice({ base64: draft.base64, mimeType: draft.mimeType, durationMs: draft.durationMs, transcript: draft.transcript.trim() });
    URL.revokeObjectURL(draft.url);
    setDraft(null);
    setSttNotice(null);
  }

  /* ── voice draft preview ───────────────────────────────────────────────── */
  if (draft) {
    return (
      <div className="glass-deep animate-slide-up rounded-2xl p-4">
        <div className="flex items-center gap-3">
          <button
            onClick={togglePreview}
            className="flex size-10 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-iris-500 to-cyanic-400 text-white"
            aria-label="Preview recording"
          >
            {previewPlaying ? <Pause className="size-4" fill="currentColor" /> : <Play className="ml-0.5 size-4" fill="currentColor" />}
          </button>
          <div className="flex h-7 flex-1 items-center gap-[2.5px]">
            {waveBars(draft.base64.slice(0, 24), 26).map((b, i) => (
              <span key={i} className="w-[3px] rounded-full bg-iris-300/60" style={{ height: `${Math.max(16, b * 100)}%` }} />
            ))}
          </div>
          <span className="font-mono text-[10px] text-mist-400">{formatDuration(draft.durationMs)}</span>
          <audio ref={audioRef} src={draft.url} onEnded={() => setPreviewPlaying(false)} className="hidden" />
        </div>
        <div className="mt-3">
          <label className="mb-1.5 flex items-center gap-1.5 text-[9.5px] font-bold uppercase tracking-[0.16em] text-mist-500">
            <Waves className="size-3 text-cyanic-300" />
            Transcript · {langDef?.name ?? myLangCode} — recipients read & hear it translated
          </label>
          <textarea
            value={draft.transcript}
            onChange={(e) => setDraft({ ...draft, transcript: e.target.value })}
            placeholder={canStt ? "Listening transcript… edit if needed" : "Type what you said (enables translation + speech)"}
            className="field min-h-[56px] text-[13px]"
            dir={langDef?.dir ?? "ltr"}
          />
          {sttNotice && (
            <p className="mt-2 flex items-start gap-1.5 text-[11px] leading-relaxed text-ambery-400">
              <AlertTriangle className="mt-0.5 size-3 shrink-0" />
              {sttNotice}
            </p>
          )}
        </div>
        <div className="mt-3 flex justify-end gap-2">
          <button
            onClick={() => {
              URL.revokeObjectURL(draft.url);
              setDraft(null);
              setSttNotice(null);
            }}
            className="btn-ghost px-4 py-2 text-[12px] font-semibold"
          >
            <Trash2 className="size-3.5" />
            Discard
          </button>
          <button onClick={sendVoice} disabled={disabled} className="btn-primary px-5 py-2 text-[12.5px]">
            <SendHorizonal className="size-3.5" />
            Send voice note
          </button>
        </div>
      </div>
    );
  }

  /* ── composer bar ──────────────────────────────────────────────────────── */
  return (
    <div>
      {micError && (
        <p className="mb-2 flex items-center gap-1.5 rounded-xl border border-rose-400/25 bg-rose-400/10 px-3 py-2 text-[11.5px] text-rose-300">
          <AlertTriangle className="size-3.5" />
          {micError}
        </p>
      )}
      {disabled ? (
        <div className="glass-deep flex items-center justify-center gap-2 rounded-2xl px-4 py-3.5 text-[12.5px] text-mist-500">
          {disabledReason ?? "Messaging unavailable"}
        </div>
      ) : (
        <div className="glass-deep flex items-end gap-2 rounded-2xl p-2">
          {recording ? (
            <div className="flex min-w-0 flex-1 items-center gap-3 px-2.5 pb-1.5 pt-1">
              <span className="rec-pulse inline-block size-2.5 shrink-0 rounded-full bg-rose-400" />
              <span className="font-mono text-[12px] text-rose-300">{formatDuration(recordMs)}</span>
              <div className="flex h-6 flex-1 items-center gap-[3px] overflow-hidden">
                {Array.from({ length: 30 }).map((_, i) => (
                  <span
                    key={i}
                    className="wave-bar w-[3px] rounded-full bg-rose-400/70"
                    style={{ height: `${25 + ((i * 37) % 70)}%`, animationDelay: `${(i % 10) * 0.07}s` }}
                  />
                ))}
              </div>
              <span className="hidden text-[10px] uppercase tracking-wider text-mist-500 sm:block">
                {canStt ? "listening…" : "recording…"}
              </span>
            </div>
          ) : (
            <textarea
              ref={textareaRef}
              value={text}
              onChange={(e) => handleChange(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  submitText();
                }
              }}
              rows={1}
              placeholder={`Write in ${langDef?.nativeName ?? "your language"} — they'll read theirs…`}
              className="min-w-0 flex-1 resize-none bg-transparent px-3 py-2 text-[13.5px] outline-none placeholder:text-mist-600"
              dir={langDef?.dir ?? "ltr"}
            />
          )}

          {recording ? (
            <>
              <button
                onClick={() => stopRecording(false)}
                className="flex size-9 shrink-0 items-center justify-center rounded-xl border border-white/10 text-mist-400 transition-colors hover:text-white"
                aria-label="Cancel recording"
              >
                <Trash2 className="size-4" />
              </button>
              <button
                onClick={() => stopRecording(true)}
                className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-rose-400 text-white transition-transform active:scale-95"
                aria-label="Stop recording"
              >
                <Square className="size-3.5" fill="currentColor" />
              </button>
            </>
          ) : (
            <>
              <button
                onClick={startRecording}
                className="flex size-9 shrink-0 items-center justify-center rounded-xl border border-white/10 text-mist-400 transition-all hover:border-iris-400/40 hover:text-white active:scale-95"
                aria-label="Record a voice note"
                title="Record a voice note — transcribed, translated, synthesized"
              >
                <Mic className="size-4" />
              </button>
              <button
                onClick={submitText}
                disabled={!text.trim()}
                className="btn-primary !size-9 shrink-0 !rounded-xl !p-0"
                aria-label="Send message"
              >
                <SendHorizonal className="size-4" />
              </button>
            </>
          )}
        </div>
      )}
    </div>
  );
}
