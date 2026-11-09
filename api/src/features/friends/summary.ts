import { defaultConfig } from "../../config";
import { orderByImprovement } from "../../domain/ordering";
import { trend } from "../../domain/rollups";
import { type Level, PERSONALISED_HISTORY_DAYS, statusLevel } from "../../domain/status";
import { addDays, daysBetween, tollTime } from "../../domain/time";
import type { Env } from "../../env";
import type { FriendSummary, WeekStats } from "../shared/contract";
import { personRef } from "../shared/people";
import type { Activity } from "./activity";

const { dayResetHour } = defaultConfig.gate;

function sumDays(person: Activity, from: string, to: string) {
  const total = { passes: 0, hits: 0, held: 0, waited: 0, waitMinutes: 0, cleanDays: 0 };
  for (let day = from; day < to; day = addDays(day, 1)) {
    const row = person.days.get(day);
    if (!row) continue;
    total.passes += row.passes;
    total.hits += row.hits;
    total.held += row.held;
    total.waited += row.waited;
    total.waitMinutes += row.wait_minutes;
    if (row.active && row.passes === 0) total.cleanDays++;
  }
  return total;
}

// "This week" is always the person's own week in their own timezone.
export function weekStats(person: Activity): WeekStats {
  const week = person.now.week;
  const current = sumDays(person, week, addDays(week, 7));
  const lastWeek = sumDays(person, addDays(week, -7), week).passes;
  return {
    passes: current.passes,
    lastWeek,
    trend: trend(current.passes, lastWeek),
    cleanDays: current.cleanDays,
    hits: current.hits,
    held: current.held,
    waited: current.waited,
    waitMinutes: current.waitMinutes,
  };
}

export function todayStatus(person: Activity): { passes: number; level: Level | null } {
  const today = person.now.day;
  const passes = person.days.get(today)?.passes ?? 0;
  const history: number[] = [];
  for (let day = addDays(today, -PERSONALISED_HISTORY_DAYS); day < today; day = addDays(day, 1)) {
    const row = person.days.get(day);
    if (row?.active) history.push(row.passes);
  }
  if (history.length === 0 && !person.days.has(today)) return { passes, level: null };
  return { passes, level: statusLevel(passes, history, defaultConfig.status) };
}

/**
 * N-9: with blocks on, a device checks in daily; after `silenceMissedCheckins` whole days without any event
 * the person is silent from the first missed day. A person who never sent an event counts from the day
 * their first block was saved.
 */
export function silentSince(person: Activity): string | null {
  if (person.blocks.length === 0) return null;
  const firstBlock = Math.min(...person.blocks.map((b) => b.updatedAt));
  const lastSeen = person.lastActiveDay ?? addDays(tollTime(firstBlock, 0, dayResetHour).day, -1);
  const missed = daysBetween(lastSeen, person.now.day) - 1;
  return missed >= defaultConfig.network.silenceMissedCheckins ? addDays(lastSeen, 1) : null;
}

export function friendSummary(env: Env, person: Activity, friendsSince: number): FriendSummary {
  const dayOf = (at: number, offset: number) => tollTime(at, offset, dayResetHour).day;
  const yesterday = addDays(person.now.day, -1);
  return {
    user: personRef(env, person.user),
    today: todayStatus(person),
    week: weekStats(person),
    silentSince: silentSince(person),
    latestPass: person.latestPass,
    todayPasses: person.passes.filter((p) => dayOf(p.at, p.tzOffset) === person.now.day),
    yesterdayPasses: person.passes.filter((p) => dayOf(p.at, p.tzOffset) === yesterday),
    blocks: person.blocks.map(({ tags, schedule }) => ({ tags, schedule })),
    friendsSince,
  };
}

export function orderedSummaries(summaries: FriendSummary[]): FriendSummary[] {
  return orderByImprovement(summaries, (s) => ({ trend: s.week.trend, name: s.user.displayName }));
}
