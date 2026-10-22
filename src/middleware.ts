import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/** Permissive CORS for the API so the Flutter web build (any origin) can
 *  call it during development. Same-origin production copies need none. */
export function middleware(request: NextRequest) {
  if (request.nextUrl.pathname.startsWith("/flutter")) return noStore(request);
  if (request.method === "OPTIONS") {
    return new NextResponse(null, {
      status: 204,
      headers: corsHeaders(),
    });
  }
  const res = NextResponse.next();
  for (const [k, v] of Object.entries(corsHeaders())) res.headers.set(k, v);
  return res;
}

function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,PATCH,DELETE,OPTIONS",
    "access-control-allow-headers": "content-type,authorization",
    "access-control-max-age": "86400",
  };
}

export const config = {
  matcher: ["/api/:path*", "/flutter/:path*", "/flutter"],
};

/** Fresh JS for the Flutter web target on every load — stale bootstrap is
 *  the classic white-screen / rolling-spinner source on mobile browsers. */
export function noStore(request: NextRequest) {
  if (request.nextUrl.pathname.startsWith("/flutter")) {
    const res = NextResponse.next();
    res.headers.set("cache-control", "no-store, must-revalidate");
    res.headers.set("x-app-build", new Date().toISOString());
    return res;
  }
  return NextResponse.next();
}
