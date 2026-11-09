import { eq } from "drizzle-orm";
import type { z } from "zod";
import { defaultConfig } from "../../config";
import { devices, users } from "../../db/schema";
import { isValidTimeZone } from "../../domain/time";
import type { Database } from "../../lib/db";
import { fail } from "../../lib/http";
import type { DeviceRequest, PatchMeRequest } from "./contract";
import { HANDLE_PATTERN } from "./handles";
import { cleanDisplayName } from "./service";

const DAY_MS = 86_400_000;

function uniqueViolation(err: unknown): boolean {
  return String((err as Error)?.message ?? err).includes("UNIQUE");
}

export async function patchMe(db: Database, userId: string, patch: PatchMeRequest): Promise<void> {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) fail(401, "unauthorized");
  const set: Partial<typeof users.$inferInsert> = {};

  if (patch.displayName !== undefined) {
    const name = cleanDisplayName(patch.displayName);
    if (!name) fail(400, "name_invalid");
    set.displayName = name;
  }

  if (patch.handle !== undefined && patch.handle !== user.handle) {
    if (!HANDLE_PATTERN.test(patch.handle)) fail(400, "handle_invalid");
    // The first handle is part of sign-up and does not start the cooldown; every later change does.
    if (user.handle !== null && user.handleChangedAt !== null) {
      const availableAt = user.handleChangedAt + defaultConfig.identity.handleCooldownDays * DAY_MS;
      if (availableAt > Date.now()) fail(409, "handle_cooldown", { availableAt });
    }
    const [owner] = await db.select().from(users).where(eq(users.handle, patch.handle)).limit(1);
    if (owner) fail(409, "handle_taken");
    set.handle = patch.handle;
    if (user.handle !== null) set.handleChangedAt = Date.now();
  }

  if (patch.timezone !== undefined) {
    if (!isValidTimeZone(patch.timezone)) fail(400, "timezone_invalid");
    set.timezone = patch.timezone;
  }
  if (patch.discoverable !== undefined) set.discoverable = patch.discoverable;
  if (patch.notifyEnabled !== undefined) set.notifyEnabled = patch.notifyEnabled;
  if (patch.notifyHour !== undefined) set.notifyHour = patch.notifyHour;

  if (Object.keys(set).length === 0) return;
  try {
    await db.update(users).set(set).where(eq(users.id, userId));
  } catch (err) {
    if (uniqueViolation(err)) fail(409, "handle_taken");
    throw err;
  }
}

export async function registerDevice(
  db: Database,
  userId: string,
  input: z.infer<typeof DeviceRequest>,
): Promise<void> {
  if (!isValidTimeZone(input.timezone)) fail(400, "timezone_invalid");
  const now = Date.now();
  const set: Partial<typeof devices.$inferInsert> = { userId, timezone: input.timezone, updatedAt: now };
  if (input.pushToken !== undefined) set.pushToken = input.pushToken;
  if (input.pushEnvironment !== undefined) set.pushEnvironment = input.pushEnvironment;
  // A phone that signs into another account moves with it: the device row follows the latest session.
  await db.batch([
    db
      .insert(devices)
      .values({
        id: input.deviceId,
        userId,
        pushToken: input.pushToken ?? null,
        pushEnvironment: input.pushEnvironment ?? null,
        timezone: input.timezone,
        updatedAt: now,
      })
      .onConflictDoUpdate({ target: devices.id, set }),
    db.update(users).set({ timezone: input.timezone }).where(eq(users.id, userId)),
  ]);
}
