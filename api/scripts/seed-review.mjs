// Writes seed/review.sql: the App Review account (review@toll.alders.dev, @review), 5 friends, a friend of a
// friend, 24 classmates at the University of Waterloo, and 8 weeks of gate events ending now, shaped so every
// Home and Insights card has something to show. Events are relative to the moment it runs, so regenerate and
// apply it right before each submission. Usage is in DEPLOY.md.
import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";

const ZONE = "America/Toronto";
const WATERLOO = 1923058245;
const REVIEW_EMAIL = "review@toll.alders.dev";
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const NOW = Date.now();
const START = NOW - 56 * DAY;

const sha256 = (text) => createHash("sha256").update(text).digest("hex");
const q = (v) =>
  v === null || v === undefined
    ? "NULL"
    : typeof v === "number"
      ? String(v)
      : `'${String(v).replaceAll("'", "''")}'`;
const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;

let seed = 20261109;
function random() {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const pick = (list) => list[Math.floor(random() * list.length)];
const ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const inviteCode = (n) =>
  `RV${[3, 2, 1, 0].map((p) => ALPHABET[Math.floor(n / ALPHABET.length ** p) % ALPHABET.length]).join("")}`;
let eventCounter = 0;
const eventId = () => `10000000-0000-4000-8000-${String(++eventCounter).padStart(12, "0")}`;

function offsetAt(ms) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ZONE,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).formatToParts(new Date(ms));
  const get = (type) => Number(parts.find((p) => p.type === type)?.value);
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"));
  return Math.round((asUtc - Math.floor(ms / MINUTE) * MINUTE) / MINUTE);
}

const always = { kind: "always", start: "00:00", end: "00:00", days: [1, 2, 3, 4, 5, 6, 7] };
const nights = { kind: "nights", start: "23:00", end: "07:00", days: [1, 2, 3, 4, 5, 6, 7] };

const people = [
  { n: 1, name: "Robin Review", handle: "review", rate: 3, trend: -0.04, late: 0.15 },
  { n: 2, name: "Adi Kumar", handle: "adi", rate: 4, trend: -0.06, late: 0.3 },
  { n: 3, name: "Bea Lin", handle: "bea", rate: 2, trend: 0.02, late: 0.1 },
  { n: 4, name: "Cy Moreau", handle: "cy", rate: 5, trend: -0.02, late: 0.35 },
  { n: 5, name: "Dana Park", handle: "dana", rate: 3, trend: 0.05, late: 0.3 },
  { n: 6, name: "Eli Cohen", handle: "eli", rate: 2, trend: 0, late: 0.2, silentFor: 4 },
  { n: 7, name: "Fay Ortiz", handle: "fay", rate: 3, trend: -0.03, late: 0.2 },
];
for (let i = 0; i < 24; i++) {
  people.push({
    n: 100 + i,
    name: `Classmate ${i + 1}`,
    handle: `classmate${i + 1}`,
    rate: 1 + (i % 6),
    trend: (i % 5) * 0.02 - 0.04,
    late: 0.25,
  });
}
const review = people[0];
const friends = people.slice(1, 6);
const tables = {
  users: [],
  auth_identities: [],
  invites: [],
  friendships: [],
  school_memberships: [],
  app_refs: [],
  blocks_meta: [],
  events: [],
  exam_weeks: [],
};
const add = (table, row) => tables[table].push(row);

function event(person, type, at, extra = {}) {
  if (at > NOW) return;
  add("events", {
    event_id: eventId(),
    user_id: id(person.n),
    device_id: `seed-${person.handle}`,
    type,
    app_ref: extra.appRef ?? null,
    block_ref: extra.blockRef ?? null,
    occurred_at: Math.round(at),
    tz_offset: offsetAt(at),
    received_at: Math.round(at),
    wait_minutes: extra.waitMinutes ?? null,
    free: extra.free === undefined ? null : extra.free ? 1 : 0,
    session_minutes: extra.sessionMinutes ?? null,
    payload: JSON.stringify(extra.payload ?? {}),
  });
}

