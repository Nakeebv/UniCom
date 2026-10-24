/**
 * In-memory sliding-window rate limiter.
 *
 * Single-process tier: a Map keyed by bucket+identity, pruned lazily. Adequate
 * for the current deployment; swap `hit()` for Redis (INCR + EXPIRE) when the
 * API scales horizontally — the call sites don't change.
 */
type Entry = { count: number; resetAt: number };
const globalStore = globalThis as typeof globalThis & {
  __unicomRate?: Map<string, Entry>;
};
const store = (globalStore.__unicomRate ??= new Map());

export type RateRule = {
  /** Bucket name, e.g. "login". */
  name: string;
  /** Max requests inside the window. */
  limit: number;
  /** Window length in milliseconds. */
  windowMs: number;
};

export const RULES = {
  login: { name: "login", limit: 8, windowMs: 60_000 },
  register: { name: "register", limit: 5, windowMs: 60_000 },
  search: { name: "search", limit: 20, windowMs: 60_000 },
  callToken: { name: "callToken", limit: 10, windowMs: 60_000 },
  media: { name: "media", limit: 20, windowMs: 60_000 },
  send: { name: "send", limit: 60, windowMs: 60_000 },
  report: { name: "report", limit: 10, windowMs: 60_000 },
} satisfies Record<string, RateRule>;

/**
 * Demo/test accounts (comma-separated usernames in DEMO_ACCOUNTS). When
 * DEV_ALLOW_DEMO_UNLIMITED=true, these identities bypass rate limits so the
 * team can exercise full flows during QA. Off by default — production must
 * never set the flag. This affects ONLY rate limiting; authentication,
 * authorization, membership, and validation remain fully enforced.
 */
function demoFlagOn(): boolean {
  return (process.env.DEV_ALLOW_DEMO_UNLIMITED ?? "").toLowerCase() === "true";
}

function demoUsernames(): string[] {
  return (process.env.DEMO_ACCOUNTS ?? "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

const globalDemo = globalThis as typeof globalThis & {
  __demoIds?: Set<string>;
  __demoIdsAt?: number;
};

/** Resolves demo-account usernames → user ids (cached 5 min, dev only). */
export async function warmDemoIds(): Promise<void> {
  if (!demoFlagOn()) return;
  const usernames = demoUsernames();
  if (usernames.length === 0) return;
  if (globalDemo.__demoIds && Date.now() - (globalDemo.__demoIdsAt ?? 0) < 300_000) {
    return;
  }
  try {
    const { db } = await import("@/db");
    const { users } = await import("@/db/schema");
    const { inArray } = await import("drizzle-orm");
    const rows = await db
      .select({ id: users.id })
      .from(users)
      .where(inArray(users.username, usernames));
    globalDemo.__demoIds = new Set(rows.map((r) => r.id));
    globalDemo.__demoIdsAt = Date.now();
  } catch {
    globalDemo.__demoIds = new Set();
  }
}

export function isDemoUnlimited(identity: string): boolean {
  if (!demoFlagOn()) return false;
  const id = identity.toLowerCase();
  if (demoUsernames().some((d) => id === d || id.startsWith(`${d}:`) || id.endsWith(`:${d}`))) {
    return true;
  }
  return Boolean(globalDemo.__demoIds?.has(identity));
}

export type RateResult = {
  allowed: boolean;
  retryAfterSeconds: number;
  remaining: number;
};

/** Records a hit for `rule` scoped to `identity`. Returns whether allowed. */
export function hit(rule: RateRule, identity: string): RateResult {
  const key = `${rule.name}:${identity}`;
  const now = Date.now();
  const entry = store.get(key);

  if (!entry || entry.resetAt <= now) {
    store.set(key, { count: 1, resetAt: now + rule.windowMs });
    return { allowed: true, retryAfterSeconds: 0, remaining: rule.limit - 1 };
  }
  if (entry.count >= rule.limit) {
    return {
      allowed: false,
      retryAfterSeconds: Math.max(1, Math.ceil((entry.resetAt - now) / 1000)),
      remaining: 0,
    };
  }
  entry.count += 1;
  return {
    allowed: true,
    retryAfterSeconds: 0,
    remaining: rule.limit - entry.count,
  };
}

/** Client IP for keying anonymous routes (login/register). Behind Cloudflare
 *  the real client is in CF-Connecting-IP; fall back to XFF then a constant. */
export function clientIp(request: Request): string {
  const h = request.headers;
  return (
    h.get("cf-connecting-ip") ??
    h.get("x-real-ip") ??
    h.get("x-forwarded-for")?.split(",")[0].trim() ??
    "local"
  );
}

/** Periodic pruning so the map can't grow unbounded. */
const globalPrune = globalThis as typeof globalThis & { __unicomPrune?: ReturnType<typeof setInterval> };
if (!globalPrune.__unicomPrune) {
  globalPrune.__unicomPrune = setInterval(() => {
    const now = Date.now();
    for (const [k, v] of store) if (v.resetAt <= now) store.delete(k);
  }, 120_000);
  // Don't keep the process alive just for pruning.
  globalPrune.__unicomPrune.unref?.();
}

import { NextResponse } from "next/server";

/**
 * Enforces `rule` for `identity`; returns a 429 response when exceeded,
 * otherwise null (caller continues).
 */
export function enforce(
  rule: RateRule,
  identity: string,
): NextResponse | null {
  if (isDemoUnlimited(identity)) return null;
  const r = hit(rule, identity);
  if (r.allowed) return null;
  return NextResponse.json(
    { error: "Too many requests — please slow down and try again shortly." },
    {
      status: 429,
      headers: { "retry-after": String(r.retryAfterSeconds) },
    },
  );
}
