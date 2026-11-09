import type { Database } from "../../lib/db";
import { chunked } from "../shared/people";

export interface WeeklyRow {
  user_id: string;
  week: string;
  passes: number;
  hits: number;
  held: number;
  active_days: number;
}

const marks = (n: number, from: number) => Array.from({ length: n }, (_, i) => `?${i + from}`).join(", ");

// Callers pass only ids visibility.ts allowed (the viewer and their friends).
export async function weeklyRows(db: Database, ids: string[], fromWeek: string, toWeek: string) {
  return chunked(ids, async (chunk) => {
    const { results } = await db.$client
      .prepare(
        `SELECT user_id, week, passes, hits, held, active_days FROM rollups_weekly
         WHERE week >= ?1 AND week <= ?2 AND user_id IN (${marks(chunk.length, 3)})`,
      )
      .bind(fromWeek, toWeek, ...chunk)
      .all<WeeklyRow>();
    return results;
  });
}

export async function hourRows(db: Database, ids: string[], week: string): Promise<Map<string, number[]>> {
  const rows = await chunked(ids, async (chunk) => {
    const { results } = await db.$client
      .prepare(
        `SELECT user_id, hours FROM hour_histograms WHERE week = ?1 AND user_id IN (${marks(chunk.length, 2)})`,
      )
      .bind(week, ...chunk)
      .all<{ user_id: string; hours: string }>();
    return results;
  });
  return new Map(rows.map((r) => [r.user_id, JSON.parse(r.hours) as number[]]));
}

export function sumHours(histograms: (number[] | undefined)[]): number[] {
  const out = Array.from({ length: 24 }, () => 0);
  for (const hours of histograms) {
    for (let h = 0; h < 24; h++) out[h] = (out[h] ?? 0) + (hours?.[h] ?? 0);
  }
  return out;
}
