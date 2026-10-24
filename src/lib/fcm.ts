import crypto from "node:crypto";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { deviceTokens } from "@/db/schema";
import { env } from "@/lib/config-lite";

/**
 * Firebase Cloud Messaging sender (HTTP v1) — env-gated.
 *
 * Provide ONE of:
 *   FCM_SERVICE_ACCOUNT_JSON  — the full service-account JSON (single line)
 *   (or) FCM_ACCESS_TOKEN      — a short-lived OAuth token (testing only)
 * plus FCM_PROJECT_ID (defaults to the service-account's project_id).
 *
 * The service-account key lives ONLY on the server, never in the client.
 * When unconfigured, sends are skipped and reported as "push not configured"
 * — never claimed as delivered.
 */

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

let cachedToken: { value: string; expiresAt: number } | null = null;

function serviceAccount(): ServiceAccount | null {
  const raw = env("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as ServiceAccount;
    if (!parsed.client_email || !parsed.private_key) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function fcmConfigured(): boolean {
  return Boolean(env("FCM_ACCESS_TOKEN") || serviceAccount());
}

export function fcmProjectId(): string | null {
  return env("FCM_PROJECT_ID") ?? serviceAccount()?.project_id ?? null;
}

/** Mints an OAuth2 access token from the service account (JWT bearer flow). */
async function accessToken(): Promise<string | null> {
  const direct = env("FCM_ACCESS_TOKEN");
  if (direct) return direct;
  const sa = serviceAccount();
  if (!sa) return null;
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }
  const now = Math.floor(Date.now() / 1000);
  const b64u = (x: Buffer | string) =>
    Buffer.from(x).toString("base64").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  const header = b64u(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64u(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(`${header}.${claims}`);
  const jwt = `${header}.${claims}.${b64u(signer.sign(sa.private_key))}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) return null;
  const data = (await res.json()) as { access_token?: string; expires_in?: number };
  if (!data.access_token) return null;
  cachedToken = {
    value: data.access_token,
    expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
  };
  return data.access_token;
}

export type PushPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
  /** android channel id */
  channelId?: string;
  highPriority?: boolean;
};

export type PushResult = { sent: number; failed: number; configured: boolean };

/** Sends a push to every device token registered for [userId]. */
export async function sendPushToUser(
  userId: string,
  payload: PushPayload,
): Promise<PushResult> {
  const tokens = await db
    .select({ token: deviceTokens.token })
    .from(deviceTokens)
    .where(eq(deviceTokens.userId, userId));
  if (tokens.length === 0) return { sent: 0, failed: 0, configured: fcmConfigured() };
  if (!fcmConfigured()) {
    return { sent: 0, failed: 0, configured: false };
  }
  const projectId = fcmProjectId();
  const token = await accessToken();
  if (!projectId || !token) {
    return { sent: 0, failed: tokens.length, configured: false };
  }

  let sent = 0;
  let failed = 0;
  await Promise.all(
    tokens.map(async ({ token: device }) => {
      // Data-only + notification so Android can present it in background.
      const message = {
        message: {
          token: device,
          notification: { title: payload.title, body: payload.body },
          data: payload.data,
          android: {
            priority: payload.highPriority ? "HIGH" : "NORMAL",
            notification: {
              channel_id: payload.channelId ?? "unicom_messages",
              sound: "default",
            },
          },
          apns: {
            headers: { "apns-priority": payload.highPriority ? "10" : "5" },
            payload: { aps: { sound: "default" } },
          },
        },
      };
      try {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              authorization: `Bearer ${token}`,
              "content-type": "application/json",
            },
            body: JSON.stringify(message),
          },
        );
        if (res.ok) {
          sent++;
        } else {
          failed++;
          // Prune tokens Firebase reports as gone.
          if (res.status === 404 || res.status === 410) {
            await db.delete(deviceTokens).where(eq(deviceTokens.token, device));
          }
        }
      } catch {
        failed++;
      }
    }),
  );
  return { sent, failed, configured: true };
}
