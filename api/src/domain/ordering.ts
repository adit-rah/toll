export interface Rankable {
  trend: number | null;
  name: string;
}

// N-3: best improvement against one's own last week first (most negative trend), never by level; people
// with no last week to compare against follow, and names break ties.
export function compareByImprovement(a: Rankable, b: Rankable): number {
  if (a.trend !== null && b.trend !== null && a.trend !== b.trend) return a.trend - b.trend;
  if (a.trend === null && b.trend !== null) return 1;
  if (a.trend !== null && b.trend === null) return -1;
  return a.name.localeCompare(b.name, "en", { sensitivity: "base" });
}

export function orderByImprovement<T>(items: T[], key: (item: T) => Rankable): T[] {
  return [...items].sort((a, b) => compareByImprovement(key(a), key(b)));
}
