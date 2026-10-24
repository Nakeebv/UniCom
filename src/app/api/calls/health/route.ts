import { NextResponse } from "next/server";
import { getSessionUser } from "@/lib/auth";
import { probeLivekit } from "@/lib/livekit";

export const dynamic = "force-dynamic";

/** Calling configuration self-check (auth'd; no secrets in response). */
export async function GET() {
  const me = await getSessionUser();
  if (!me) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const probe = await probeLivekit();
  return NextResponse.json({ ...probe });
}

export const runtime = "nodejs";
