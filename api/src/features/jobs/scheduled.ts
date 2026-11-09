import type { Env } from "../../env";
import { database } from "../../lib/db";
import { enqueueDailyPushes } from "../notify/summary";
import { exportTables, nightly } from "./maintenance";

// Must match "triggers.crons" in wrangler.jsonc.
export const CRONS = { hourly: "0 * * * *", nightly: "30 9 * * *", weekly: "0 11 * * 1" } as const;

export async function runCron(cron: string, env: Env, scheduledTime: number): Promise<void> {
  const db = database(env.DB);
  if (cron === CRONS.hourly) {
    console.log("daily summary pushes queued", await enqueueDailyPushes(db, env.PUSH_QUEUE, scheduledTime));
  } else if (cron === CRONS.nightly) {
    console.log("nightly", JSON.stringify(await nightly(db, scheduledTime)));
  } else if (cron === CRONS.weekly) {
    console.log("exported", (await exportTables(db, env, scheduledTime)).length);
  } else {
    console.error("unknown cron", cron);
  }
}
