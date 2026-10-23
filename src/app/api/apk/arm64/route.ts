import { NextResponse } from "next/server";
import { presignGetUrl } from "@/lib/storage";

export const dynamic = "force-dynamic";

/**
 * Public APK download — 302 to a long-lived presigned R2 URL so large
 * transfers stream from Cloudflare's edge instead of the dev server.
 */
export async function GET() {
  const url = await presignGetUrl("downloads/unicom-arm64.apk", 86_400);
  return NextResponse.redirect(url, {
    status: 302,
    headers: { "cache-control": "no-store" },
  });
}

export const runtime = "nodejs";
