import { type Context, Hono } from "hono";
import type { z } from "zod";
import { defaultConfig, serverConfig } from "../../config";
import type { AppEnv } from "../../env";
import { database } from "../../lib/db";
import { fail, validate } from "../../lib/http";
import { allowed } from "../../lib/ratelimit";
import { recomputeWeeks, weeksTouched } from "../rollups/service";
import { EventBatch } from "./contract";
import { type IngestWindow, ingestEvents } from "./service";

const live: IngestWindow = { maxAgeDays: serverConfig.eventSkewDays };
// A solo user who signs in uploads what the phone kept (ledger A2), back to the server's retention.
const history: IngestWindow = { maxAgeDays: defaultConfig.retention.rawEventDays };

async function ingest(c: Context<AppEnv>, body: z.infer<typeof EventBatch>, window: IngestWindow) {
  const userId = c.get("userId");
  if (!(await allowed(c.env.RL_INGEST, userId))) fail(429, "rate_limited");
  const db = database(c.env.DB);
  const result = await ingestEvents(db, userId, body.deviceId, body.events, window);
  // Rollups are rebuilt before answering so the next /home already includes this batch.
  await recomputeWeeks(db, userId, weeksTouched(result.events));
  return c.json({ accepted: result.accepted, rejected: result.rejected });
}

export const eventRoutes = new Hono<AppEnv>()
  .post("/events", validate("json", EventBatch), (c) => ingest(c, c.req.valid("json"), live))
  .post("/events/history", validate("json", EventBatch), (c) => ingest(c, c.req.valid("json"), history));