// One person's day: a morning check-in, then reaches through the day weighted towards the evening.
function day(person, dayStart, weekIndex) {
  event(person, "checkin", dayStart + 5 * HOUR);
  const expected = Math.max(0, person.rate * (1 + person.trend * (weekIndex - 4)));
  const hits = Math.round(expected * (0.6 + random() * 0.9));
  let free = 2;
  let waited = 0;
  const times = Array.from(
    { length: hits },
    () => dayStart + (random() < person.late ? 19 + random() * 3.5 : 4 + random() * 15) * HOUR,
  ).sort((a, b) => a - b);
  for (const at of times) {
    const appRef = pick(["a1", "a2", "a2", "a3", "a4", "a5"]);
    if (random() < 0.3) {
      event(person, "block_hit", at, { appRef, payload: { via: "dismiss" } });
    } else if (free > 0) {
      free--;
      event(person, "block_hit", at, { appRef, payload: { via: "open" } });
      event(person, "pass", at + 20_000, { appRef, free: true, sessionMinutes: 10 });
    } else {
      const minutes = [3, 5, 8][Math.min(waited, 2)];
      event(person, "block_hit", at, { appRef, payload: { via: "open" } });
      event(person, "wait_started", at + 15_000, { appRef, waitMinutes: minutes });
      if (random() < 0.15) {
        event(person, "wait_abandoned", at + 75_000, { appRef });
      } else {
        waited++;
        event(person, "wait_completed", at + 15_000 + minutes * MINUTE, { appRef });
        event(person, "pass", at + 16_000 + minutes * MINUTE, {
          appRef,
          free: false,
          waitMinutes: minutes,
          sessionMinutes: 5,
        });
      }
    }
  }
}

const startOf = (ms) => {
  const local = ms + offsetAt(ms) * MINUTE;
  const date = new Date(local - 4 * HOUR);
  const civil = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 4);
  return civil - offsetAt(ms) * MINUTE;
};
const mondayOf = (ms) => {
  const start = startOf(ms);
  const weekday = (new Date(start + offsetAt(start) * MINUTE).getUTCDay() + 6) % 7;
  return start - weekday * DAY;
};
const isoDay = (ms) => new Date(ms + offsetAt(ms) * MINUTE).toISOString().slice(0, 10);

const firstMonday = mondayOf(START);
const currentMonday = mondayOf(NOW);
for (const person of people) {
  const userId = id(person.n);
  add("users", {
    id: userId,
    display_name: person.name,
    handle: person.handle,
    email: person === review ? REVIEW_EMAIL : null,
    timezone: ZONE,
    created_at: START,
    discoverable: 1,
    notify_enabled: 1,
  });
  add("invites", { code: inviteCode(person.n), user_id: userId, created_at: START });
  if (person.n === 1 || person.n >= 100 || friends.includes(person))
    add("school_memberships", {
      user_id: userId,
      school_id: WATERLOO,
      email_hash: sha256(`seed:${person.handle}`),
      verified_at: START,
    });
  for (const [appRef, tag] of [
    ["a1", "instagram"],
    ["a2", "tiktok"],
    ["a3", "youtube"],
    ["a4", "reddit"],
  ])
    add("app_refs", { user_id: userId, app_ref: appRef, tag, updated_at: START });
  event(person, "block_added", START, {
    blockRef: "b1",
    payload: { appRefs: ["a1", "a2", "a5"], schedule: always },
  });
  event(person, "block_added", START + MINUTE, {
    blockRef: "b2",
    payload: { appRefs: ["a3", "a4"], schedule: nights },
  });
  add("blocks_meta", {
    user_id: userId,
    block_ref: "b1",
    schedule: JSON.stringify(always),
    app_refs: JSON.stringify(["a1", "a2", "a5"]),
    updated_at: START,
  });
  add("blocks_meta", {
    user_id: userId,
    block_ref: "b2",
    schedule: JSON.stringify(nights),
    app_refs: JSON.stringify(["a3", "a4"]),
    updated_at: START + MINUTE,
  });

  const lastDay = startOf(NOW) - (person.silentFor ?? 0) * DAY;
  for (let d = startOf(START); d <= lastDay; d += DAY) {
    const dayStart = startOf(d + 12 * HOUR);
    const weekIndex = Math.floor((dayStart - firstMonday) / (7 * DAY));
    if (person === review && dayStart === startOf(NOW - 2 * DAY))
      event(person, "checkin", dayStart + 5 * HOUR);
    else day(person, dayStart, weekIndex);
  }
}

