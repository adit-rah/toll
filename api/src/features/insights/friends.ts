import { defaultConfig, serverConfig, TAGS, type Tag } from "../../config";
import { sturgesBins } from "../../domain/bins";
import { heldPercent } from "../../domain/rollups";
import { addDays, DAY_MS, HOUR_MS, tollTime } from "../../domain/time";
import { loadGraph, visibleFriendIds } from "../../domain/visibility";
import type { Env } from "../../env";
import type { Database } from "../../lib/db";
import { chunked, personRef, usersById } from "../shared/people";
import type { FriendsInsights } from "./contract";
import { hourRows, sumHours, type WeeklyRow, weeklyRows } from "./data";

const { lateStart, friendsMinN, maxBins } = defaultConfig.insights;
const { dayResetHour } = defaultConfig.gate;
const isLate = (hour: number) => hour >= lateStart || hour < dayResetHour;

// I-14: "3 of your friends opened TikTok after 11 p.m. this week." Counts people, never names them.
async function sameAppSameHour(db: Database, friendIds: string[], week: string) {
  const from = Date.parse(`${week}T00:00:00Z`) - 14 * HOUR_MS;
  const to = from + 8 * DAY_MS + 2 * HOUR_MS;
  const rows = await chunked(friendIds, async (chunk) => {
    const marks = chunk.map((_, i) => `?${i + 3}`).join(", ");
    const { results } = await db.$client
      .prepare(
        `SELECT e.user_id, e.occurred_at, e.tz_offset, a.tag FROM events e
         JOIN app_refs a ON a.user_id = e.user_id AND a.app_ref = e.app_ref
         WHERE e.type = 'pass' AND e.occurred_at >= ?1 AND e.occurred_at < ?2 AND e.user_id IN (${marks})`,
      )
      .bind(from, to, ...chunk)
      .all<{ user_id: string; occurred_at: number; tz_offset: number; tag: string }>();
    return results;
  });
  const people = new Map<Tag, Set<string>>();
  for (const row of rows) {
    const time = tollTime(row.occurred_at, row.tz_offset, dayResetHour);
    // "other" is many different apps, so it cannot be "the same app".
    if (time.week !== week || !isLate(time.hour) || row.tag === "other") continue;
    if (!(TAGS as readonly string[]).includes(row.tag)) continue;
    const tag = row.tag as Tag;
    people.set(tag, (people.get(tag) ?? new Set()).add(row.user_id));
  }
  let best: { tag: Tag; count: number } | null = null;
  for (const tag of TAGS) {
    const count = people.get(tag)?.size ?? 0;
    if (count >= 3 && count > (best?.count ?? 0)) best = { tag, count };
  }
  return best;
}

function weekly(rows: WeeklyRow[], weeks: string[]) {
  return weeks.map((week) => {
    const that = rows.filter((r) => r.week === week);
    const active = that.filter((r) => r.active_days > 0);
    const passes = active.reduce((sum, r) => sum + r.passes, 0);
    return {
      week,
      heldPercent: heldPercent(
        that.reduce((sum, r) => sum + r.held, 0),
        that.reduce((sum, r) => sum + r.hits, 0),
      ),
      passesPerPerson: active.length ? passes / active.length : null,
    };
  });
}

export async function friendsInsights(
  db: Database,
  env: Env,
  viewer: string,
  week: string,
): Promise<FriendsInsights> {
  const graph = await loadGraph(db, viewer, false);
  const friendIds = visibleFriendIds(graph);
  const everyone = [viewer, ...friendIds];
  const weeks = Array.from({ length: serverConfig.insightsWeeks }, (_, i) =>
    addDays(week, -7 * (serverConfig.insightsWeeks - 1 - i)),
  );
  const [rows, hours, users, late] = await Promise.all([
    weeklyRows(db, everyone, weeks[0] ?? week, week),
    hourRows(db, everyone, week),
    usersById(db, friendIds),
    sameAppSameHour(db, friendIds, week),
  ]);
  const thisWeek = new Map(rows.filter((r) => r.week === week).map((r) => [r.user_id, r]));

  const people = everyone.flatMap((id) => {
    const user = users.get(id);
    if (id !== viewer && !user) return [];
    const row = thisWeek.get(id);
    const [passes, hits, held] = [row?.passes ?? 0, row?.hits ?? 0, row?.held ?? 0];
    return [
      {
        user: id === viewer || !user ? null : personRef(env, user),
        isMe: id === viewer,
        passes,
        hits,
        held,
        heldPercent: heldPercent(held, hits),
      },
    ];
  });
  people.sort(
    (a, b) =>
      (b.heldPercent ?? -1) - (a.heldPercent ?? -1) ||
      (a.user?.displayName ?? "").localeCompare(b.user?.displayName ?? ""),
  );

  const mine = thisWeek.get(viewer)?.passes ?? 0;
  const enoughFriends = friendIds.length >= friendsMinN;
  const totals = people.reduce((t, p) => ({ held: t.held + p.held, hits: t.hits + p.hits }), {
    held: 0,
    hits: 0,
  });
  return {
    week,
    people,
    distribution: enoughFriends
      ? {
          bins: sturgesBins(
            people.map((p) => p.passes),
            maxBins,
            mine,
          ),
        }
      : null,
    friendsByHour: sumHours(friendIds.map((id) => hours.get(id))),
    myByHour: sumHours([hours.get(viewer)]),
    weekly: weekly(rows, weeks),
    sameAppSameHour: late,
    friendsHeldPercent: heldPercent(totals.held, totals.hits),
  };
}
