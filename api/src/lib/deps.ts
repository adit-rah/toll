import { createRemoteJWKSet, type JWTVerifyGetKey } from "jose";
import type { Env } from "../env";

export interface EmailMessage {
  to: string;
  subject: string;
  text: string;
}

export type Fetch = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

// Everything that leaves the Worker goes through here so tests swap in local fakes (no network in tests).
export const deps: {
  appleKeys: JWTVerifyGetKey;
  fetch: Fetch;
  sendEmail: (env: Env, message: EmailMessage) => Promise<void>;
} = {
  appleKeys: createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys")),
  fetch: (input, init) => fetch(input, init),
  sendEmail: async (env, message) => {
    if (!env.RESEND_API_KEY) {
      console.log("email skipped: RESEND_API_KEY not set", message.subject);
      return;
    }
    const res = await deps.fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
      body: JSON.stringify({
        from: env.EMAIL_FROM,
        to: [message.to],
        subject: message.subject,
        text: message.text,
      }),
    });
    if (!res.ok) console.error("resend failed", res.status, await res.text());
  },
};
