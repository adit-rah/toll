import { serverConfig } from "../../config";
import { loadGraph, relationIn } from "../../domain/visibility";
import type { Env } from "../../env";
import type { Database } from "../../lib/db";
import { fail } from "../../lib/http";
import { loadActivity } from "../friends/activity";
import { todayStatus } from "../friends/summary";
import { personRef, usersById } from "../shared/people";
import type { SchoolMembersResponse } from "./contract";
import { membership } from "./service";

const ORDER = { friend: 0, mutual: 1, requested: 2, none: 3 } as const;

// N-8, N-16: members find mutuals at their school. Strangers see a display name and handle only (A21).
export async function schoolMembers(db: Database, env: Env, viewer: string): Promise<SchoolMembersResponse> {
  const school = await membership(db, viewer);
  if (!school) fail(404, "not_found");
  const { results } = await db.$client
    .prepare("SELECT user_id FROM school_memberships WHERE school_id = ? AND user_id != ? LIMIT ?")
    .bind(school.id, viewer, serverConfig.schoolMembersMax)
    .all<{ user_id: string }>();
  const graph = await loadGraph(db, viewer);
  const ids = results.map((r) => r.user_id).filter((id) => !graph.blocked.has(id));
  const users = await usersById(db, ids);
  const visible = ids.filter((id) => relationIn(graph, id) !== "none");
  const activity = await loadActivity(db, visible, Date.now());

  const members = ids.flatMap((id) => {
    const user = users.get(id);
    if (!user?.handle) return [];
    const rel = relationIn(graph, id);
    const pending = graph.incoming.has(id) || graph.outgoing.has(id);
    const relation = rel === "friend" ? rel : pending ? ("requested" as const) : rel;
    const ref = personRef(env, user);
    const known = rel !== "none";
    const person = activity.get(id);
    return [
      {
        user: known ? ref : { ...ref, photoUrl: null },
        relation,
        level: known && person ? todayStatus(person).level : null,
      },
    ];
  });
  members.sort(
    (a, b) =>
      ORDER[a.relation] - ORDER[b.relation] ||
      a.user.displayName.localeCompare(b.user.displayName, "en", { sensitivity: "base" }),
  );
  return { members };
}
