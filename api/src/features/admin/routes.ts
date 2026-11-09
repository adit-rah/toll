import { Hono } from "hono";
import { createMiddleware } from "hono/factory";
import { z } from "zod";
import { defaultConfig } from "../../config";
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

export const adminRoutes = new Hono<AppEnv>().post(
  "/admin/recompute",
  requireAdmin,
  validate("json", RecomputeRequest),
  async (c) => {
    const { userIds, days } = c.req.valid("json");
    return c.json(await recomputeRecent(database(c.env.DB), Date.now(), days, userIds));
  },
);
