import { defaultConfig, TAGS, type Tag } from "../../config";
import { addDays, DAY_MS, type TollTime, tollTimeIn } from "../../domain/time";
import type { Database } from "../../lib/db";
import type { PassLine, Schedule } from "../shared/contract";
import { chunked, type UserRow, usersById } from "../shared/people";

const { dayResetHour } = defaultConfig.gate;
// Enough daily rows for a 28-day status history plus this week and last week.
const DAILY_LOOKBACK_DAYS = 36;

export interface DailyRow {
  user_id: string;
  day: string;
  passes: number;
  free: number;
  waited: number;
  hits: number;
  held: number;
  abandoned: number;
  wait_minutes: number;
  active: number;
  level: number | null;
}

export interface Activity {
  user: UserRow;
  now: TollTime;
  days: Map<string, DailyRow>;
  passes: PassLine[];
  latestPass: PassLine | null;
  blocks: {
    blockRef: string;
    appRefs: string[];
    tags: (Tag | null)[];
    schedule: Schedule;
    updatedAt: number;
  }[];
  lastActiveDay: string | null;
  tags: Map<string, Tag>;
}

interface PassRow {
  user_id: string;
  occurred_at: number;
  tz_offset: number;
  free: number | null;
  wait_minutes: number | null;
  tag: string | null;
}

const asTag = (tag: string | null | undefined): Tag | null =>
  tag && (TAGS as readonly string[]).includes(tag) ? (tag as Tag) : null;

const passLine = (row: PassRow): PassLine => ({
  at: row.occurred_at,
  tzOffset: row.tz_offset,
  tag: asTag(row.tag),
  free: row.free === 1,
  waitMinutes: row.wait_minutes ?? 0,
});

// `leading` binds ?1…?n; the id list takes the numbers after them.
async function rows<T>(db: Database, ids: string[], sql: (inList: string) => string, ...leading: unknown[]) {
  return chunked(ids, async (chunk) => {
    const inList = chunk.map((_, i) => `?${i + leading.length + 1}`).join(", ");
    const { results } = await db.$client
      .prepare(sql(inList))
      .bind(...leading, ...chunk)
      .all<T>();
    return results;
  });
}

const PASS_SELECT = `SELECT e.user_id, e.occurred_at, e.tz_offset, e.free, e.wait_minutes, a.tag
  FROM events e LEFT JOIN app_refs a ON a.user_id = e.user_id AND a.app_ref = e.app_ref`;

/**
 * Loads what Home, People and Insights show about a set of people. Callers pass only ids that
 * visibility.ts allowed for the viewer (the viewer's own id included).
 */
export async function loadActivity(
  db: Database,
  ids: string[],
  nowMs: number,
): Promise<Map<string, Activity>> {
  const unique = [...new Set(ids)];
  const users = await usersById(db, unique);
  const sinceDay = addDays(new Date(nowMs).toISOString().slice(0, 10), -DAILY_LOOKBACK_DAYS);
  const [daily, passes, latest, blocks, tags, lastActive] = await Promise.all([
    rows<DailyRow>(
      db,
      unique,
      (l) => `SELECT * FROM rollups_daily WHERE day >= ?1 AND user_id IN (${l})`,
      sinceDay,
    ),
    rows<PassRow>(
      db,
      unique,
      (l) =>
        `${PASS_SELECT} WHERE e.type = 'pass' AND e.occurred_at >= ?1 AND e.user_id IN (${l}) ORDER BY e.occurred_at`,
      nowMs - 3 * DAY_MS,
    ),
    rows<PassRow>(
      db,
      unique,
      (l) => `${PASS_SELECT} WHERE e.type = 'pass' AND e.user_id IN (${l}) AND e.occurred_at = (
        SELECT MAX(x.occurred_at) FROM events x WHERE x.user_id = e.user_id AND x.type = 'pass' AND x.occurred_at <= ?1)`,
      nowMs,
    ),
    rows<{ user_id: string; block_ref: string; schedule: string; app_refs: string; updated_at: number }>(
      db,
      unique,
      (l) => `SELECT * FROM blocks_meta WHERE user_id IN (${l}) ORDER BY updated_at`,
    ),
    rows<{ user_id: string; app_ref: string; tag: string }>(
      db,
      unique,
      (l) => `SELECT user_id, app_ref, tag FROM app_refs WHERE user_id IN (${l})`,
    ),
    rows<{ user_id: string; day: string }>(
      db,
      unique,
      (l) =>
        `SELECT user_id, MAX(day) AS day FROM rollups_daily WHERE active = ?1 AND user_id IN (${l}) GROUP BY user_id`,
      1,
    ),
  ]);

  const out = new Map<string, Activity>();
  for (const id of unique) {
    const user = users.get(id);
    if (!user) continue;
    out.set(id, {
      user,
      now: tollTimeIn(user.timezone, nowMs, dayResetHour),
      days: new Map(),
      passes: [],
      latestPass: null,
      blocks: [],
      lastActiveDay: null,
      tags: new Map(),
    });
  }
  for (const row of tags) {
    const tag = asTag(row.tag);
    if (tag) out.get(row.user_id)?.tags.set(row.app_ref, tag);
  }
  for (const row of daily) out.get(row.user_id)?.days.set(row.day, row);
  for (const row of passes) out.get(row.user_id)?.passes.push(passLine(row));
  for (const row of latest) {
    const person = out.get(row.user_id);
    if (person && !person.latestPass) person.latestPass = passLine(row);
  }
  for (const row of lastActive) {
    const person = out.get(row.user_id);
    if (person) person.lastActiveDay = row.day;
  }
  for (const row of blocks) {
    const person = out.get(row.user_id);
    if (!person) continue;
    const appRefs = JSON.parse(row.app_refs) as string[];
    person.blocks.push({
      blockRef: row.block_ref,
      appRefs,
      tags: [...new Set(appRefs.map((ref) => person.tags.get(ref) ?? null))],
      schedule: JSON.parse(row.schedule) as Schedule,
      updatedAt: row.updated_at,
    });
  }
  return out;
}
