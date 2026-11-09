import { importPKCS8, SignJWT } from "jose";
import { serverConfig } from "../config";
import type { Env, PushMessage } from "../env";
import { deps } from "./deps";

let cached: { token: string; keyId: string; issuedAt: number } | null = null;

// APNs rejects tokens older than an hour and throttles ones refreshed too often, so one is reused ~50 min.
async function providerToken(env: Env): Promise<string> {
  const now = Date.now();
  const ttl = serverConfig.apnsJwtTtlMinutes * 60_000;
  if (cached && cached.keyId === env.APNS_KEY_ID && now - cached.issuedAt < ttl) return cached.token;
  const key = await importPKCS8(env.APNS_PRIVATE_KEY ?? "", "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APNS_KEY_ID })
    .setIssuer(env.APPLE_TEAM_ID)
    .setIssuedAt(Math.floor(now / 1000))
    .sign(key);
  cached = { token, keyId: env.APNS_KEY_ID, issuedAt: now };
  return token;
}

export interface PushResult {
  status: number;
  reason: string | null;
}

export function apnsConfigured(env: Env): boolean {
  return Boolean(env.APNS_PRIVATE_KEY && env.APNS_KEY_ID && env.APPLE_TEAM_ID);
}

export async function sendPush(env: Env, message: PushMessage): Promise<PushResult> {
  const host = message.environment === "sandbox" ? "api.sandbox.push.apple.com" : env.APNS_HOST;
  const alert = message.kind === "alert";
  const payload = alert
    ? { aps: { alert: { body: message.body ?? "" }, sound: "default" }, ...message.data }
    : { aps: { "content-available": 1 }, ...message.data };
  const res = await deps.fetch(`https://${host}/3/device/${message.deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken(env)}`,
      "apns-topic": env.APPLE_BUNDLE_ID,
      "apns-push-type": alert ? "alert" : "background",
      "apns-priority": alert ? "10" : "5",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (res.ok) return { status: res.status, reason: null };
  const body = (await res.json().catch(() => ({}))) as { reason?: string };
  return { status: res.status, reason: body.reason ?? null };
}

export const isDeadToken = (result: PushResult) =>
  result.status === 410 || result.reason === "BadDeviceToken" || result.reason === "Unregistered";
