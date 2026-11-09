import type { GateEvent } from "../src/features/events/contract";
import type { TestUser } from "./accounts";
import { call } from "./helpers";

export const MINUTE = 60_000;
export const HOUR = 60 * MINUTE;
export const DAY = 24 * HOUR;

export function ev(type: GateEvent["type"], occurredAt: number, extra: Partial<GateEvent> = {}): GateEvent {
  return { id: crypto.randomUUID(), type, occurredAt, tzOffset: -300, ...extra };
}

export async function upload(user: TestUser, events: GateEvent[], path = "/v1/events") {
  const res = await call(path, { method: "POST", token: user.token, json: { deviceId: "phone", events } });
  return {
    status: res.status,
    body: (await res.json()) as { accepted: string[]; rejected: { id: string; reason: string }[] },
  };
}

// A local wall-clock time in a fixed-offset zone, as epoch ms (offset in minutes, e.g. -300 for EST).
export function local(iso: string, offsetMinutes = -300): number {
  return Date.parse(`${iso}Z`) - offsetMinutes * MINUTE;
}
