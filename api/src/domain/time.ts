export const MINUTE_MS = 60_000;
export const HOUR_MS = 60 * MINUTE_MS;
export const DAY_MS = 24 * HOUR_MS;

// Toll days are named by date ("YYYY-MM-DD"); a week is named by its Monday (spec §4).
export interface TollTime {
  day: string;
  week: string;
  hour: number;
  minuteOfDay: number;
  weekday: number;
}

const pad = (n: number) => String(n).padStart(2, "0");

function civil(date: Date): string {
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
}

// Date names are handled at UTC noon so no zone or DST can move them.
function noon(day: string): number {
  return Date.parse(`${day}T12:00:00Z`);
}

export function addDays(day: string, days: number): string {
  return civil(new Date(noon(day) + days * DAY_MS));
}

export function daysBetween(from: string, to: string): number {
  return Math.round((noon(to) - noon(from)) / DAY_MS);
}

export function isoWeekday(day: string): number {
  const sundayZero = new Date(noon(day)).getUTCDay();
  return sundayZero === 0 ? 7 : sundayZero;
}

export function weekOf(day: string): string {
  return addDays(day, 1 - isoWeekday(day));
}

export function isWeekName(text: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(text) && !Number.isNaN(noon(text)) && isoWeekday(text) === 1;
}

// The device sends its UTC offset with every event, so the event's own offset decides its day (spec §11.2).
export function tollTime(epochMs: number, offsetMinutes: number, resetHour: number): TollTime {
  const local = new Date(epochMs + offsetMinutes * MINUTE_MS);
  const hour = local.getUTCHours();
  const date = civil(local);
  const day = hour < resetHour ? addDays(date, -1) : date;
  const sundayZero = local.getUTCDay();
  return {
    day,
    week: weekOf(day),
    hour,
    minuteOfDay: hour * 60 + local.getUTCMinutes(),
    weekday: sundayZero === 0 ? 7 : sundayZero,
  };
}

export function isValidTimeZone(zone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: zone });
    return true;
  } catch {
    return false;
  }
}

export function offsetMinutesIn(zone: string, epochMs: number): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: isValidTimeZone(zone) ? zone : "UTC",
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(new Date(epochMs));
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? 0);
  const asUtc = Date.UTC(
    get("year"),
    get("month") - 1,
    get("day"),
    get("hour"),
    get("minute"),
    get("second"),
  );
  return Math.round((asUtc - Math.floor(epochMs / 1000) * 1000) / MINUTE_MS);
}

// "Today" for a person is their own Toll day in the zone their phone last reported.
export function tollTimeIn(zone: string, epochMs: number, resetHour: number): TollTime {
  return tollTime(epochMs, offsetMinutesIn(zone, epochMs), resetHour);
}

// Start of a Toll day as an instant, for a person whose offset that day was `offsetMinutes`.
export function dayStartMs(day: string, offsetMinutes: number, resetHour: number): number {
  return Date.parse(`${day}T00:00:00Z`) + resetHour * HOUR_MS - offsetMinutes * MINUTE_MS;
}
