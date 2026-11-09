export interface ScheduleShape {
  kind: "always" | "nights" | "weekdays" | "custom";
  start: string;
  end: string;
  days: number[];
}

const DAY_MINUTES = 1440;
const WEEK_MINUTES = 7 * DAY_MINUTES;

const minutes = (clock: string) => {
  const [h = 0, m = 0] = clock.split(":").map(Number);
  return h * 60 + m;
};

/**
 * Every minute of the week (Monday 00:00 = 0) the shield is on. A window belongs to the day it starts on,
 * so "nights on Friday" runs Friday 23:00 to Saturday 07:00, matching TollCore's Schedule.isActive.
 */
export function coverage(schedule: ScheduleShape): Uint8Array {
  const covered = new Uint8Array(WEEK_MINUTES);
  if (schedule.kind === "always") return covered.fill(1);
  const start = minutes(schedule.start);
  const end = minutes(schedule.end);
  const length = start === end ? DAY_MINUTES : (end - start + DAY_MINUTES) % DAY_MINUTES;
  for (const day of new Set(schedule.days)) {
    if (day < 1 || day > 7) continue;
    const from = (day - 1) * DAY_MINUTES + (start === end ? 0 : start);
    for (let m = 0; m < length; m++) covered[(from + m) % WEEK_MINUTES] = 1;
  }
  return covered;
}

// Spec G-7a: a change that drops any covered minute (shorter window, fewer days, always → anything) loosens.
export function isLoosened(before: ScheduleShape, after: ScheduleShape): boolean {
  const old = coverage(before);
  const next = coverage(after);
  for (let m = 0; m < WEEK_MINUTES; m++) if (old[m] && !next[m]) return true;
  return false;
}
