import { serverConfig } from "../../config";
import { DAY_MS, tollTime } from "../../domain/time";
import type { Database } from "../../lib/db";
import { refreshSchoolRollups } from "../school/rollups";
import { recomputeWeeks } from "./service";

// Every week name any timezone could give the last `days` days (offsets span a day either side of UTC).
export function weeksSpanning(nowMs: number, days: number): string[] {
  const weeks = new Set<string>();
  for (let t = nowMs - (days + 1) * DAY_MS; t <= nowMs + DAY_MS; t += DAY_MS / 2) {
    weeks.add(tollTime(t, 0, 0).week);
  }
  return [...weeks].sort();
}

async function usersWithEventsSince(db: Database, sinceMs: number, after: string): Promise<string[]> {
  const { results } = await db.$client
    .prepare(
      `SELECT DISTINCT user_id FROM events WHERE occurred_at >= ? AND user_id > ? ORDER BY user_id LIMIT ?`,
    )
    .bind(sinceMs, after, serverConfig.nightlyUserBatch)
    .all<{ user_id: string }>();
  return results.map((r) => r.user_id);
}

/**
 * Rebuilds rollups for the weeks covering the last `days` days, for the given users or for everyone with an
 * event in that range (paged so one run stays inside the cron's limits), then the school aggregates.
 */
export async function recomputeRecent(db: Database, nowMs: number, days: number, userIds?: string[]) {
  const weeks = weeksSpanning(nowMs, days);
  let users = 0;
  if (userIds) {
    for (const id of userIds) await recomputeWeeks(db, id, weeks);
    users = userIds.length;
  } else {
    let after = "";
    for (;;) {
      const page = await usersWithEventsSince(db, nowMs - (days + 1) * DAY_MS, after);
      for (const id of page) await recomputeWeeks(db, id, weeks);
      users += page.length;
      if (page.length < serverConfig.nightlyUserBatch) break;
      after = page.at(-1) ?? after;
    }
  }
  await refreshSchoolRollups(db, weeks);
  return { users, weeks };
}
