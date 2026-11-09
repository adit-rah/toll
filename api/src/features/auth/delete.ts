import { and, eq } from "drizzle-orm";
import type { z } from "zod";
import { copy } from "../../copy";
import { authIdentities, idempotencyKeys, tombstones, users } from "../../db/schema";
import type { Env } from "../../env";
import { decryptText } from "../../lib/crypto";
import type { Database } from "../../lib/db";
import { sendEmail } from "../../lib/email";
import { fail } from "../../lib/http";
import { redeemCode } from "../../lib/otp";
import { swapPhotoKey } from "../me/photo";
import { exchangeAuthorizationCode, revokeRefreshToken, verifyIdentityToken } from "./apple";
import type { DeleteAccountRequest } from "./contract";
import { appleSubjectHash, signInKey } from "./service";

type Reauth = z.infer<typeof DeleteAccountRequest>["reauth"];

async function reauthenticate(db: Database, env: Env, userId: string, email: string | null, reauth: Reauth) {
  if (reauth.kind === "email") {
    if (!email) fail(403, "reauth_failed");
    await redeemCode(db, env, await signInKey(email), reauth.code);
    return null;
  }
  const identity = await verifyIdentityToken(env, reauth.identityToken, reauth.nonce);
  if (!identity) fail(403, "reauth_failed");
  const [own] = await db
    .select()
    .from(authIdentities)
    .where(
      and(
        eq(authIdentities.subjectHash, await appleSubjectHash(identity.sub)),
        eq(authIdentities.userId, userId),
      ),
    );
  if (!own) fail(403, "reauth_failed");
  return exchangeAuthorizationCode(env, reauth.authorizationCode);
}

// Spec §13: revoke Apple, tombstone the Apple subject, delete every row by cascade, then confirm by email.
export async function deleteAccount(db: Database, env: Env, userId: string, reauth: Reauth): Promise<void> {
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  if (!user) fail(401, "unauthorized");
  const freshToken = await reauthenticate(db, env, userId, user.email, reauth);

  const identities = await db.select().from(authIdentities).where(eq(authIdentities.userId, userId));
  const refreshTokens = freshToken ? [freshToken] : [];
  for (const identity of identities) {
    if (!identity.appleRefreshTokenEnc) continue;
    try {
      refreshTokens.push(await decryptText(env.TOKEN_ENC_KEY, identity.appleRefreshTokenEnc));
    } catch (err) {
      console.error("stored apple token unreadable", err);
    }
  }
  for (const token of new Set(refreshTokens)) await revokeRefreshToken(env, token);

  await swapPhotoKey(db, env, userId, null);
  const now = Date.now();
  const appleSubjects = identities.filter((i) => i.provider === "apple").map((i) => i.subjectHash);
  await db.batch([
    db.delete(idempotencyKeys).where(eq(idempotencyKeys.userId, userId)),
    ...appleSubjects.map((subjectHash) =>
      db.insert(tombstones).values({ subjectHash, createdAt: now }).onConflictDoNothing(),
    ),
    db.delete(users).where(eq(users.id, userId)),
  ]);

  if (user.email) await sendEmail(env, { to: user.email, ...copy.accountDeleted() });
}
