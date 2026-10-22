import { db } from "@/db";
import { conversationMembers } from "@/db/schema";
import { eq } from "drizzle-orm";
import { getSessionUser } from "@/lib/auth";
import { subscribe, type RealtimeEvent } from "@/lib/realtime";

export const dynamic = "force-dynamic";

/**
 * Server-Sent Events stream: authenticated, authorized per-conversation.
 *
 * The client opens one EventSource (or fetch stream) and receives only events
 * for conversations they belong to. Heartbeat every 25s keeps intermediaries
 * from closing the connection. Falls back gracefully — the polling sync
 * endpoint remains the offline safety net.
 */
export async function GET(request: Request) {
  const me = await getSessionUser();
  if (!me) return new Response("unauthorized", { status: 401 });

  const memberRows = await db
    .select({ conversationId: conversationMembers.conversationId })
    .from(conversationMembers)
    .where(eq(conversationMembers.userId, me.id));
  const myConversations = new Set(memberRows.map((r) => r.conversationId));

  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      let closed = false;
      const send = (event: RealtimeEvent) => {
        if (closed) return;
        const payload = JSON.stringify(event);
        try {
          controller.enqueue(encoder.encode(`data: ${payload}\n\n`));
        } catch {
          closed = true;
        }
      };

      // Greeting so the client knows it's live.
      send({ kind: "ping" });

      const unsubscribe = subscribe((event) => {
        // Call events are delivered only to their two participants.
        if (event.kind === "call") {
          if (!event.participants.includes(me.id)) return;
          send(event);
          return;
        }
        // Everything else is scoped to conversations the user belongs to.
        if ("conversationId" in event && event.conversationId) {
          if (!myConversations.has(event.conversationId)) return;
        }
        send(event);
      });

      const heartbeat = setInterval(() => send({ kind: "ping" }), 25_000);

      const cleanup = () => {
        if (closed) return;
        closed = true;
        clearInterval(heartbeat);
        unsubscribe();
        try {
          controller.close();
        } catch {
          /* already closed */
        }
      };

      request.signal.addEventListener("abort", cleanup);
    },
  });

  return new Response(stream, {
    headers: {
      "content-type": "text/event-stream; charset=utf-8",
      "cache-control": "no-cache, no-transform",
      connection: "keep-alive",
      "x-accel-buffering": "no",
    },
  });
}

export const runtime = "nodejs";
