import type { Database } from "../lib/db";

export type Relation = "none" | "mutual" | "friend";

// One person's view of the network. Every read of another person's data asks this (CLAUDE.md, spec §11.2).
export interface SocialGraph {
  viewer: string;
  friends: Set<string>;
  friendsSince: Map<string, number>;
  incoming: Set<string>;
  outgoing: Set<string>;
  blocked: Set<string>;
  // Friends of friends who are not the viewer, not friends and not blocked either way, with the friends between.
  mutualVia: Map<string, string[]>;
}

interface FriendshipRow {
  user_lo: string;
  user_hi: string;
  status: "requested" | "accepted";
  requested_by: string;
  accepted_at: number | null;
}

export async function loadGraph(db: Database, viewer: string, withMutuals = true): Promise<SocialGraph> {
  const d1 = db.$client;
  const [edges, blocks] = await d1.batch([
    d1.prepare("SELECT * FROM friendships WHERE user_lo = ?1 OR user_hi = ?1").bind(viewer),
    d1
      .prepare("SELECT blocker_id, blocked_id FROM person_blocks WHERE blocker_id = ?1 OR blocked_id = ?1")
      .bind(viewer),
  ]);
  const blocked = new Set<string>();
  for (const row of (blocks?.results ?? []) as { blocker_id: string; blocked_id: string }[]) {
    blocked.add(row.blocker_id === viewer ? row.blocked_id : row.blocker_id);
  }

  const graph: SocialGraph = {
    viewer,
    friends: new Set(),
    friendsSince: new Map(),
    incoming: new Set(),
    outgoing: new Set(),
    blocked,
    mutualVia: new Map(),
  };
  for (const row of (edges?.results ?? []) as unknown as FriendshipRow[]) {
    const other = row.user_lo === viewer ? row.user_hi : row.user_lo;
    if (blocked.has(other)) continue;
    if (row.status === "accepted") {
      graph.friends.add(other);
      graph.friendsSince.set(other, row.accepted_at ?? 0);
    } else if (row.requested_by === viewer) {
      graph.outgoing.add(other);
    } else {
      graph.incoming.add(other);
    }
  }
  if (withMutuals && graph.friends.size > 0) await addMutuals(db, graph);
  return graph;
}

async function addMutuals(db: Database, graph: SocialGraph) {
  const { results } = await db.$client
    .prepare(
      `WITH mine AS (
         SELECT CASE WHEN user_lo = ?1 THEN user_hi ELSE user_lo END AS via
         FROM friendships WHERE status = 'accepted' AND (user_lo = ?1 OR user_hi = ?1)
       )
       SELECT mine.via AS via, CASE WHEN f.user_lo = mine.via THEN f.user_hi ELSE f.user_lo END AS other
       FROM mine JOIN friendships f ON f.status = 'accepted' AND (f.user_lo = mine.via OR f.user_hi = mine.via)`,
    )
    .bind(graph.viewer)
    .all<{ via: string; other: string }>();
  for (const { via, other } of results) {
    if (!graph.friends.has(via) || other === graph.viewer) continue;
    if (graph.friends.has(other) || graph.blocked.has(other)) continue;
    const list = graph.mutualVia.get(other) ?? [];
    list.push(via);
    graph.mutualVia.set(other, list);
  }
}

export function relationIn(graph: SocialGraph, subject: string): Relation {
  if (subject === graph.viewer || graph.blocked.has(subject)) return "none";
  if (graph.friends.has(subject)) return "friend";
  if (graph.mutualVia.has(subject)) return "mutual";
  return "none";
}

export async function relation(db: Database, viewer: string, subject: string): Promise<Relation> {
  return relationIn(await loadGraph(db, viewer), subject);
}

export async function blockedEitherWay(db: Database, a: string, b: string): Promise<boolean> {
  const row = await db.$client
    .prepare(
      "SELECT 1 FROM person_blocks WHERE (blocker_id = ?1 AND blocked_id = ?2) OR (blocker_id = ?2 AND blocked_id = ?1)",
    )
    .bind(a, b)
    .first();
  return row !== null;
}

export const visibleFriendIds = (graph: SocialGraph) => [...graph.friends];
