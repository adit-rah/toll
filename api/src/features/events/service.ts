import { and, eq, inArray } from "drizzle-orm";
import type { BatchItem } from "drizzle-orm/batch";
import { serverConfig } from "../../config";
import { blocksMeta, events } from "../../db/schema";
import type { Database } from "../../lib/db";
import { GateEvent, type IngestResult } from "./contract";

const DAY_MS = 86_400_000;

export interface IngestWindow {
  maxAgeDays: number;
}

// An older event arriving late (outbox retry, history upload) must neither undo a newer change nor bring
// back a block whose removal is already stored. Runs after the events themselves are stored.
const UPSERT_BLOCK = `
  INSERT INTO blocks_meta (user_id, block_ref, schedule, app_refs, updated_at)
  SELECT ?1, ?2, ?3, COALESCE(?4, '[]'), ?5
  WHERE NOT EXISTS (
    SELECT 1 FROM events WHERE user_id = ?1 AND block_ref = ?2 AND type = 'block_removed' AND occurred_at > ?5
  )
  ON CONFLICT (user_id, block_ref) DO UPDATE SET
    schedule = excluded.schedule,
    app_refs = COALESCE(?4, blocks_meta.app_refs),
    updated_at = excluded.updated_at
  WHERE blocks_meta.updated_at <= excluded.updated_at`;

const REMOVE_BLOCK = "DELETE FROM blocks_meta WHERE user_id = ?1 AND block_ref = ?2 AND updated_at <= ?3";

function blockStatement(d1: D1Database, userId: string, event: GateEvent): D1PreparedStatement[] {
  if (!event.blockRef) return [];
  if (event.type === "block_removed") {
    return [d1.prepare(REMOVE_BLOCK).bind(userId, event.blockRef, event.occurredAt)];
  }
  if ((event.type !== "block_added" && event.type !== "block_changed") || !event.schedule) return [];
  const appRefs = event.appRefs ? JSON.stringify(event.appRefs) : null;
  return [
    d1
      .prepare(UPSERT_BLOCK)
      .bind(userId, event.blockRef, JSON.stringify(event.schedule), appRefs, event.occurredAt),
  ];
}

// A removal pin needs the removed block's apps after its blocks_meta row is gone, so they ride on the event.
async function withRemovedAppRefs(db: Database, userId: string, accepted: GateEvent[]) {
  const missing = accepted.filter((e) => e.type === "block_removed" && !e.appRefs && e.blockRef);
  if (missing.length === 0) return accepted;
  const refs = [...new Set(missing.map((e) => e.blockRef ?? ""))].slice(0, 90);
  const rows = await db
    .select()
    .from(blocksMeta)
    .where(and(eq(blocksMeta.userId, userId), inArray(blocksMeta.blockRef, refs)));
  const byRef = new Map(rows.map((r) => [r.blockRef, { appRefs: r.appRefs, schedule: r.schedule }]));
  // The block may have been added in this same batch, before its row exists.
  for (const e of [...accepted].sort((a, b) => a.occurredAt - b.occurredAt)) {
    if ((e.type !== "block_added" && e.type !== "block_changed") || !e.blockRef) continue;
    const prior = byRef.get(e.blockRef);
    byRef.set(e.blockRef, {
      appRefs: e.appRefs ?? prior?.appRefs ?? [],
      schedule: e.schedule ?? prior?.schedule,
    });
  }
  return accepted.map((e) => {
    const known = e.type === "block_removed" && !e.appRefs ? byRef.get(e.blockRef ?? "") : undefined;
    return known
      ? { ...e, appRefs: known.appRefs, oldSchedule: e.oldSchedule ?? (known.schedule as never) }
      : e;
  });
}

export async function ingestEvents(
  db: Database,
  userId: string,
  deviceId: string,
  raw: unknown[],
  window: IngestWindow,
): Promise<IngestResult & { events: GateEvent[] }> {
  const now = Date.now();
  const oldest = now - window.maxAgeDays * DAY_MS;
  const newest = now + serverConfig.eventSkewDays * DAY_MS;
  const rejected: IngestResult["rejected"] = [];
  let accepted: GateEvent[] = [];
  for (const item of raw) {
    const parsed = GateEvent.safeParse(item);
    if (!parsed.success) {
      const id = (item as { id?: unknown })?.id;
      rejected.push({ id: typeof id === "string" ? id : "", reason: "invalid" });
    } else if (parsed.data.occurredAt < oldest || parsed.data.occurredAt > newest) {
      rejected.push({ id: parsed.data.id, reason: "skew" });
    } else {
      accepted.push(parsed.data);
    }
  }
  if (accepted.length === 0) return { accepted: [], rejected, events: [] };

  accepted = await withRemovedAppRefs(db, userId, accepted);
  const ordered = [...accepted].sort((a, b) => a.occurredAt - b.occurredAt);
  const statements: BatchItem<"sqlite">[] = ordered.flatMap((event) => [
    db
      .insert(events)
      .values({
        eventId: event.id,
        userId,
        deviceId,
        type: event.type,
        appRef: event.appRef ?? null,
        blockRef: event.blockRef ?? null,
        occurredAt: event.occurredAt,
        tzOffset: event.tzOffset,
        receivedAt: now,
        waitMinutes: event.waitMinutes ?? null,
        free: event.free ?? null,
        sessionMinutes: event.sessionMinutes ?? null,
        payload: {
          appRefs: event.appRefs,
          via: event.via,
          schedule: event.schedule,
          oldSchedule: event.oldSchedule,
        },
      })
      .onConflictDoNothing({ target: events.eventId }),
  ]);
  const [first, ...rest] = statements;
  if (first) await db.batch([first, ...rest]);
  const blockChanges = ordered.flatMap((event) => blockStatement(db.$client, userId, event));
  if (blockChanges.length) await db.$client.batch(blockChanges);
  return { accepted: accepted.map((e) => e.id), rejected, events: ordered };
}
