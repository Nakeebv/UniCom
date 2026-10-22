import crypto from "node:crypto";
import { cookies } from "next/headers";
import type { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { sessions, userPreferences, users } from "@/db/schema";
import { newId, newToken } from "@/lib/ids";
import { DEFAULT_LANGUAGE } from "@/lib/i18n/languages";

export const SESSION_COOKIE = "unicom_session";
const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

/* Password hashing: scrypt w/ per-user salt (native module, no native deps). */
export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = crypto.scryptSync(password, salt, 64).toString("hex");
  return `s2$${salt}$${hash}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  const [, salt, hash] = stored.split("$");
  if (!salt || !hash) return false;
  const candidate = crypto.scryptSync(password, salt, 64);
  const expected = Buffer.from(hash, "hex");
  return candidate.length === expected.length && crypto.timingSafeEqual(candidate, expected);
}

export type SessionUser = {
  email?: string | null;
  emailVerified?: boolean;
  id: string;
  username: string;
  displayName: string;
  avatarHue: number;
  avatarUrl: string | null;
  bio: string | null;
  isPersona: boolean;
  preferredLanguage: string;
  speechLanguage: string | null;
  voiceId: string | null;
  showOriginal: boolean;
  lastSeenAt: Date | null;
};

export async function createUser(input: {
  username: string;
  displayName: string;
  password: string;
  email?: string | null;
  preferredLanguage?: string;
  avatarHue?: number;
  isPersona?: boolean;
  bio?: string;
}): Promise<string> {
  const id = newId("user");
  await db.insert(users).values({
    id,
    username: input.username,
    email: input.email ? input.email.toLowerCase() : null,
    displayName: input.displayName,
    passwordHash: hashPassword(input.password),
    avatarHue: input.avatarHue ?? Math.floor(Math.random() * 360),
    isPersona: input.isPersona ?? false,
    bio: input.bio ?? null,
    lastSeenAt: new Date(),
  });
  await db.insert(userPreferences).values({
    userId: id,
    preferredLanguage: input.preferredLanguage ?? DEFAULT_LANGUAGE,
    speechLanguage: input.preferredLanguage ?? DEFAULT_LANGUAGE,
  });
  return id;
}

export async function issueSession(userId: string): Promise<string> {
  const token = newToken();
  await db.insert(sessions).values({
    token,
    userId,
    expiresAt: new Date(Date.now() + SESSION_TTL_MS),
  });
  return token;
}

export function setSessionCookie(res: NextResponse, token: string): void {
  res.cookies.set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: SESSION_TTL_MS / 1000,
  });
}

export function clearSessionCookie(res: NextResponse): void {
  res.cookies.set(SESSION_COOKIE, "", { httpOnly: true, path: "/", maxAge: 0 });
}

export async function destroySession(token: string): Promise<void> {
  await db.delete(sessions).where(eq(sessions.token, token));
}

export async function getSessionUser(): Promise<SessionUser | null> {
  const store = await cookies();
  const token = store.get(SESSION_COOKIE)?.value;
  if (!token) return null;

  const rows = await db
    .select({
      id: users.id,
      username: users.username,
      displayName: users.displayName,
      avatarHue: users.avatarHue,
      avatarKey: users.avatarKey,
      email: users.email,
      emailVerifiedAt: users.emailVerifiedAt,
      bio: users.bio,
      isPersona: users.isPersona,
      lastSeenAt: users.lastSeenAt,
      expiresAt: sessions.expiresAt,
      preferredLanguage: userPreferences.preferredLanguage,
      speechLanguage: userPreferences.speechLanguage,
      voiceId: userPreferences.voiceId,
      showOriginal: userPreferences.showOriginal,
    })
    .from(sessions)
    .innerJoin(users, eq(users.id, sessions.userId))
    .innerJoin(userPreferences, eq(userPreferences.userId, users.id))
    .where(eq(sessions.token, token))
    .limit(1);

  const row = rows[0];
  if (!row) return null;
  if (row.expiresAt.getTime() < Date.now()) {
    await destroySession(token);
    return null;
  }
  return {
    id: row.id,
    username: row.username,
    displayName: row.displayName,
    avatarHue: row.avatarHue,
    email: row.email,
    emailVerified: !!row.emailVerifiedAt,
    avatarUrl: row.avatarKey ? `/api/users/${row.id}/avatar` : null,
    bio: row.bio,
    isPersona: row.isPersona,
    lastSeenAt: row.lastSeenAt,
    preferredLanguage: row.preferredLanguage,
    speechLanguage: row.speechLanguage,
    voiceId: row.voiceId,
    showOriginal: row.showOriginal,
  };
}

export async function getSessionToken(): Promise<string | null> {
  const store = await cookies();
  return store.get(SESSION_COOKIE)?.value ?? null;
}
