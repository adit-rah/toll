import { and, eq, gt } from "drizzle-orm";
import { createMiddleware } from "hono/factory";
import { serverConfig } from "../config";
import { idempotencyKeys } from "../db/schema";
import type { AppEnv } from "../env";
import { database } from "./db";

const WRITES = new Set(["POST", "PUT", "PATCH", "DELETE"]);

// A retried write (the app's outbox retries on timeouts) gets the first response back instead of running twice.
export const idempotency = createMiddleware<AppEnv>(async (c, next) => {
  const key = c.req.header("idempotency-key");
  const userId = c.get("userId");
  if (!key || !userId || !WRITES.has(c.req.method) || key.length > 200) return next();

  const db = database(c.env.DB);
  const since = Date.now() - serverConfig.idempotencyTtlHours * 3_600_000;
  const [stored] = await db
    .select()
    .from(idempotencyKeys)
    .where(
      and(
        eq(idempotencyKeys.userId, userId),
        eq(idempotencyKeys.key, key),
        gt(idempotencyKeys.createdAt, since),
      ),
    )
    .limit(1);
  if (stored) {
    const headers = stored.body ? { "content-type": "application/json" } : undefined;
    return new Response(stored.body || null, { status: stored.status, headers });
  }

  await next();

  if (c.res.status >= 500 || c.res.status === 429) return;
  const body = c.res.status === 204 ? "" : await c.res.clone().text();
  await db
    .insert(idempotencyKeys)
    .values({ userId, key, status: c.res.status, body, createdAt: Date.now() })
    .onConflictDoUpdate({
      target: [idempotencyKeys.userId, idempotencyKeys.key],
      set: { status: c.res.status, body, createdAt: Date.now() },
    });
});
