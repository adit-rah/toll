import { defaultConfig, serverConfig } from "../../config";
import { copy } from "../../copy";
import { compareByImprovement } from "../../domain/ordering";
import { trend } from "../../domain/rollups";
import { addDays, tollTimeIn, weekOf } from "../../domain/time";
import { loadGraph, visibleFriendIds } from "../../domain/visibility";
import type { PushMessage } from "../../env";
import type { Database } from "../../lib/db";
import { type Activity, loadActivity } from "../friends/activity";

export interface DueUser {
  id: string;
  notifyEnabled: boolean;
  devices: { token: string; environment: "production" | "sandbox" }[];
}

interface Candidate {
  id: string;
  timezone: string;
  notify_enabled: number;
  notify_hour: number | null;
  push_token: string;
  push_environment: "production" | "sandbox" | null;
}

/**
 * Everyone with a push token whose local hour is their summary hour. Background pushes go to all of them
 * so devices flush their daily check-in (N-9); the alert only to those with the summary on (N-13).
 */
export async function dueUsers(db: Database, nowMs: number): Promise<DueUser[]> {
  const due = new Map<string, DueUser>();
  for (let offset = 0; ; offset += serverConfig.pushBatchSize * 5) {
    const { results } = await db.$client
      .prepare(
        `SELECT u.id, u.timezone, u.notify_enabled, u.notify_hour, d.push_token, d.push_environment
         FROM devices d JOIN users u ON u.id = d.user_id
         WHERE d.push_token IS NOT NULL ORDER BY d.id LIMIT ? OFFSET ?`,
      )
      .bind(serverConfig.pushBatchSize * 5, offset)
      .all<Candidate>();
    for (const row of results) {
      const hour = row.notify_hour ?? defaultConfig.notify.hour;
      if (tollTimeIn(row.timezone, nowMs, 0).hour !== hour) continue;
      const user = due.get(row.id) ?? { id: row.id, notifyEnabled: row.notify_enabled === 1, devices: [] };
      user.devices.push({ token: row.push_token, environment: row.push_environment ?? "production" });
      due.set(row.id, user);
    }
    if (results.length < serverConfig.pushBatchSize * 5) break;
  }
  return [...due.values()];
}

// Week-to-date through `day` against the whole week before it.
function trendThrough(person: Activity, day: string): number | null {
  const week = weekOf(day);
  let passes = 0;
  let lastWeek = 0;
  for (let d = week; d <= day; d = addDays(d, 1)) passes += person.days.get(d)?.passes ?? 0;
  for (let d = addDays(week, -7); d < week; d = addDays(d, 1)) lastWeek += person.days.get(d)?.passes ?? 0;
  return trend(passes, lastWeek);
}

/**
 * Position uses the N-3 improvement order, as N-13 says, counting yourself: each person's trend for the
 * week that holds their yesterday, so a Monday summary ranks the finished week rather than six hours.
 */
export async function dailySummary(
  db: Database,
  userId: string,
  nowMs: number,
): Promise<{ body: string; requests: number }> {
  const graph = await loadGraph(db, userId, false);
  const friendIds = visibleFriendIds(graph);
  const people = await loadActivity(db, [userId, ...friendIds], nowMs);
  const me = people.get(userId);
  const yesterdayOf = (p: Activity) => addDays(p.now.day, -1);
  const passes = me ? (me.days.get(yesterdayOf(me))?.passes ?? 0) : 0;
  const ranked = [...people.values()]
    .map((p) => ({ id: p.user.id, trend: trendThrough(p, yesterdayOf(p)), name: p.user.displayName ?? "" }))
    .sort(compareByImprovement);
  const rank = friendIds.length > 0 ? ranked.findIndex((p) => p.id === userId) + 1 : null;
  const requests = graph.incoming.size;
  return { body: copy.dailySummary({ passes, rank, of: ranked.length, requests }), requests };
}

export async function dailyPushes(db: Database, nowMs: number): Promise<PushMessage[]> {
  const messages: PushMessage[] = [];
  for (const user of await dueUsers(db, nowMs)) {
    const summary = user.notifyEnabled ? await dailySummary(db, user.id, nowMs) : null;
    for (const device of user.devices) {
      messages.push({ deviceToken: device.token, environment: device.environment, kind: "background" });
      if (summary) {
        messages.push({
          deviceToken: device.token,
          environment: device.environment,
          kind: "alert",
          body: summary.body,
          // Flows §17: a summary that mentions requests opens People.
          data: { route: summary.requests > 0 ? "people" : "home" },
        });
      }
    }
  }
  return messages;
}

export async function enqueueDailyPushes(db: Database, queue: Queue<PushMessage>, nowMs: number) {
  const messages = await dailyPushes(db, nowMs);
  for (let i = 0; i < messages.length; i += serverConfig.pushBatchSize) {
    await queue.sendBatch(messages.slice(i, i + serverConfig.pushBatchSize).map((body) => ({ body })));
  }
  return messages.length;
}
