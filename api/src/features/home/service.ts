import { eq } from "drizzle-orm";
import { defaultConfig, type Tag } from "../../config";
import { users } from "../../db/schema";
import { heldPercent } from "../../domain/rollups";
import { isLoosened } from "../../domain/schedule";
import { dayStartMs, HOUR_MS, offsetMinutesIn } from "../../domain/time";
import { loadGraph, visibleFriendIds } from "../../domain/visibility";
import type { Env } from "../../env";
import type { Database } from "../../lib/db";
import { type Activity, loadActivity } from "../friends/activity";
import { friendSummary, orderedSummaries, weekStats } from "../friends/summary";
import type { FriendSummary, Pinned, Schedule } from "../shared/contract";
import { chunked, personRef } from "../shared/people";
import type { HomeResponse } from "./contract";

interface ChangeRow {
  user_id: string;
  type: "block_removed" | "block_changed";
  block_ref: string | null;
  occurred_at: number;
  payload: string | null;
}

interface ChangePayload {
  appRefs?: string[];
  schedule?: Schedule;
  oldSchedule?: Schedule;
}

function tagsFor(person: Activity, appRefs: string[]): (Tag | null)[] {
  return [...new Set(appRefs.map((ref) => person.tags.get(ref) ?? null))];
}

async function changePins(
  db: Database,
  env: Env,
  people: Map<string, Activity>,
  friendIds: string[],
  now: number,
) {
  const since = now - defaultConfig.network.pinHours * HOUR_MS;
  const rows = await chunked(friendIds, async (chunk) => {
    const marks = chunk.map((_, i) => `?${i + 2}`).join(", ");
    const { results } = await db.$client
      .prepare(
        `SELECT user_id, type, block_ref, occurred_at, payload FROM events
         WHERE type IN ('block_removed', 'block_changed') AND occurred_at >= ?1 AND user_id IN (${marks})`,
      )
      .bind(since, ...chunk)
      .all<ChangeRow>();
    return results;
  });
  const pins: Pinned[] = [];
  for (const row of rows) {
    const person = people.get(row.user_id);
    if (!person) continue;
    const payload = (row.payload ? JSON.parse(row.payload) : {}) as ChangePayload;
    const block = person.blocks.find((b) => b.blockRef === row.block_ref);
    const appRefs = payload.appRefs ?? block?.appRefs ?? [];
    const user = personRef(env, person.user);
    if (row.type === "block_removed") {
      const schedule = payload.oldSchedule ?? payload.schedule ?? null;
      pins.push({ kind: "removal", user, tags: tagsFor(person, appRefs), schedule, since: row.occurred_at });
    } else if (payload.oldSchedule && payload.schedule && isLoosened(payload.oldSchedule, payload.schedule)) {
      pins.push({
        kind: "loosened",
        user,
        tags: tagsFor(person, appRefs),
        schedule: payload.schedule,
        since: row.occurred_at,
      });
    }
  }
  return pins;
}

function silencePins(summaries: FriendSummary[], people: Map<string, Activity>, now: number): Pinned[] {
  return summaries.flatMap((summary) => {
    const person = people.get(summary.user.id);
    if (!summary.silentSince || !person) return [];
    const offset = offsetMinutesIn(person.user.timezone, now);
    return [
      {
        kind: "silence" as const,
        user: summary.user,
        tags: [...new Set(person.blocks.flatMap((b) => b.tags))],
        schedule: null,
        since: dayStartMs(summary.silentSince, offset, defaultConfig.gate.dayResetHour),
      },
    ];
  });
}

// N-4: held ÷ hits this week across every friend and the viewer, each in their own week.
export function groupHeldPercent(people: Activity[]): number | null {
  let held = 0;
  let hits = 0;
  for (const person of people) {
    const week = weekStats(person);
    held += week.held;
    hits += week.hits;
  }
  return heldPercent(held, hits);
}

export async function loadHome(db: Database, env: Env, viewer: string): Promise<HomeResponse> {
  const now = Date.now();
  const graph = await loadGraph(db, viewer, false);
  const friendIds = visibleFriendIds(graph);
  const people = await loadActivity(db, [viewer, ...friendIds], now);
  const summaries = friendIds.flatMap((id) => {
    const person = people.get(id);
    return person ? [friendSummary(env, person, graph.friendsSince.get(id) ?? 0)] : [];
  });

  const silence = silencePins(summaries, people, now).sort((a, b) => b.since - a.since);
  const changes = (await changePins(db, env, people, friendIds, now)).sort((a, b) => b.since - a.since);
  // Weekly lookers (spec §1) are counted from this timestamp.
  await db.update(users).set({ lastHomeAt: now }).where(eq(users.id, viewer));

  return {
    friends: orderedSummaries(summaries),
    pinned: [...silence, ...changes],
    friendsHeldPercent: groupHeldPercent([...people.values()]),
    pendingRequests: graph.incoming.size,
    asOf: now,
  };
}