// Same app, same hour (I-14): three friends opened TikTok after 11 p.m. this week.
const lateAt = startOf(NOW - 20.5 * HOUR) + 19.5 * HOUR;
for (const friend of friends.slice(0, 3)) {
  const at = lateAt;
  event(friend, "block_hit", at, { appRef: "a2", payload: { via: "open" } });
  event(friend, "pass", at + 20_000, { appRef: "a2", free: true, sessionMinutes: 10 });
}
// Pinned: Bea removed her nights block 3 hours ago; Cy loosened Always to Nights 5 hours ago.
event(people[2], "block_removed", NOW - 3 * HOUR, {
  blockRef: "b2",
  payload: { appRefs: ["a3", "a4"], oldSchedule: nights },
});
tables.blocks_meta = tables.blocks_meta.filter((b) => !(b.user_id === id(3) && b.block_ref === "b2"));
event(people[3], "block_changed", NOW - 5 * HOUR, {
  blockRef: "b1",
  payload: { schedule: nights, oldSchedule: always },
});
for (const b of tables.blocks_meta)
  if (b.user_id === id(4) && b.block_ref === "b1") b.schedule = JSON.stringify(nights);

// Five friends, and Fay as a friend of Adi only, so she shows as a mutual.
const befriend = (a, b) => {
  const [lo, hi] = [id(a.n), id(b.n)].sort();
  add("friendships", {
    user_lo: lo,
    user_hi: hi,
    status: "accepted",
    requested_by: id(a.n),
    created_at: START,
    accepted_at: START + DAY,
  });
};
for (const friend of friends) befriend(review, friend);
befriend(people[1], people[6]);
add("auth_identities", {
  subject_hash: sha256(`email:${REVIEW_EMAIL}`),
  user_id: id(1),
  provider: "email",
  created_at: START,
});

// Exam weeks (I-9, I-19): two weeks ago, marked by the reviewer and ten classmates.
const examWeek = isoDay(currentMonday - 14 * DAY);
for (const person of [review, ...people.slice(7, 17)])
  add("exam_weeks", { user_id: id(person.n), week: examWeek });

const ids = people.map((p) => id(p.n));
const lines = [
  "-- Generated by scripts/seed-review.mjs; do not edit. Re-running replaces the review data.",
  `DELETE FROM users WHERE id IN (${ids.map(q).join(", ")});`,
];
for (const [table, rows] of Object.entries(tables)) {
  for (let i = 0; i < rows.length; i += 100) {
    const chunk = rows.slice(i, i + 100);
    const columns = Object.keys(chunk[0]);
    lines.push(
      `INSERT INTO ${table} (${columns.join(", ")}) VALUES\n${chunk.map((r) => `(${columns.map((c) => q(r[c])).join(", ")})`).join(",\n")};`,
    );
  }
}
mkdirSync(new URL("../seed/", import.meta.url), { recursive: true });
writeFileSync(new URL("../seed/review.sql", import.meta.url), `${lines.join("\n")}\n`);
console.log(
  `Wrote seed/review.sql: ${people.length} users, ${tables.events.length} events (${isoDay(START)} to ${isoDay(NOW)}).`,
);
console.log("Then rebuild their rollups and the school aggregates:");
console.log(
  `curl -X POST "$BASE/v1/admin/recompute" -H "Authorization: Bearer $ADMIN_TOKEN" -H "content-type: application/json" -d '${JSON.stringify({ userIds: ids, days: 60 })}'`,
);
