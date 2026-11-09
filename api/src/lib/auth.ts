import { eq } from "drizzle-orm";
import { createMiddleware } from "hono/factory";
import { serverConfig } from "../config";
import { sessions } from "../db/schema";
import type { AppEnv } from "../env";
import { randomToken, sha256Hex } from "./crypto";
import { type Database, database } from "./db";
import { fail } from "./http";

const DAY_MS = 86_400_000;
const ttlMs = () => serverConfig.sessionTtlDays * DAY_MS;

export function bearer(header: string | undefined): string | null {
  const match = header?.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

export async function createSession(db: Database, userId: string, deviceId: string | null): Promise<string> {
  const token = randomToken(32);
  const now = Date.now();
  await db.insert(sessions).values({
    tokenHash: await sha256Hex(token),
    userId,
    deviceId,
    createdAt: now,
    expiresAt: now + ttlMs(),
  });
  return token;
}

export const requireAuth = createMiddleware<AppEnv>(async (c, next) => {
  const token = bearer(c.req.header("authorization"));
  if (!token) fail(401, "unauthorized");
  const db = database(c.env.DB);
  const tokenHash = await sha256Hex(token);
  const [session] = await db.select().from(sessions).where(eq(sessions.tokenHash, tokenHash)).limit(1);
  const now = Date.now();
  if (!session || session.expiresAt <= now) fail(401, "unauthorized");
  // Sliding expiry, written at most once a day per session to keep reads read-only.
  if (session.expiresAt - now < ttlMs() - DAY_MS) {
    await db
      .update(sessions)
      .set({ expiresAt: now + ttlMs() })
      .where(eq(sessions.tokenHash, tokenHash));
  }
  c.set("userId", session.userId);
  c.set("deviceId", session.deviceId);
  await next();
});
