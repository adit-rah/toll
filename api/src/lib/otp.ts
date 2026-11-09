import { eq } from "drizzle-orm";
import { serverConfig } from "../config";
import { emailCodes } from "../db/schema";
import type { Env } from "../env";
import { constantTimeEqual, hmacHex, randomDigits } from "./crypto";
import type { Database } from "./db";
import { fail } from "./http";

const MINUTE = 60_000;

// One code per key ("signin:<emailHash>", "school:<emailHash>"); the code itself is never stored.
const codeHash = (env: Env, key: string, code: string) => hmacHex(env.OTP_PEPPER, `${key}:${code}`);

export async function issueCode(
  db: Database,
  env: Env,
  key: string,
  options: { schoolId?: number; fixedCode?: string } = {},
): Promise<string> {
  const now = Date.now();
  const [row] = await db.select().from(emailCodes).where(eq(emailCodes.key, key)).limit(1);
  if (row?.lockedUntil && row.lockedUntil > now) fail(423, "locked", { lockedUntil: row.lockedUntil });
  const cooldownEnds = (row?.sentAt ?? 0) + serverConfig.otpResendCooldownSeconds * 1000;
  if (row && cooldownEnds > now) fail(429, "rate_limited", { retryAt: cooldownEnds });

  const code = options.fixedCode ?? randomDigits(6);
  // Attempts survive a resend; otherwise Resend would reset the five-try lock every 30 seconds.
  const attempts = row?.lockedUntil ? 0 : (row?.attempts ?? 0);
  const values = {
    codeHash: await codeHash(env, key, code),
    expiresAt: now + serverConfig.otpTtlMinutes * MINUTE,
    attempts,
    lockedUntil: null,
    sentAt: now,
    schoolId: options.schoolId ?? null,
  };
  await db
    .insert(emailCodes)
    .values({ key, ...values })
    .onConflictDoUpdate({ target: emailCodes.key, set: values });
  return code;
}

export async function redeemCode(
  db: Database,
  env: Env,
  key: string,
  code: string,
): Promise<{ schoolId: number | null }> {
  const now = Date.now();
  const [row] = await db.select().from(emailCodes).where(eq(emailCodes.key, key)).limit(1);
  if (!row) fail(410, "expired");
  if (row.lockedUntil && row.lockedUntil > now) fail(423, "locked", { lockedUntil: row.lockedUntil });
  if (row.expiresAt <= now) fail(410, "expired");

  if (!constantTimeEqual(row.codeHash, await codeHash(env, key, code))) {
    const attempts = row.attempts + 1;
    if (attempts >= serverConfig.otpMaxAttempts) {
      const lockedUntil = now + serverConfig.otpLockMinutes * MINUTE;
      await db.update(emailCodes).set({ attempts, lockedUntil }).where(eq(emailCodes.key, key));
      fail(423, "locked", { lockedUntil });
    }
    await db.update(emailCodes).set({ attempts }).where(eq(emailCodes.key, key));
    fail(400, "wrong_code", { attemptsLeft: serverConfig.otpMaxAttempts - attempts });
  }

  await db.delete(emailCodes).where(eq(emailCodes.key, key));
  return { schoolId: row.schoolId };
}
