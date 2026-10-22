import { NextResponse } from "next/server";
import { db } from "@/db";
import { conversationMembers, userBlocks } from "@/db/schema";
import { and, eq } from "drizzle-orm";
import { getSessionUser } from "@/lib/auth";
import { livekitConfigured, livekitUrl, mintCallToken } from "@/lib/livekit";
import { RULES, enforce } from "@/lib/rate-limit";

/** Server-minted, room-scoped LiveKit access token (5-min TTL).
 *  Caller must be authenticated; peer must exist in an allowed direct
 *  conversation; blocking is enforced before any grant. */
export async function POST(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const limited = enforce(RULES.callToken, me.id);
  if (limited) return limited;
  if (!livekitConfigured()) {
    return NextResponse.json({ error: "Calling is not configured on this server" }, { status: 503 });
  }
  const body = (await request.json().catch(() => null)) as {
    peerId?: string; room?: string; callType?: "audio" | "video"; conversationId?: string;
  } | null;
  const peerId = body?.peerId ?? "";
  const room = (body?.room ?? "").trim().slice(0, 80);
  const callType = body?.callType === "video" ? "video" : "audio";
  if (!peerId || !room) return NextResponse.json({ error: "peerId and room are required" }, { status: 400 });

  // Authorization: must share a conversation with the peer, and not be blocked.
  const memberConvs = await db
    .select({ conversationId: conversationMembers.conversationId })
    .from(conversationMembers)
    .where(eq(conversationMembers.userId, me.id));
  const convIds = memberConvs.map((r) => r.conversationId);
  let shared = false;
  for (const cid of convIds) {
    const others = await db
      .select({ userId: conversationMembers.userId })
      .from(conversationMembers)
      .where(and(eq(conversationMembers.conversationId, cid), eq(conversationMembers.userId, peerId)));
    if (others.length > 0) { shared = true; break; }
  }
  if (!shared) return NextResponse.json({ error: "forbidden" }, { status: 403 });

  const blocks = await db
    .select()
    .from(userBlocks)
    .where(and(
      eq(userBlocks.blockerId, me.id), eq(userBlocks.blockedId, peerId)
    ));
  const blocks2 = await db
    .select()
    .from(userBlocks)
    .where(and(
      eq(userBlocks.blockerId, peerId), eq(userBlocks.blockedId, me.id)
    ));
  if (blocks.length > 0 || blocks2.length > 0) {
    return NextResponse.json({ error: "Messaging is disabled between these accounts" }, { status: 403 });
  }

  const token = mintCallToken({ room: `call_${room}`, identity: me.id, name: me.displayName });
  return NextResponse.json({
    token,
    url: livekitUrl(),
    room: `call_${room}`,
    identity: me.id,
    call_type: callType,
    expires_in: 300,
  });
}

export const runtime = "nodejs";
