/**
 * Idempotent demo seed: six personas spanning the launch languages, a direct
 * es↔yo conversation, and a four-language group. All seeded translations come
 * from the reviewed phrasebook so the demo renders correctly even fully offline.
 */
import { eq } from "drizzle-orm";
import { db } from "@/db";
import {
  conversationMembers,
  conversations,
  messageContents,
  messageReceipts,
  messages,
  messageTranslations,
  users,
} from "@/db/schema";
import { createUser } from "@/lib/auth";
import { newId } from "@/lib/ids";
import { PHRASEBOOK, phraseLookup } from "@/lib/i18n/phrasebook";

export const DEMO_PERSONAS = [
  { username: "sofia", displayName: "Sofía Marín", lang: "es", hue: 28, bio: "Product lead · Madrid" },
  { username: "amara", displayName: "Amara Ọlánrewájú", lang: "yo", hue: 152, bio: "Design · Lagos" },
  { username: "pierre", displayName: "Pierre Dubois", lang: "fr", hue: 265, bio: "Engineering · Lyon" },
  { username: "ibrahim", displayName: "Ibrahim Sule", lang: "ha", hue: 330, bio: "Operations · Kano" },
  { username: "layla", displayName: "Layla Haddad", lang: "ar", hue: 190, bio: "Research · Amman" },
  { username: "alex", displayName: "Alex Rivera", lang: "en", hue: 215, bio: "Mobile · Austin" },
] as const;

export const PERSONA_PASSWORD = "demo12345";

function phraseText(id: string, lang: string): string {
  const entry = PHRASEBOOK.find((p) => p.id === id);
  return entry?.texts[lang] ?? "";
}

let seeding: Promise<void> | null = null;

export function ensureSeed(): Promise<void> {
  seeding ??= doSeed().catch((err) => {
    console.error("[seed]", err);
    seeding = null;
  });
  return seeding;
}

async function doSeed(): Promise<void> {
  const [existing] = await db.select({ id: users.id }).from(users).limit(1);
  if (existing) return;

  const ids: Record<string, string> = {};
  for (const persona of DEMO_PERSONAS) {
    ids[persona.username] = await createUser({
      username: persona.username,
      displayName: persona.displayName,
      password: PERSONA_PASSWORD,
      preferredLanguage: persona.lang,
      avatarHue: persona.hue,
      bio: persona.bio,
      isPersona: true,
    });
  }

  const now = Date.now();
  const min = 60_000;

  async function addConversation(type: "direct" | "group", title: string | null, createdBy: string, memberIds: string[]) {
    const id = newId("conv");
    await db.insert(conversations).values({ id, type, title, createdBy });
    for (const memberId of memberIds) {
      await db.insert(conversationMembers).values({
        conversationId: id,
        userId: memberId,
        role: memberId === createdBy ? "admin" : "member",
      });
    }
    return id;
  }

  type SeedMessage = {
    sender: string;
    lang: string;
    phraseId: string;
    at: number;
    readBy: string[]; // usernames who have read it (besides sender)
  };

  async function addMessage(convId: string, memberUsernames: string[], seed: SeedMessage, targets: string[]) {
    const messageId = newId("msg");
    const createdAt = new Date(now - seed.at);
    const senderId = ids[seed.sender];
    const text = phraseText(seed.phraseId, seed.lang);

    await db.insert(messages).values({
      id: messageId,
      conversationId: convId,
      senderId,
      type: "text",
      sourceLanguage: seed.lang,
      createdAt,
    });
    await db.insert(messageContents).values({ messageId, originalText: text });

    for (const target of targets) {
      if (target === seed.lang) continue;
      const hit = phraseLookup(text, seed.lang, target);
      await db.insert(messageTranslations).values({
        id: newId("trl"),
        messageId,
        targetLanguage: target,
        translatedText: hit?.translatedText ?? null,
        status: hit ? "completed" : "failed",
        provider: hit ? "phrasebook-offline" : null,
        detail: hit ? "seed · reviewed phrasebook" : "untested pair",
        attempts: 1,
        sourceVersion: 1,
      });
    }

    for (const username of memberUsernames) {
      const memberId = ids[username];
      if (memberId === senderId) {
        await db.insert(messageReceipts).values({
          messageId,
          userId: memberId,
          deliveredAt: createdAt,
          readAt: createdAt,
        });
      } else {
        const read = seed.readBy.includes(username);
        await db.insert(messageReceipts).values({
          messageId,
          userId: memberId,
          deliveredAt: new Date(createdAt.getTime() + 4_000),
          readAt: read ? new Date(createdAt.getTime() + 45_000) : null,
        });
      }
    }
    return messageId;
  }

  /* Direct: Sofía (es) ↔ Amara (yo) */
  const direct = await addConversation("direct", null, ids.sofia, [ids.sofia, ids.amara]);
  await addMessage(direct, ["sofia", "amara"], { sender: "sofia", lang: "es", phraseId: "greet-how", at: 34 * min, readBy: ["amara"] }, ["yo"]);
  await addMessage(direct, ["sofia", "amara"], { sender: "amara", lang: "yo", phraseId: "how-are-you", at: 33 * min, readBy: ["sofia"] }, ["es"]);
  await addMessage(direct, ["sofia", "amara"], { sender: "sofia", lang: "es", phraseId: "meet-ten", at: 32 * min, readBy: ["amara"] }, ["yo"]);
  await addMessage(direct, ["sofia", "amara"], { sender: "amara", lang: "yo", phraseId: "see-tomorrow", at: 3 * min, readBy: [] }, ["es"]);
  await db
    .update(conversationMembers)
    .set({ lastReadAt: new Date(now - 5 * min) })
    .where(eq(conversationMembers.conversationId, direct));

  /* Group: Launch Crew — es, yo, fr, en */
  const group = await addConversation("group", "Launch Crew", ids.sofia, [ids.sofia, ids.amara, ids.pierre, ids.alex]);
  const groupMembers = ["sofia", "amara", "pierre", "alex"];
  await addMessage(group, groupMembers, { sender: "alex", lang: "en", phraseId: "good-morning", at: 3 * 62 * min, readBy: groupMembers }, ["es", "yo", "fr"]);
  await addMessage(group, groupMembers, { sender: "sofia", lang: "es", phraseId: "morning-project", at: 3 * 60 * min, readBy: groupMembers }, ["en", "yo", "fr"]);
  await addMessage(group, groupMembers, { sender: "alex", lang: "en", phraseId: "design-ready", at: 2 * 63 * min, readBy: groupMembers }, ["es", "yo", "fr"]);
  await addMessage(group, groupMembers, { sender: "pierre", lang: "fr", phraseId: "hello-everyone", at: 2 * 30 * min, readBy: groupMembers }, ["en", "es", "yo"]);
  await addMessage(group, groupMembers, { sender: "alex", lang: "en", phraseId: "update-after-call", at: 42 * min, readBy: [] }, ["es", "yo", "fr"]);
  await db
    .update(conversationMembers)
    .set({ lastReadAt: new Date(now - 90 * min) })
    .where(eq(conversationMembers.conversationId, group));

  console.log("[seed] personas + demo conversations created");
}
