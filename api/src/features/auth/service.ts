import { eq } from "drizzle-orm";
import { z } from "zod";
import { serverConfig } from "../../config";
import { copy } from "../../copy";
import { authIdentities, sessions } from "../../db/schema";
import type { Env } from "../../env";
import { createSession } from "../../lib/auth";
import { encryptText, sha256Hex } from "../../lib/crypto";
import type { Database } from "../../lib/db";
import { sendEmail } from "../../lib/email";
import { fail } from "../../lib/http";
import { issueCode, redeemCode } from "../../lib/otp";
import { allowed } from "../../lib/ratelimit";
import { createUser, loadMe, normalizeEmail } from "../me/service";
import type { AuthSession } from "../shared/contract";
import { exchangeAuthorizationCode, verifyIdentityToken } from "./apple";
import type { AppleSignInRequest, EmailVerifyRequest } from "./contract";

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

export function parseEmail(raw: string): string {
  const email = normalizeEmail(raw);
  if (!z.email().safeParse(email).success) fail(400, "invalid_email");
  return email;
}

export const signInKey = async (email: string) => `signin:${await sha256Hex(email)}`;

export async function sendSignInCode(db: Database, env: Env, email: string, ip: string): Promise<void> {
  if (!(await allowed(env.RL_OTP, `${ip}:${await sha256Hex(email)}`))) {
    fail(429, "rate_limited", { retryAt: Date.now() + 60_000 });
  }
  const review = env.REVIEW_EMAIL && env.REVIEW_CODE && normalizeEmail(env.REVIEW_EMAIL) === email;
  const code = await issueCode(db, env, await signInKey(email), {
    fixedCode: review ? env.REVIEW_CODE : undefined,
  });
  if (!review) await sendEmail(env, { to: email, ...copy.signInCode(code, serverConfig.otpTtlMinutes) });
}

export async function signInWithEmail(
  db: Database,
  env: Env,
  input: z.infer<typeof EmailVerifyRequest>,
): Promise<AuthSession> {
  const email = parseEmail(input.email);
  await redeemCode(db, env, await signInKey(email), input.code);
  const subjectHash = await emailSubjectHash(email);
  const [existing] = await db
    .select()
    .from(authIdentities)
    .where(eq(authIdentities.subjectHash, subjectHash))
    .limit(1);
  if (existing) return startSession(db, env, existing.userId, input.deviceId, false);

  const userId = await createUser(db, env, { email });
  await db.insert(authIdentities).values({ subjectHash, userId, provider: "email", createdAt: Date.now() });
  return startSession(db, env, userId, input.deviceId, true);
}

export async function endSession(db: Database, token: string): Promise<void> {
  await db.delete(sessions).where(eq(sessions.tokenHash, await sha256Hex(token)));
}
