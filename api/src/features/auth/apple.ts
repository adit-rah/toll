import { importPKCS8, jwtVerify, SignJWT } from "jose";
import type { Env } from "../../env";
import { sha256Hex } from "../../lib/crypto";
import { deps } from "../../lib/deps";

const APPLE_ISSUER = "https://appleid.apple.com";

export interface AppleIdentity {
  sub: string;
  email: string | null;
}

export async function verifyIdentityToken(
  env: Env,
  token: string,
  rawNonce: string,
): Promise<AppleIdentity | null> {
  try {
    const { payload } = await jwtVerify(token, deps.appleKeys, {
      issuer: APPLE_ISSUER,
      audience: env.APPLE_BUNDLE_ID,
      requiredClaims: ["sub", "exp", "nonce"],
    });
    // The app sends Apple the SHA-256 of its nonce, so the token carries the hash, never the raw value.
    if (payload.nonce !== (await sha256Hex(rawNonce))) return null;
    if (typeof payload.sub !== "string") return null;
    return { sub: payload.sub, email: typeof payload.email === "string" ? payload.email : null };
  } catch {
    return null;
  }
}

function configured(env: Env): boolean {
  return Boolean(env.APPLE_PRIVATE_KEY && env.APPLE_KEY_ID && env.APPLE_TEAM_ID);
}

async function clientSecret(env: Env): Promise<string> {
  const key = await importPKCS8(env.APPLE_PRIVATE_KEY ?? "", "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APPLE_KEY_ID })
    .setIssuer(env.APPLE_TEAM_ID)
    .setSubject(env.APPLE_BUNDLE_ID)
    .setAudience(APPLE_ISSUER)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
}

export async function exchangeAuthorizationCode(env: Env, code: string): Promise<string | null> {
  if (!configured(env)) {
    console.log("apple code exchange skipped: key not configured");
    return null;
  }
  try {
    const res = await deps.fetch(`${APPLE_ISSUER}/auth/token`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: env.APPLE_BUNDLE_ID,
        client_secret: await clientSecret(env),
        code,
        grant_type: "authorization_code",
      }),
    });
    if (!res.ok) {
      console.error("apple code exchange failed", res.status);
      return null;
    }
    const body = (await res.json()) as { refresh_token?: string };
    return body.refresh_token ?? null;
  } catch (err) {
    console.error("apple code exchange failed", err);
    return null;
  }
}

export async function revokeRefreshToken(env: Env, refreshToken: string): Promise<void> {
  if (!configured(env)) return;
  try {
    const res = await deps.fetch(`${APPLE_ISSUER}/auth/revoke`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: env.APPLE_BUNDLE_ID,
        client_secret: await clientSecret(env),
        token: refreshToken,
        token_type_hint: "refresh_token",
      }),
    });
    if (!res.ok) console.error("apple revoke failed", res.status);
  } catch (err) {
    console.error("apple revoke failed", err);
  }
}
