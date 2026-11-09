import { defaultConfig } from "../../config";
import {
  type DayRollup,
  dailyRollups,
  passesByHour,
  type StoredEvent,
  weeklyRollup,
} from "../../domain/rollups";
import { PERSONALISED_HISTORY_DAYS, statusLevel } from "../../domain/status";
import { addDays, DAY_MS, HOUR_MS, tollTime } from "../../domain/time";
import type { Database } from "../../lib/db";

const { dayResetHour, resumeWindowSeconds } = defaultConfig.gate;
const resumeWindowMs = resumeWindowSeconds * 1000;

interface EventRow {
  type: string;
  occurred_at: number;
  tz_offset: number;
  free: number | null;
  wait_minutes: number | null;
}

export function weeksTouched(events: { occurredAt: number; tzOffset: number }[]): Set<string> {
  return new Set(events.map((e) => tollTime(e.occurredAt, e.tzOffset, dayResetHour).week));
}

// Offsets run from UTC-12 to UTC+14, so a week's events lie in this instant range whatever the zone.
function weekRange(week: string): [number, number] {
  const mondayReset = Date.parse(`${week}T00:00:00Z`) + dayResetHour * HOUR_MS;
  return [mondayReset - 14 * HOUR_MS, mondayReset + 7 * DAY_MS + 12 * HOUR_MS + resumeWindowMs];
}

async function weekEvents(db: Database, userId: string, week: string): Promise<StoredEvent[]> {
  const [from, to] = weekRange(week);
  const { results } = await db.$client
    .prepare(
      `SELECT type, occurred_at, tz_offset, free, wait_minutes FROM events
       WHERE user_id = ? AND occurred_at >= ? AND occurred_at <= ? ORDER BY occurred_at, received_at`,
    )
    .bind(userId, from, to)
    .all<EventRow>();
  return results.map((r) => ({
    type: r.type,
    occurredAt: r.occurred_at,
    tzOffset: r.tz_offset,
    free: r.free === null ? null : r.free === 1,
    waitMinutes: r.wait_minutes,
  }));
}

async function priorPasses(db: Database, userId: string, week: string): Promise<Map<string, number>> {
  const { results } = await db.$client
    .prepare(
      "SELECT day, passes FROM rollups_daily WHERE user_id = ? AND active = 1 AND day >= ? AND day < ?",
    )
    .bind(userId, addDays(week, -PERSONALISED_HISTORY_DAYS), week)
    .all<{ day: string; passes: number }>();
  return new Map(results.map((r) => [r.day, r.passes]));
}

const UPSERT_DAY = `INSERT INTO rollups_daily
  (user_id, day, passes, free, waited, hits, held, abandoned, wait_minutes, active, level)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
  ON CONFLICT (user_id, day) DO UPDATE SET passes = ?3, free = ?4, waited = ?5, hits = ?6, held = ?7,
    abandoned = ?8, wait_minutes = ?9, active = ?10, level = ?11`;

const UPSERT_WEEK = `INSERT INTO rollups_weekly
  (user_id, week, passes, free, waited, hits, held, abandoned, wait_minutes, clean_days, active_days, trend)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11,
    (SELECT CASE WHEN passes > 0 THEN ?3 * 1.0 / passes - 1 END FROM rollups_weekly WHERE user_id = ?1 AND week = ?12))
  ON CONFLICT (user_id, week) DO UPDATE SET passes = excluded.passes, free = excluded.free,
    waited = excluded.waited, hits = excluded.hits, held = excluded.held, abandoned = excluded.abandoned,
    wait_minutes = excluded.wait_minutes, clean_days = excluded.clean_days, active_days = excluded.active_days,
    trend = excluded.trend`;

const UPDATE_NEXT_TREND = `UPDATE rollups_weekly
  SET trend = CASE WHEN ?3 > 0 THEN passes * 1.0 / ?3 - 1 END WHERE user_id = ?1 AND week = ?2`;

export async function recomputeWeek(db: Database, userId: string, week: string): Promise<void> {
  const events = await weekEvents(db, userId, week);
  const allDays = dailyRollups(events, dayResetHour, resumeWindowMs);
  const days: DayRollup[] = [...allDays.values()]
    .filter((d) => d.day >= week && d.day < addDays(week, 7))
    .sort((a, b) => a.day.localeCompare(b.day));

  const history = await priorPasses(db, userId, week);
  const d1 = db.$client;
  const statements: D1PreparedStatement[] = days.map((day) => {
    const prior = [...history.entries()]
      .filter(([d]) => d < day.day && d >= addDays(day.day, -PERSONALISED_HISTORY_DAYS))
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([, passes]) => passes);
    history.set(day.day, day.passes);
    const level = statusLevel(day.passes, prior, defaultConfig.status);
    return d1
      .prepare(UPSERT_DAY)
      .bind(
        userId,
        day.day,
        day.passes,
        day.free,
        day.waited,
        day.hits,
        day.held,
        day.abandoned,
        day.waitMinutes,
        1,
        level,
      );
  });

  const w = weeklyRollup(days);
  statements.push(
    d1
      .prepare(UPSERT_WEEK)
      .bind(
        userId,
        week,
        w.passes,
        w.free,
        w.waited,
        w.hits,
        w.held,
        w.abandoned,
        w.waitMinutes,
        w.cleanDays,
        w.activeDays,
        addDays(week, -7),
      ),
    d1.prepare(UPDATE_NEXT_TREND).bind(userId, addDays(week, 7), w.passes),
    d1
      .prepare(
        "INSERT INTO hour_histograms (user_id, week, hours) VALUES (?1, ?2, ?3) ON CONFLICT (user_id, week) DO UPDATE SET hours = ?3",
      )
      .bind(userId, week, JSON.stringify(passesByHour(events, dayResetHour, week))),
  );
  await d1.batch(statements);
}

export async function recomputeWeeks(db: Database, userId: string, weeks: Iterable<string>): Promise<void> {
  for (const week of [...new Set(weeks)].sort()) await recomputeWeek(db, userId, week);
}
