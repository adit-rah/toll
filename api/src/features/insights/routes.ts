import { type Context, Hono } from "hono";
import { isWeekName } from "../../domain/time";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { fail, validate } from "../../lib/http";
import { viewerWeek } from "../school/service";
import { WeekQuery } from "./contract";
import { friendsInsights } from "./friends";
import { schoolInsights } from "./school";

// Default: the viewer's current week in their own timezone.
async function weekParam(c: Context<AppEnv>, requested: string | undefined): Promise<string> {
  if (requested === undefined) return viewerWeek(database(c.env.DB), c.get("userId"));
  if (!isWeekName(requested)) fail(400, "invalid");
  return requested;
}

export const insightRoutes = new Hono<AppEnv>()
  .get("/insights/friends", validate("query", WeekQuery), async (c) => {
    const week = await weekParam(c, c.req.valid("query").week);
    return c.json(await friendsInsights(database(c.env.DB), c.env, c.get("userId"), week));
  })
  .get("/insights/school", validate("query", WeekQuery), async (c) => {
    const week = await weekParam(c, c.req.valid("query").week);
    return c.json(await schoolInsights(database(c.env.DB), c.get("userId"), week));
  });
