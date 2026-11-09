import { inArray } from "drizzle-orm";
import { users } from "../../db/schema";
import type { Env } from "../../env";
import type { Database } from "../../lib/db";
import type { PersonRef } from "./contract";

// D1 caps bound parameters per statement at 100; every IN list goes through this.
export const IN_CHUNK = 90;

export async function chunked<T, R>(items: T[], run: (chunk: T[]) => Promise<R[]>): Promise<R[]> {
  const out: R[] = [];
  for (let i = 0; i < items.length; i += IN_CHUNK) out.push(...(await run(items.slice(i, i + IN_CHUNK))));
  return out;
}

export function photoUrl(env: Env, key: string | null): string | null {
  return key ? `${env.PUBLIC_BASE_URL}/v1/photos/${key}` : null;
}

export type UserRow = typeof users.$inferSelect;

export function personRef(env: Env, user: UserRow): PersonRef {
  return {
    id: user.id,
    displayName: user.displayName ?? "",
    handle: user.handle ?? "",
    photoUrl: photoUrl(env, user.photoKey),
  };
}

export async function usersById(db: Database, ids: string[]): Promise<Map<string, UserRow>> {
  const unique = [...new Set(ids)];
  const rows = await chunked(unique, (chunk) => db.select().from(users).where(inArray(users.id, chunk)));
  return new Map(rows.map((row) => [row.id, row]));
}
