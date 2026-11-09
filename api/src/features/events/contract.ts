import { z } from "zod";
import { serverConfig } from "../../config";
import { Schedule } from "../shared/contract";

const ref = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/);

export const EVENT_TYPES = [
  "block_hit",
  "wait_started",
  "wait_completed",
  "wait_abandoned",
  "pass",
  "session_ended",
  "block_added",
  "block_changed",
  "block_removed",
  "checkin",
] as const;
export type EventType = (typeof EVENT_TYPES)[number];

export const GateEvent = z.object({
  id: z.uuid(),
  type: z.enum(EVENT_TYPES),
  occurredAt: z.number().int(),
  tzOffset: z
    .number()
    .int()
    .min(-14 * 60)
    .max(14 * 60),
  appRef: ref.optional(),
  blockRef: ref.optional(),
  appRefs: z.array(ref).max(100).optional(),
  via: z.enum(["open", "dismiss"]).optional(),
  free: z.boolean().optional(),
  waitMinutes: z.number().int().min(0).max(1440).optional(),
  sessionMinutes: z.number().int().min(0).max(1440).optional(),
  schedule: Schedule.optional(),
  oldSchedule: Schedule.optional(),
});
export type GateEvent = z.infer<typeof GateEvent>;

// Events are parsed one by one so a single bad event is rejected without failing its batch.
export const EventBatch = z.object({
  deviceId: z.string().min(1).max(100),
  events: z.array(z.unknown()).min(1).max(serverConfig.eventBatchMax),
});

export const IngestResult = z.object({
  accepted: z.array(z.string()),
  rejected: z.array(z.object({ id: z.string(), reason: z.enum(["skew", "invalid"]) })),
});
export type IngestResult = z.infer<typeof IngestResult>;
