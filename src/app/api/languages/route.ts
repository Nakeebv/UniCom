import { NextResponse } from "next/server";
import { SUPPORTED_LANGUAGES } from "@/lib/i18n/languages";

export async function GET() {
  return NextResponse.json({ languages: SUPPORTED_LANGUAGES });
}
