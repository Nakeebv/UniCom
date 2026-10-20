"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowRight, Eye, EyeOff, Languages, Loader2, Lock, User, Waves } from "lucide-react";
import { LogoMark } from "@/components/landing/Landing";

const PERSONAS = [
  { username: "sofia", name: "Sofía Marín", lang: "Español", code: "es", hue: 28 },
  { username: "amara", name: "Amara Ọlánrewájú", lang: "Yorùbá", code: "yo", hue: 152 },
  { username: "pierre", name: "Pierre Dubois", lang: "Français", code: "fr", hue: 265 },
  { username: "ibrahim", name: "Ibrahim Sule", lang: "Hausa", code: "ha", hue: 330 },
  { username: "layla", name: "Layla Haddad", lang: "العربية", code: "ar", hue: 190 },
  { username: "alex", name: "Alex Rivera", lang: "English", code: "en", hue: 215 },
];

function Avatar({ name, hue, size = 38 }: { name: string; hue: number; size?: number }) {
  const initials = name
    .split(" ")
    .map((p) => p[0])
    .slice(0, 2)
    .join("");
  return (
    <div
      className="flex shrink-0 items-center justify-center rounded-full font-display font-bold text-white"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.36,
        background: `linear-gradient(140deg, hsl(${hue} 75% 55%), hsl(${hue + 40} 70% 42%))`,
      }}
    >
      {initials}
    </div>
  );
}

export function SignInForm() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ username, password }),
      });
      const data = (await res.json().catch(() => ({}))) as { error?: string };
      if (!res.ok) {
        setError(data.error ?? "Sign-in failed");
        setLoading(false);
        return;
      }
      router.push("/app");
      router.refresh();
    } catch {
      setError("Network error — please retry");
      setLoading(false);
    }
  }

  function quickLogin(persona: (typeof PERSONAS)[number]) {
    setUsername(persona.username);
    setPassword("demo12345");
    setError(null);
  }

  return (
    <div className="w-full">
      <form onSubmit={submit} className="space-y-3.5">
        <div className="relative">
          <User className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-mist-500" />
          <input
            className="field !pl-10"
            placeholder="Username"
            autoComplete="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
        </div>
        <div className="relative">
          <Lock className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-mist-500" />
          <input
            className="field !pl-10 !pr-10"
            placeholder="Password"
            type={showPassword ? "text" : "password"}
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <button
            type="button"
            onClick={() => setShowPassword((s) => !s)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-mist-500 transition-colors hover:text-white"
            aria-label="Toggle password visibility"
          >
            {showPassword ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
          </button>
        </div>
        {error && (
          <p className="animate-fade-in rounded-xl border border-rose-400/25 bg-rose-400/10 px-3.5 py-2.5 text-[12.5px] text-rose-300">
            {error}
          </p>
        )}
        <button type="submit" disabled={loading || !username || !password} className="btn-primary w-full py-3 text-[14px]">
          {loading ? <Loader2 className="size-4 animate-spin" /> : <ArrowRight className="size-4" />}
          Sign in to UniCom
        </button>
      </form>

      <div className="mt-8">
        <p className="flex items-center gap-2 text-[10.5px] font-bold uppercase tracking-[0.18em] text-mist-500">
          <Waves className="size-3.5 text-cyanic-300" />
          Demo personas · password “demo12345”
        </p>
        <div className="mt-3.5 grid grid-cols-2 gap-2">
          {PERSONAS.map((p) => (
            <button
              key={p.username}
              type="button"
              onClick={() => quickLogin(p)}
              className={`card-hover flex items-center gap-2.5 rounded-2xl border px-3 py-2.5 text-left transition-all ${
                username === p.username
                  ? "border-iris-400/50 bg-iris-500/10"
                  : "border-white/8 bg-white/[0.03] hover:border-white/20"
              }`}
            >
              <Avatar name={p.name} hue={p.hue} size={30} />
              <span className="min-w-0">
                <span className="block truncate text-[12px] font-semibold leading-tight">{p.name}</span>
                <span className="mt-0.5 flex items-center gap-1 text-[9.5px] font-medium uppercase tracking-wider text-mist-500">
                  <Languages className="size-2.5 text-iris-300" />
                  {p.lang}
                </span>
              </span>
            </button>
          ))}
        </div>
        <p className="mt-4 text-center text-[12.5px] text-mist-500">
          New here?{" "}
          <Link href="/register" className="font-semibold text-iris-300 transition-colors hover:text-white">
            Create an account
          </Link>
        </p>
      </div>
    </div>
  );
}

export function RegisterForm({ languages }: { languages: { code: string; name: string; nativeName: string; status: string }[] }) {
  const router = useRouter();
  const [form, setForm] = useState({
    username: "",
    displayName: "",
    password: "",
    confirm: "",
    preferredLanguage: "en",
  });
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  function set<K extends keyof typeof form>(key: K, value: string) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (form.password !== form.confirm) {
      setError("Passwords do not match");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/register", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          username: form.username,
          displayName: form.displayName,
          password: form.password,
          preferredLanguage: form.preferredLanguage,
        }),
      });
      const data = (await res.json().catch(() => ({}))) as { error?: string };
      if (!res.ok) {
        setError(data.error ?? "Registration failed");
        setLoading(false);
        return;
      }
      router.push("/app");
      router.refresh();
    } catch {
      setError("Network error — please retry");
      setLoading(false);
    }
  }

  return (
    <form onSubmit={submit} className="w-full space-y-3.5">
      <div>
        <label className="mb-1.5 block text-[11px] font-semibold uppercase tracking-wider text-mist-500">
          Display name
        </label>
        <input
          className="field"
          placeholder="Ada Lovelace"
          value={form.displayName}
          onChange={(e) => set("displayName", e.target.value)}
        />
      </div>
      <div>
        <label className="mb-1.5 block text-[11px] font-semibold uppercase tracking-wider text-mist-500">
          Username
        </label>
        <input
          className="field font-mono"
          placeholder="ada_l"
          autoComplete="username"
          value={form.username}
          onChange={(e) => set("username", e.target.value)}
        />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="mb-1.5 block text-[11px] font-semibold uppercase tracking-wider text-mist-500">
            Password
          </label>
          <div className="relative">
            <input
              className="field !pr-9"
              placeholder="8+ chars"
              type={showPassword ? "text" : "password"}
              autoComplete="new-password"
              value={form.password}
              onChange={(e) => set("password", e.target.value)}
            />
            <button
              type="button"
              onClick={() => setShowPassword((s) => !s)}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-mist-500 hover:text-white"
              aria-label="Toggle password visibility"
            >
              {showPassword ? <EyeOff className="size-3.5" /> : <Eye className="size-3.5" />}
            </button>
          </div>
        </div>
        <div>
          <label className="mb-1.5 block text-[11px] font-semibold uppercase tracking-wider text-mist-500">
            Confirm
          </label>
          <input
            className="field"
            placeholder="Repeat"
            type={showPassword ? "text" : "password"}
            autoComplete="new-password"
            value={form.confirm}
            onChange={(e) => set("confirm", e.target.value)}
          />
        </div>
      </div>
      <div>
        <label className="mb-1.5 flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider text-mist-500">
          <Languages className="size-3.5 text-iris-300" />
          My language — everything arrives in it
        </label>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {languages.map((lang) => (
            <button
              key={lang.code}
              type="button"
              onClick={() => set("preferredLanguage", lang.code)}
              className={`rounded-xl border px-3 py-2.5 text-left transition-all ${
                form.preferredLanguage === lang.code
                  ? "border-iris-400/60 bg-iris-500/12"
                  : "border-white/8 bg-white/[0.03] hover:border-white/20"
              }`}
            >
              <span className="block text-[12.5px] font-semibold">{lang.nativeName}</span>
              <span className="mt-0.5 block text-[10px] uppercase tracking-wider text-mist-500">
                {lang.name}
                {lang.status === "beta" ? " · beta" : ""}
              </span>
            </button>
          ))}
        </div>
      </div>
      {error && (
        <p className="animate-fade-in rounded-xl border border-rose-400/25 bg-rose-400/10 px-3.5 py-2.5 text-[12.5px] text-rose-300">
          {error}
        </p>
      )}
      <button type="submit" disabled={loading} className="btn-primary w-full py-3 text-[14px]">
        {loading ? <Loader2 className="size-4 animate-spin" /> : <ArrowRight className="size-4" />}
        Create account & enter UniCom
      </button>
      <p className="text-center text-[12.5px] text-mist-500">
        Already registered?{" "}
        <Link href="/sign-in" className="font-semibold text-iris-300 transition-colors hover:text-white">
          Sign in
        </Link>
      </p>
    </form>
  );
}

