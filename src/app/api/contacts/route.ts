import { NextResponse } from "next/server";
import { eq, ne, or } from "drizzle-orm";
import { db } from "@/db";
import { userBlocks, userPreferences, users } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";
import { ensureSeed } from "@/db/seed";

export const dynamic = "force-dynamic";

export async function GET() {
  await ensureSeed();
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const rows = await db
    .select({
      id: users.id,
      username: users.username,
      displayName: users.displayName,
      avatarHue: users.avatarHue,
      bio: users.bio,
      isPersona: users.isPersona,
      lastSeenAt: users.lastSeenAt,
      preferredLanguage: userPreferences.preferredLanguage,
    })
    .from(users)
    .leftJoin(userPreferences, eq(userPreferences.userId, users.id))
    .where(ne(users.id, me.id));

  const blocks = await db
    .select()
    .from(userBlocks)
    .where(or(eq(userBlocks.blockerId, me.id), eq(userBlocks.blockedId, me.id)));

  const myBlocks = new Set(blocks.filter((b) => b.blockerId === me.id).map((b) => b.blockedId));
  const blockedMe = new Set(blocks.filter((b) => b.blockedId === me.id).map((b) => b.blockerId));

  return NextResponse.json({
    contacts: rows.map((r) => ({
      id: r.id,
      username: r.username,
      displayName: r.displayName,
      avatarHue: r.avatarHue,
      bio: r.bio,
      isPersona: r.isPersona,
      preferredLanguage: r.preferredLanguage ?? "en",
      online: !!r.lastSeenAt && Date.now() - r.lastSeenAt.getTime() < 30_000,
      lastSeenAt: r.lastSeenAt ? r.lastSeenAt.toISOString() : null,
      blockedByMe: myBlocks.has(r.id),
      blockedMe: blockedMe.has(r.id),
    })),
  });
}
