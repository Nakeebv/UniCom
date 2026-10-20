import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { messages } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { requestTranslation } from "@/lib/queue";
import { isSupported } from "@/lib/i18n/languages";
import { isMember } from "@/lib/serialize";

type Params = { params: Promise<{ id: string }> };

/** Request (or retry) a translation for a specific target language. */
export async function POST(request: Request, { params }: Params) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const [msg] = await db.select().from(messages).where(eq(messages.id, id)).limit(1);
  if (!msg || msg.deletedAt) return NextResponse.json({ error: "not found" }, { status: 404 });
  if (!(await isMember(msg.conversationId, me.id))) return NextResponse.json({ error: "forbidden" }, { status: 403 });

  const body = (await request.json().catch(() => null)) as { language?: string } | null;
  const language = body?.language ?? me.preferredLanguage;
  if (!isSupported(language)) return NextResponse.json({ error: "Unsupported language" }, { status: 400 });
  if (language === msg.sourceLanguage) {
    return NextResponse.json({ error: "Message is already in that language" }, { status: 400 });
  }

  await requestTranslation(id, language);
  return NextResponse.json({ message_id: id, language, status: "queued" });
}
