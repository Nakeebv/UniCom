/**
 * In-process realtime event bus + SSE fan-out.
 *
 * Single-process tier: a global subscriber set; each SSE connection registers
 * a listener and receives events for the conversations it is authorized to
 * see. Swap for Redis pub/sub (or the outbox → worker relay) when scaling
 * horizontally — publishers call `publish()` either way.
 */
export type RealtimeEvent =
  | { kind: "message"; conversationId: string; messageId: string; senderId: string }
  | { kind: "receipt"; conversationId: string; messageId: string }
  | { kind: "translation"; conversationId: string; messageId: string; targetLanguage: string; status: string }
  | { kind: "voice"; conversationId: string; messageId: string; status: string }
  | { kind: "typing"; conversationId: string; userId: string; name: string }
  | { kind: "call"; conversationId: string; callId: string; status: string }
  | { kind: "ping" };

type Listener = (event: RealtimeEvent) => void;

const globalBus = globalThis as typeof globalThis & {
  __unicomBus?: Set<Listener>;
};
const listeners = (globalBus.__unicomBus ??= new Set<Listener>());

export function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function publish(event: RealtimeEvent): void {
  for (const l of [...listeners]) {
    try {
      l(event);
    } catch {
      listeners.delete(l);
    }
  }
}

export function subscriberCount(): number {
  return listeners.size;
}
