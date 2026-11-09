import { serverConfig } from "../../config";
import { mutualsOf } from "../../domain/mutuals";
import { loadGraph, relationIn, type SocialGraph, visibleFriendIds } from "../../domain/visibility";
import type { Env } from "../../env";
import type { Database } from "../../lib/db";
import { loadActivity } from "../friends/activity";
import { friendSummary, orderedSummaries, todayStatus, weekStats } from "../friends/summary";
import { personRef, type UserRow, usersById } from "../shared/people";
import type { PeopleResponse, SchoolSummary } from "./contract";

const MUTUAL_NAMES_SHOWN = 3;

export type SchoolSummaryLoader = (db: Database, viewer: string) => Promise<SchoolSummary | null>;

function viaNames(graph: SocialGraph, users: Map<string, UserRow>, id: string): string[] {
  return (graph.mutualVia.get(id) ?? [])
    .map((via) => users.get(via)?.displayName ?? "")
    .filter(Boolean)
    .sort((a, b) => a.localeCompare(b));
}

export async function loadPeople(
  db: Database,
  env: Env,
  viewer: string,
  school: SchoolSummaryLoader,
): Promise<PeopleResponse> {
  const now = Date.now();
  const graph = await loadGraph(db, viewer);
  const friendIds = visibleFriendIds(graph);
  const mutuals = mutualsOf(graph).slice(0, serverConfig.mutualsMax);
  const mutualIds = mutuals.map((m) => m.id).filter((id) => relationIn(graph, id) === "mutual");

  const friendActivity = await loadActivity(db, friendIds, now);
  const mutualActivity = await loadActivity(db, mutualIds, now);
  const named = await usersById(db, [...graph.incoming, ...graph.outgoing, ...friendIds]);

  const friends = friendIds.flatMap((id) => {
    const person = friendActivity.get(id);
    return person ? [friendSummary(env, person, graph.friendsSince.get(id) ?? 0)] : [];
  });

  return {
    requests: [...graph.incoming].flatMap((id) => {
      const user = named.get(id);
      if (!user) return [];
      return [
        { user: personRef(env, user), mutualNames: viaNames(graph, named, id).slice(0, MUTUAL_NAMES_SHOWN) },
      ];
    }),
    outgoing: [...graph.outgoing].flatMap((id) => {
      const user = named.get(id);
      return user ? [personRef(env, user)] : [];
    }),
    friends: orderedSummaries(friends),
    // Mutuals see level and trend only: never tags, pass lists or blocks (N-7).
    mutuals: mutualIds.flatMap((id) => {
      const person = mutualActivity.get(id);
      if (!person) return [];
      const names = viaNames(graph, named, id);
      return [
        {
          user: personRef(env, person.user),
          via: names.slice(0, 1),
          viaCount: graph.mutualVia.get(id)?.length ?? 0,
          level: todayStatus(person).level,
          trend: weekStats(person).trend,
        },
      ];
    }),
    school: await school(db, viewer),
  };
}