export function AuthShell({ children, title, subtitle }: { children: React.ReactNode; title: string; subtitle: string }) {
  return (
    <div className="noise relative flex min-h-screen items-center justify-center overflow-clip bg-ink-950 px-4 py-12">
      <div className="pointer-events-none absolute inset-0">
        <div className="grid-bg absolute inset-x-0 top-0 h-[600px]" />
        <div className="absolute -top-32 left-1/3 h-[420px] w-[640px] animate-aurora rounded-full bg-[radial-gradient(closest-side,rgba(124,92,255,0.2),transparent)] blur-3xl" />
        <div className="absolute bottom-[-10%] right-[8%] h-[360px] w-[480px] animate-aurora-2 rounded-full bg-[radial-gradient(closest-side,rgba(34,211,238,0.12),transparent)] blur-3xl" />
      </div>
      <div className="relative w-full max-w-md animate-fade-up">
        <Link href="/" className="mb-8 flex items-center justify-center gap-2.5">
          <LogoMark size={36} />
          <span className="font-display text-xl font-bold tracking-tight">UniCom</span>
        </Link>
        <div className="glass-deep rounded-3xl p-7 sm:p-8">
          <h1 className="font-display text-[22px] font-bold tracking-tight">{title}</h1>
          <p className="mt-1.5 text-[13px] leading-relaxed text-mist-500">{subtitle}</p>
          <div className="mt-6">{children}</div>
        </div>
      </div>
    </div>
  );
}
