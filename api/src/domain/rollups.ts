import { type GateFact, heldFlags } from "./held";
import { tollTime } from "./time";

export interface StoredEvent extends GateFact {
  tzOffset: number;
  waitMinutes: number | null;
}

export interface Counts {
  passes: number;
  free: number;
  waited: number;
  hits: number;
  held: number;
  abandoned: number;
  waitMinutes: number;
}

export interface DayRollup extends Counts {
  day: string;
  active: boolean;
}

export interface WeekRollup extends Counts {
  cleanDays: number;
  activeDays: number;
}

export const emptyCounts = (): Counts => ({
  passes: 0,
  free: 0,
  waited: 0,
  hits: 0,
  held: 0,
  abandoned: 0,
  waitMinutes: 0,
});

// Events must be sorted by occurredAt; held needs the events that follow each hit.
export function dailyRollups(events: StoredEvent[], resetHour: number, resumeWindowMs: number) {
  const held = heldFlags(events, resumeWindowMs);
  const days = new Map<string, DayRollup>();
  events.forEach((event, index) => {
    const { day } = tollTime(event.occurredAt, event.tzOffset, resetHour);
    let row = days.get(day);
    if (!row) {
      row = { day, active: true, ...emptyCounts() };
      days.set(day, row);
    }
    if (event.type === "pass") {
      row.passes++;
      if (event.free) row.free++;
      else {
        row.waited++;
        row.waitMinutes += event.waitMinutes ?? 0;
      }
    } else if (event.type === "block_hit") {
      row.hits++;
      if (held[index]) row.held++;
    } else if (event.type === "wait_abandoned") {
      row.abandoned++;
    }
  });
  return days;
}

export function weeklyRollup(days: DayRollup[]): WeekRollup {
  const week: WeekRollup = { ...emptyCounts(), cleanDays: 0, activeDays: 0 };
  for (const day of days) {
    for (const key of Object.keys(emptyCounts()) as (keyof Counts)[]) week[key] += day[key];
    if (day.active) week.activeDays++;
    if (day.active && day.passes === 0) week.cleanDays++;
  }
  return week;
}

// Negative is improvement; undefined against an empty last week rather than infinite.
export function trend(passes: number, lastWeek: number): number | null {
  return lastWeek === 0 ? null : passes / lastWeek - 1;
}

export function passesByHour(events: StoredEvent[], resetHour: number, week: string): number[] {
  const hours = Array.from({ length: 24 }, () => 0);
  for (const event of events) {
    if (event.type !== "pass") continue;
    const time = tollTime(event.occurredAt, event.tzOffset, resetHour);
    if (time.week === week) hours[time.hour] = (hours[time.hour] ?? 0) + 1;
  }
  return hours;
}

export function heldPercent(held: number, hits: number): number | null {
  return hits === 0 ? null : Math.round((100 * held) / hits);
}
