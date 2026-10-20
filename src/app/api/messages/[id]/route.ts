import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { messageContents, messages } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import {
  enqueueTranslationsForMessage,
  enqueueVoiceJobs,
  invalidateStaleTranslations,
} from "@/lib/queue";
import { isMember } from "@/lib/serialize";

type Params = { params: Promise<{ id: string }> };

/** Edit the original text. Version bumps and every translation is invalidated. */
export async function PATCH(request: Request, { params }: Params) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [msg] = await db.select().from(messages).where(eq(messages.id, id)).limit(1);
  if (!msg || msg.deletedAt) return NextResponse.json({ error: "not found" }, { status: 404 });
  if (msg.senderId !== me.id) return NextResponse.json({ error: "forbidden" }, { status: 403 });
  if (!(await isMember(msg.conversationId, me.id))) return NextResponse.json({ error: "forbidden" }, { status: 403 });

  const body = (await request.json().catch(() => null)) as { text?: string } | null;
  const text = (body?.text ?? "").trim();
  if (text.length < 1 || text.length > 4000) {
    return NextResponse.json({ error: "Message text must be 1–4000 characters" }, { status: 400 });
  }

  const nextVersion = msg.version + 1;
  await db.transaction(async (tx) => {
    await tx
      .update(messageContents)
      .set({ originalText: text })
      .where(eq(messageContents.messageId, id));
    await tx
      .update(messages)
      .set({ version: nextVersion, editedAt: new Date() })
      .where(eq(messages.id, id));
  });

  await invalidateStaleTranslations(id, nextVersion);
  if (msg.type === "voice") {
    await enqueueVoiceJobs(id);
  }
  await enqueueTranslationsForMessage(id);

  return NextResponse.json({ ok: true, version: nextVersion });
}

/** Soft delete: tombstone the message, keep the original content private. */
export async function DELETE(_request: Request, { params }: Params) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [msg] = await db.select().from(messages).where(eq(messages.id, id)).limit(1);
  if (!msg || msg.deletedAt) return NextResponse.json({ error: "not found" }, { status: 404 });
  if (msg.senderId !== me.id) return NextResponse.json({ error: "forbidden" }, { status: 403 });

  await db.update(messages).set({ deletedAt: new Date() }).where(eq(messages.id, id));
  return NextResponse.json({ ok: true });
}
