import { index, integer, primaryKey, real, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { users } from "./identity";

const userRef = () =>
  text("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" });

// The only place a tag lives: re-tagging one row re-labels every past event (spec §4).
export const appRefs = sqliteTable(
  "app_refs",
  {
    userId: userRef(),
    appRef: text("app_ref").notNull(),
    tag: text("tag").notNull(),
    updatedAt: integer("updated_at").notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.appRef] })],
);

export const blocksMeta = sqliteTable(
  "blocks_meta",
  {
    userId: userRef(),
    blockRef: text("block_ref").notNull(),
    schedule: text("schedule", { mode: "json" }).notNull(),
    appRefs: text("app_refs", { mode: "json" }).$type<string[]>().notNull(),
    updatedAt: integer("updated_at").notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.blockRef] })],
);

export const events = sqliteTable(
  "events",
  {
    eventId: text("event_id").primaryKey(),
    userId: userRef(),
    deviceId: text("device_id").notNull(),
    type: text("type").notNull(),
    appRef: text("app_ref"),
    blockRef: text("block_ref"),
    occurredAt: integer("occurred_at").notNull(),
    tzOffset: integer("tz_offset").notNull(),
    receivedAt: integer("received_at").notNull(),
    waitMinutes: integer("wait_minutes"),
    free: integer("free", { mode: "boolean" }),
    sessionMinutes: integer("session_minutes"),
    payload: text("payload", { mode: "json" }),
  },
  (t) => [index("events_user_time").on(t.userId, t.occurredAt), index("events_received").on(t.receivedAt)],
);

const counts = {
  passes: integer("passes").notNull().default(0),
  free: integer("free").notNull().default(0),
  waited: integer("waited").notNull().default(0),
  hits: integer("hits").notNull().default(0),
  held: integer("held").notNull().default(0),
  abandoned: integer("abandoned").notNull().default(0),
  waitMinutes: integer("wait_minutes").notNull().default(0),
};

export const rollupsDaily = sqliteTable(
  "rollups_daily",
  {
    userId: userRef(),
    day: text("day").notNull(),
    ...counts,
    active: integer("active", { mode: "boolean" }).notNull().default(false),
    level: integer("level"),
  },
  (t) => [primaryKey({ columns: [t.userId, t.day] })],
);

export const rollupsWeekly = sqliteTable(
  "rollups_weekly",
  {
    userId: userRef(),
    week: text("week").notNull(),
    passes: integer("passes").notNull().default(0),
    free: integer("free").notNull().default(0),
    waited: integer("waited").notNull().default(0),
    hits: integer("hits").notNull().default(0),
    held: integer("held").notNull().default(0),
    abandoned: integer("abandoned").notNull().default(0),
    waitMinutes: integer("wait_minutes").notNull().default(0),
    cleanDays: integer("clean_days").notNull().default(0),
    activeDays: integer("active_days").notNull().default(0),
    trend: real("trend"),
  },
  (t) => [primaryKey({ columns: [t.userId, t.week] }), index("rollups_weekly_week").on(t.week)],
);

export const hourHistograms = sqliteTable(
  "hour_histograms",
  {
    userId: userRef(),
    week: text("week").notNull(),
    hours: text("hours", { mode: "json" }).$type<number[]>().notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.week] })],
);

export const examWeeks = sqliteTable(
  "exam_weeks",
  {
    userId: userRef(),
    week: text("week").notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.week] })],
);
