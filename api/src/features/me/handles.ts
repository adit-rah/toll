import { and, inArray, ne } from "drizzle-orm";
import { serverConfig } from "../../config";
import { users } from "../../db/schema";
import type { Database } from "../../lib/db";

export const HANDLE_PATTERN = /^[a-z0-9_]{3,20}$/;
const MAX = 20;

function words(name: string | null | undefined): string[] {
  return (name ?? "")
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
}

const clip = (base: string, suffix = "") => base.slice(0, MAX - suffix.length) + suffix;

function variants(handle: string, name: string | null | undefined): string[] {
  const [first, ...rest] = words(name);
  const lastInitial = rest.at(-1)?.[0] ?? first?.[0];
  const out = [clip(handle, "2")];
  if (lastInitial) out.push(clip(handle, `_${lastInitial}`));
  for (let n = 3; n <= 9; n++) out.push(clip(handle, String(n)));
  for (let n = 0; n < 4; n++) out.push(clip(handle, String(10 + Math.floor(Math.random() * 90))));
  return out;
}

function fromName(name: string): string[] {
  const parts = words(name);
  const first = parts[0] ?? "";
  const last = parts.at(-1) ?? "";
  let base = first.length >= 3 ? first : parts.join("");
  if (base.length < 3) base = `${base}toll`.slice(0, Math.max(3, base.length));
  const out = [clip(base)];
  if (parts.length > 1) out.push(clip(base, `_${last[0]}`), clip(parts.join("")), clip(parts.join("_")));
  return [...out, ...variants(clip(base), name)];
}

async function takenAmong(db: Database, candidates: string[], exceptUserId?: string): Promise<Set<string>> {
  const filter = inArray(users.handle, candidates);
  const rows = await db
    .select({ handle: users.handle })
    .from(users)
    .where(exceptUserId ? and(filter, ne(users.id, exceptUserId)) : filter);
  return new Set(rows.map((r) => r.handle ?? ""));
}

async function firstAvailable(db: Database, candidates: string[], count: number, exceptUserId?: string) {
  const unique = [...new Set(candidates)].filter((h) => HANDLE_PATTERN.test(h));
  const taken = await takenAmong(db, unique, exceptUserId);
  return unique.filter((h) => !taken.has(h)).slice(0, count);
}

export async function checkHandle(
  db: Database,
  handle: string,
  viewer: { id: string; displayName: string | null },
): Promise<{ available: boolean; reason: "taken" | "invalid" | null; suggestions: string[] }> {
  if (!HANDLE_PATTERN.test(handle)) return { available: false, reason: "invalid", suggestions: [] };
  const taken = await takenAmong(db, [handle], viewer.id);
  if (!taken.has(handle)) return { available: true, reason: null, suggestions: [] };
  const suggestions = await firstAvailable(
    db,
    variants(handle, viewer.displayName),
    serverConfig.handleSuggestions,
    viewer.id,
  );
  return { available: false, reason: "taken", suggestions };
}

export async function suggestHandle(db: Database, name: string, viewerId: string): Promise<string> {
  const [best] = await firstAvailable(db, fromName(name), 1, viewerId);
  return best ?? clip(`toll${crypto.getRandomValues(new Uint32Array(1))[0]}`);
}
