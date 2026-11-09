import { eq } from "drizzle-orm";
import type { z } from "zod";
import { authIdentities } from "../../db/schema";
import type { Env } from "../../env";
import { createSession } from "../../lib/auth";
import { encryptText, sha256Hex } from "../../lib/crypto";
import type { Database } from "../../lib/db";
import { fail } from "../../lib/http";
import { createUser, loadMe } from "../me/service";
import type { AuthSession } from "../shared/contract";
import { exchangeAuthorizationCode, verifyIdentityToken } from "./apple";
import type { AppleSignInRequest } from "./contract";

export const appleSubjectHash = (sub: string) => sha256Hex(`apple:${sub}`);
export const emailSubjectHash = (email: string) => sha256Hex(`email:${email}`);

export async function startSession(
  db: Database,
  env: Env,
  userId: string,
  deviceId: string,
  isNew: boolean,
): Promise<AuthSession> {
  const token = await createSession(db, userId, deviceId);
  return { token, user: await loadMe(db, env, userId), isNew };
}

export async function signInWithApple(
  db: Database,
  env: Env,
  input: z.infer<typeof AppleSignInRequest>,
): Promise<AuthSession> {
  const identity = await verifyIdentityToken(env, input.identityToken, input.nonce);
  if (!identity) fail(401, "invalid_token");
  const subjectHash = await appleSubjectHash(identity.sub);
  const [existing] = await db
    .select()
    .from(authIdentities)
    .where(eq(authIdentities.subjectHash, subjectHash))
    .limit(1);

  const refreshToken = await exchangeAuthorizationCode(env, input.authorizationCode);
  const sealed = refreshToken ? await encryptText(env.TOKEN_ENC_KEY, refreshToken) : null;

  if (existing) {
    if (sealed) {
      await db
        .update(authIdentities)
        .set({ appleRefreshTokenEnc: sealed })
        .where(eq(authIdentities.subjectHash, subjectHash));
    }
    return startSession(db, env, existing.userId, input.deviceId, false);
  }

  // Apple sends the name only with the very first credential, so it is captured here or never.
  const name = [input.givenName, input.familyName].filter(Boolean).join(" ");
  const userId = await createUser(db, env, { displayName: name, email: identity.email });
  await db.insert(authIdentities).values({
    subjectHash,
    userId,
    provider: "apple",
    appleRefreshTokenEnc: sealed,
    createdAt: Date.now(),
  });
  return startSession(db, env, userId, input.deviceId, true);
}
