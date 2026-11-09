import type { SocialGraph } from "./visibility";

export interface Mutual {
  id: string;
  via: string[];
}

// N-7: friends of friends who are not friends, not you, not blocked either way, and not already asked.
export function mutualsOf(graph: SocialGraph): Mutual[] {
  const out: Mutual[] = [];
  for (const [id, via] of graph.mutualVia) {
    if (graph.incoming.has(id) || graph.outgoing.has(id)) continue;
    out.push({ id, via: [...new Set(via)] });
  }
  return out.sort((a, b) => b.via.length - a.via.length || a.id.localeCompare(b.id));
}
