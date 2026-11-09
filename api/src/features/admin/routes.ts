import { Hono } from "hono";
import { createMiddleware } from "hono/factory";
import { z } from "zod";
import { defaultConfig } from "../../config";
import { DAY_MS } from "../../domain/time";
import type { AppEnv } from "../../env";
import { bearer } from "../../lib/auth";
import { constantTimeEqual } from "../../lib/crypto";
import { database } from "../../lib/db";
import { fail, validate } from "../../lib/http";
import { recomputeRecent } from "../rollups/recent";

// Founders only, with a separate secret: an app session can never reach these routes.
const requireAdmin = createMiddleware<AppEnv>(async (c, next) => {
  const token = bearer(c.req.header("authorization"));
  if (!c.env.ADMIN_TOKEN || !token || !constantTimeEqual(token, c.env.ADMIN_TOKEN)) fail(401, "unauthorized");
  await next();
});

// A week is only rebuilt while all of its raw events are still kept.
const MAX_RECOMPUTE_DAYS = defaultConfig.retention.rawEventDays - 7;

const RecomputeRequest = z.object({
  userIds: z.array(z.string().max(100)).max(500).optional(),
  days: z.int().min(1).max(MAX_RECOMPUTE_DAYS),
});

// Spec §1: what proves us wrong is under a third of users with a friend, or friends not looking weekly.
const STATS = `SELECT
  (SELECT COUNT(*) FROM devices) AS installs,
  (SELECT COUNT(*) FROM users) AS users,
  (SELECT COUNT(*) FROM (
    SELECT user_lo AS id FROM friendships WHERE status = 'accepted'
    UNION SELECT user_hi FROM friendships WHERE status = 'accepted')) AS usersWithFriend,
  (SELECT COUNT(*) FROM users WHERE last_home_at >= ?) AS weeklyLookers`;

export const adminRoutes = new Hono<AppEnv>()
  .get("/admin/stats", requireAdmin, async (c) => {
    const row = await c.env.DB.prepare(STATS)
      .bind(Date.now() - 7 * DAY_MS)
      .first<{ installs: number; users: number; usersWithFriend: number; weeklyLookers: number }>();
    const stats = row ?? { installs: 0, users: 0, usersWithFriend: 0, weeklyLookers: 0 };
    return c.json({
      ...stats,
      usersWithFriendPercent: stats.users ? Math.round((100 * stats.usersWithFriend) / stats.users) : 0,
    });
  })
  .post("/admin/recompute", requireAdmin, validate("json", RecomputeRequest), async (c) => {
    const { userIds, days } = c.req.valid("json");
    return c.json(await recomputeRecent(database(c.env.DB), Date.now(), days, userIds));
  });
