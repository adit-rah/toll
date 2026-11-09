import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from "jose";
import { sha256Hex } from "../src/lib/crypto";
import { deps } from "../src/lib/deps";
import { env } from "./helpers";

const keys = await generateKeyPair("RS256");
const jwk = { ...(await exportJWK(keys.publicKey)), kid: "test-kid", alg: "RS256" };
deps.appleKeys = createLocalJWKSet({ keys: [jwk] });

export interface TokenOptions {
  sub?: string;
  aud?: string;
  nonce?: string;
  rawNonce?: string;
  expiresIn?: string | number;
  email?: string;
}

export async function appleToken(options: TokenOptions = {}): Promise<{ token: string; nonce: string }> {
  const rawNonce = options.rawNonce ?? crypto.randomUUID();
  const claims: Record<string, unknown> = { nonce: options.nonce ?? (await sha256Hex(rawNonce)) };
  if (options.email) claims.email = options.email;
  const token = await new SignJWT(claims)
    .setProtectedHeader({ alg: "RS256", kid: "test-kid" })
    .setIssuer("https://appleid.apple.com")
    .setAudience(options.aud ?? env.APPLE_BUNDLE_ID)
    .setSubject(options.sub ?? crypto.randomUUID())
    .setIssuedAt()
    .setExpirationTime(options.expiresIn ?? "10m")
    .sign(keys.privateKey);
  return { token, nonce: rawNonce };
}
