import type { Env } from "../../env";
import { database } from "../../lib/db";
import { enqueueDailyPushes } from "../notify/summary";

export const CRONS = { hourly: "0 * * * *", nightly: "30 9 * * *", weekly: "0 11 * * 1" } as const;

export async function runCron(cron: string, env: Env, scheduledTime: number): Promise<void> {
  const db = database(env.DB);
  if (cron === CRONS.hourly) {
    const sent = await enqueueDailyPushes(db, env.PUSH_QUEUE, scheduledTime);
    console.log("daily summary pushes queued", sent);
  }
}
