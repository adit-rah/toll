import { and, eq } from "drizzle-orm";
import { friendships, invites, users } from "../../db/schema";
import { blockedEitherWay } from "../../domain/visibility";
import type { Env } from "../../env";
import type { Database } from "../../lib/db";
import { fail } from "../../lib/http";
import { allowed } from "../../lib/ratelimit";
import { personRef, type UserRow } from "../shared/people";
import type { FriendRequestResult } from "./contract";

export function pair(a: string, b: string) {
  const [userLo, userHi] = a < b ? [a, b] : [b, a];
  return { userLo, userHi, where: and(eq(friendships.userLo, userLo), eq(friendships.userHi, userHi)) };
}

export async function userByInviteCode(db: Database, code: string): Promise<UserRow | null> {
  const [row] = await db
    .select({ user: users })
    .from(invites)
    .innerJoin(users, eq(users.id, invites.userId))
    .where(eq(invites.code, code.trim().toUpperCase()))
    .limit(1);
  return row?.user ?? null;
}

export async function sendRequest(
  db: Database,
  env: Env,
  viewer: string,
  target: { userId?: string; code?: string },
): Promise<FriendRequestResult> {
  if (!(await allowed(env.RL_SOCIAL, viewer))) fail(429, "rate_limited");
  const other = target.code
    ? await userByInviteCode(db, target.code)
    : ((
        await db
          .select()
          .from(users)
          .where(eq(users.id, target.userId ?? ""))
          .limit(1)
      )[0] ?? null);
  if (!other) fail(404, "not_found");
  if (other.id === viewer) fail(400, "self");
  // Answering like an unknown person keeps a block from being detectable.
  if (await blockedEitherWay(db, viewer, other.id)) fail(404, "not_found");

  const { userLo, userHi, where } = pair(viewer, other.id);
  const [existing] = await db.select().from(friendships).where(where).limit(1);
  const user = personRef(env, other);
  if (existing?.status === "accepted") fail(409, "already_friends");
  if (existing && existing.requestedBy === viewer) return { status: "requested", user };
  if (existing) {
    await db.update(friendships).set({ status: "accepted", acceptedAt: Date.now() }).where(where);
    return { status: "accepted", user };
  }
  await db
    .insert(friendships)
    .values({ userLo, userHi, status: "requested", requestedBy: viewer, createdAt: Date.now() })
    .onConflictDoNothing();
  return { status: "requested", user };
}

export async function acceptRequest(db: Database, viewer: string, other: string): Promise<void> {
  const { where } = pair(viewer, other);
  const updated = await db
    .update(friendships)
    .set({ status: "accepted", acceptedAt: Date.now() })
    .where(and(where, eq(friendships.status, "requested"), eq(friendships.requestedBy, other)))
    .returning();
  if (updated.length === 0) fail(404, "not_found");
}

export async function declineRequest(db: Database, viewer: string, other: string): Promise<void> {
  const { where } = pair(viewer, other);
  await db
    .delete(friendships)
    .where(and(where, eq(friendships.status, "requested"), eq(friendships.requestedBy, other)));
}

export async function removeFriendship(db: Database, viewer: string, other: string): Promise<void> {
  await db.delete(friendships).where(pair(viewer, other).where);
}
