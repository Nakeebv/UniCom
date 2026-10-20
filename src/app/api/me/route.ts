import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { userPreferences, users } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { isSupported } from "@/lib/i18n/languages";

export const dynamic = "force-dynamic";

export async function GET() {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  return NextResponse.json({ me });
}

export async function PATCH(request: Request) {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as {
    preferredLanguage?: string;
    speechLanguage?: string | null;
    showOriginal?: boolean;
    displayName?: string;
  } | null;

  if (body?.preferredLanguage !== undefined && !isSupported(body.preferredLanguage)) {
    return NextResponse.json({ error: "Unsupported language" }, { status: 400 });
  }
  if (body?.speechLanguage != null && body.speechLanguage !== "" && !isSupported(body.speechLanguage)) {
    return NextResponse.json({ error: "Unsupported speech language" }, { status: 400 });
  }

  await db
    .update(userPreferences)
    .set({
      ...(body?.preferredLanguage !== undefined ? { preferredLanguage: body.preferredLanguage } : {}),
      ...(body?.speechLanguage !== undefined ? { speechLanguage: body.speechLanguage || null } : {}),
      ...(body?.showOriginal !== undefined ? { showOriginal: body.showOriginal } : {}),
      updatedAt: new Date(),
    })
    .where(eq(userPreferences.userId, me.id));

  if (body?.displayName && body.displayName.trim().length >= 2) {
    await db.update(users).set({ displayName: body.displayName.trim().slice(0, 48) }).where(eq(users.id, me.id));
  }

  return NextResponse.json({ ok: true });
}
