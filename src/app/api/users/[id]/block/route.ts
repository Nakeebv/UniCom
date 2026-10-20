import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { userBlocks, users } from "@/db/schema";
import { getSessionUser } from "@/lib/auth";

type Params = { params: Promise<{ id: string }> };

export async function POST(_request: Request, { params }: Params) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  if (id === me.id) return NextResponse.json({ error: "Cannot block yourself" }, { status: 400 });

  const [target] = await db.select({ id: users.id }).from(users).where(eq(users.id, id)).limit(1);
  if (!target) return NextResponse.json({ error: "not found" }, { status: 404 });

  const [existing] = await db
    .select()
    .from(userBlocks)
    .where(and(eq(userBlocks.blockerId, me.id), eq(userBlocks.blockedId, id)))
    .limit(1);
  if (!existing) {
    await db.insert(userBlocks).values({ blockerId: me.id, blockedId: id });
  }
  return NextResponse.json({ ok: true });
}

export async function DELETE(_request: Request, { params }: Params) {
  const { id } = await params;
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  await db
    .delete(userBlocks)
    .where(and(eq(userBlocks.blockerId, me.id), eq(userBlocks.blockedId, id)));
  return NextResponse.json({ ok: true });
}
