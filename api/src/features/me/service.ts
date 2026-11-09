import { eq } from "drizzle-orm";
import { serverConfig } from "../../config";
import { contactHashes, invites, schoolMemberships, schools, users } from "../../db/schema";
import type { Env } from "../../env";
import { randomFrom, sha256Hex } from "../../lib/crypto";
import type { Database } from "../../lib/db";
import { fail } from "../../lib/http";
import type { Me } from "../shared/contract";
import { photoUrl } from "../shared/people";

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export async function contactHash(env: Env, value: string): Promise<string> {
  return sha256Hex(env.CONTACTS_SALT + value);
}

export function cleanDisplayName(raw: string | undefined | null): string | null {
  const name = raw?.trim().replace(/\s+/g, " ") ?? "";
  if (name.length < serverConfig.displayNameMin || name.length > serverConfig.displayNameMax) return null;
  return name;
}

export async function ensureInviteCode(db: Database, userId: string): Promise<string> {
  const [existing] = await db.select().from(invites).where(eq(invites.userId, userId)).limit(1);
  if (existing) return existing.code;
  for (;;) {
    const code = randomFrom(serverConfig.inviteAlphabet, serverConfig.inviteCodeLength);
    const inserted = await db
      .insert(invites)
      .values({ code, userId, createdAt: Date.now() })
      .onConflictDoNothing()
      .returning();
    if (inserted.length) return code;
  }
}

// Discoverability by contacts works on the server's own copy of the email hash, never the address.
export async function storeEmailContactHash(db: Database, env: Env, userId: string, email: string) {
  await db
    .insert(contactHashes)
    .values({ userId, hash: await contactHash(env, normalizeEmail(email)) })
    .onConflictDoNothing();
}

export async function createUser(
  db: Database,
  env: Env,
  input: { displayName?: string | null; email?: string | null },
): Promise<string> {
  const id = crypto.randomUUID();
  await db.insert(users).values({
    id,
    displayName: cleanDisplayName(input.displayName),
    email: input.email ?? null,
    createdAt: Date.now(),
  });
  await ensureInviteCode(db, id);
  if (input.email) await storeEmailContactHash(db, env, id, input.email);
  return id;
}

export async function loadMe(db: Database, env: Env, userId: string): Promise<Me> {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) fail(401, "unauthorized");
  const [school] = await db
    .select({ id: schools.id, name: schools.name })
    .from(schoolMemberships)
    .innerJoin(schools, eq(schools.id, schoolMemberships.schoolId))
    .where(eq(schoolMemberships.userId, userId))
    .limit(1);
  return {
    id: user.id,
    displayName: user.displayName,
    handle: user.handle,
    photoUrl: photoUrl(env, user.photoKey),
    email: user.email,
    discoverable: user.discoverable,
    timezone: user.timezone,
    notifyEnabled: user.notifyEnabled,
    notifyHour: user.notifyHour,
    handleChangedAt: user.handleChangedAt,
    school: school ?? null,
    inviteCode: await ensureInviteCode(db, userId),
    createdAt: user.createdAt,
  };
}
