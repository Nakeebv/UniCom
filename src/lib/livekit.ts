import crypto from "crypto";
import { env } from "@/lib/config-lite";

/** Minimal LiveKit server-side access-token mint (HMAC/HS256, no SDK dep). */
export type CallGrant = { room: string; identity: string; name?: string };

export function livekitConfigured() {
  return Boolean(env("LIVEKIT_URL") && env("LIVEKIT_API_KEY") && env("LIVEKIT_API_SECRET"));
}

export function livekitUrl() {
  return env("LIVEKIT_URL")!;
}

/** VideoGrant: publish/subscribe within the one call room, 5-minute TTL. */
export function mintCallToken({ room, identity, name }: CallGrant): string {
  const key = env("LIVEKIT_API_KEY")!;
  const secret = env("LIVEKIT_API_SECRET")!;
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: key,
    sub: identity,
    nbf: now - 10,
    exp: now + 300,
    name: name ?? identity,
    video: {
      room, roomJoin: true, canPublish: true, canSubscribe: true,
      canPublishData: true, canPublishSources: [], hidden: false, recorder: false,
    },
  };
  const b64u = (b: Buffer | string) =>
    Buffer.from(b).toString("base64").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  const header = b64u(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = b64u(JSON.stringify(payload));
  const sig = crypto.createHmac("sha256", secret).update(`${header}.${body}`).digest();
  return `${header}.${body}.${b64u(sig)}`;
}

/** LiveKit cloud reachability probe. Result cached 60s. Never exposes the
 *  key/secret — only booleans and a redacted reason. */
let lastProbe: { at: number; ok: boolean; reason?: string } | null = null;

export async function probeLivekit(): Promise<{
  configured: boolean;
  ok: boolean;
  reason?: string;
}> {
  if (!livekitConfigured()) {
    return { configured: false, ok: false, reason: "not configured" };
  }
  if (lastProbe && Date.now() - lastProbe.at < 60_000) {
    return { configured: true, ok: lastProbe.ok, reason: lastProbe.reason };
  }
  const secret = env("LIVEKIT_API_SECRET")!;
  const host = env("LIVEKIT_URL")!.replace(/^wss:\/\//, "https://").replace(/^ws:\/\//, "http://");
  const now = Math.floor(Date.now() / 1000);
  const b64u = (b: Buffer | string) =>
    Buffer.from(b).toString("base64").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  const header = b64u(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = b64u(
    JSON.stringify({ iss: env("LIVEKIT_API_KEY"), sub: "probe", nbf: now - 10, exp: now + 60, video: { roomList: true } }),
  );
  const sig = b64u(crypto.createHmac("sha256", secret).update(`${header}.${body}`).digest());

  let ok = false;
  let reason: string | undefined;
  try {
    const res = await fetch(`${host}/twirp/livekit.RoomService/ListRooms`, {
      method: "POST",
      headers: { authorization: `Bearer ${header}.${body}.${sig}`, "content-type": "application/json" },
      body: JSON.stringify({}),
    });
    ok = res.ok;
    if (!ok) reason = `livekit rejected server credentials (http ${res.status})`;
  } catch {
    reason = `livekit unreachable at ${env("LIVEKIT_URL")}`;
  }
  lastProbe = { at: Date.now(), ok, reason };
  return { configured: true, ok, reason };
}
