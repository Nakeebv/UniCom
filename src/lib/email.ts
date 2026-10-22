import { env } from "@/lib/config-lite";

/**
 * Transactional email via Resend (https://resend.com).
 *
 * Env-gated: with RESEND_API_KEY + RESEND_FROM set, verification codes are
 * emailed for real. Without them the code is NOT silently accepted — the
 * caller is told email delivery is not configured, so registration cannot
 * appear to succeed when it cannot.
 */
export function emailConfigured(): boolean {
  return Boolean(env("RESEND_API_KEY") && env("RESEND_FROM"));
}

export type SendResult = { ok: true } | { ok: false; reason: string };

export async function sendEmail(input: {
  to: string;
  subject: string;
  text: string;
  html?: string;
}): Promise<SendResult> {
  const apiKey = env("RESEND_API_KEY");
  const from = env("RESEND_FROM");
  if (!apiKey || !from) {
    return { ok: false, reason: "email delivery is not configured on this server" };
  }
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        authorization: `Bearer ${apiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [input.to],
        subject: input.subject,
        text: input.text,
        html: input.html,
      }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      return { ok: false, reason: `resend http ${res.status} ${detail.slice(0, 160)}` };
    }
    return { ok: true };
  } catch (err) {
    return { ok: false, reason: err instanceof Error ? err.message : "network error" };
  }
}

/** The 6-digit verification email body (plain + branded HTML). */
export function verificationEmail(code: string): { subject: string; text: string; html: string } {
  const subject = `Your UniCom verification code: ${code}`;
  const text =
    `Your UniCom verification code is ${code}.\n\n` +
    `It expires in 15 minutes. If you didn't create a UniCom account, ignore this email.`;
  const html = `
  <div style="font-family:system-ui,Segoe UI,Roboto,sans-serif;background:#0b0f10;color:#f2f4f3;padding:32px">
    <div style="max-width:420px;margin:0 auto;background:#121a1c;border-radius:18px;padding:28px;text-align:center">
      <div style="font-size:13px;letter-spacing:2px;color:#2BB8AC;font-weight:700">UNICOM</div>
      <h2 style="margin:14px 0 6px">Verify your email</h2>
      <p style="color:#9aa7a6;font-size:14px;margin:0 0 20px">Enter this code to finish creating your account.</p>
      <div style="font-size:34px;font-weight:800;letter-spacing:8px;color:#2BB8AC;margin:8px 0 18px">${code}</div>
      <p style="color:#637372;font-size:12px;margin:0">Expires in 15 minutes. Didn't sign up? Ignore this email.</p>
    </div>
  </div>`;
  return { subject, text, html };
}
