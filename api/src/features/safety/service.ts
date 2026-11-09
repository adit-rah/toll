import { and, eq } from "drizzle-orm";
import type { z } from "zod";
import { copy } from "../../copy";
import { friendships, personBlocks, reports, users } from "../../db/schema";
import type { Env } from "../../env";
import type { Database } from "../../lib/db";
import { sendEmail } from "../../lib/email";
import { fail } from "../../lib/http";
import { pair } from "../friends/service";
import type { PersonRef } from "../shared/contract";
import { personRef, usersById } from "../shared/people";
import type { ReportRequest } from "./contract";

async function existing(db: Database, userId: string) {
  const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!user) fail(404, "not_found");
  return user;
}

// N-14: a block hides both people from each other everywhere and ends any friendship or request between them.
export async function blockPerson(db: Database, viewer: string, other: string): Promise<void> {
  if (viewer === other) fail(400, "self");
  await existing(db, other);
  await db.batch([
    db.delete(friendships).where(pair(viewer, other).where),
    db
      .insert(personBlocks)
      .values({ blockerId: viewer, blockedId: other, createdAt: Date.now() })
      .onConflictDoNothing(),
  ]);
}

// Unblocking makes the two visible to each other again; the friendship is not restored.
export async function unblockPerson(db: Database, viewer: string, other: string): Promise<void> {
  await db
    .delete(personBlocks)
    .where(and(eq(personBlocks.blockerId, viewer), eq(personBlocks.blockedId, other)));
}

// The viewer's own list of the people they blocked, so they can undo it (flows §22).
export async function blockedByViewer(db: Database, env: Env, viewer: string): Promise<PersonRef[]> {
  const rows = await db
    .select({ id: personBlocks.blockedId })
    .from(personBlocks)
    .where(eq(personBlocks.blockerId, viewer));
  const found = await usersById(
    db,
    rows.map((r) => r.id),
  );
  return rows.flatMap((r) => {
    const user = found.get(r.id);
    return user ? [personRef(env, user)] : [];
  });
}

export async function reportPerson(
  db: Database,
  env: Env,
  viewer: string,
  input: z.infer<typeof ReportRequest>,
): Promise<void> {
  if (input.userId === viewer) fail(400, "self");
  const subject = await existing(db, input.userId);
  const text = input.text?.trim() || null;
  await db.insert(reports).values({
    id: crypto.randomUUID(),
    reporterId: viewer,
    subjectId: subject.id,
    reason: input.reason,
    text,
    createdAt: Date.now(),
  });
  const subjectName = `${subject.displayName ?? ""} @${subject.handle ?? ""}`.trim();
  await sendEmail(env, {
    to: env.FOUNDERS_EMAIL,
    ...copy.report({ reason: input.reason, text, reporter: viewer, subject: subject.id, subjectName }),
  });
}
