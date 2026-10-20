/**
 * Ephemeral typing indicators. Redis-backed in production; the single-process
 * deploy tier keeps them in memory with a short TTL.
 */
const TYPING_TTL_MS = 4000;

type TypingEntry = { name: string; expiresAt: number };

const globalTyping = globalThis as typeof globalThis & {
  __unicomTyping?: Map<string, Map<string, TypingEntry>>;
};
const store = (globalTyping.__unicomTyping ??= new Map());

export function recordTyping(conversationId: string, userId: string, name: string): void {
  let room = store.get(conversationId);
  if (!room) {
    room = new Map();
    store.set(conversationId, room);
  }
  room.set(userId, { name, expiresAt: Date.now() + TYPING_TTL_MS });
}

export function getTypers(conversationId: string, excludeUserId: string): string[] {
  const room = store.get(conversationId);
  if (!room) return [];
  const now = Date.now();
  const names: string[] = [];
  for (const [userId, entry] of room) {
    if (entry.expiresAt < now) {
      room.delete(userId);
      continue;
    }
    if (userId !== excludeUserId) names.push(entry.name);
  }
  return names;
}
