import { index, integer, primaryKey, real, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { users } from "./identity";

export const schools = sqliteTable("schools", {
  id: integer("id").primaryKey(),
  name: text("name").notNull(),
  country: text("country").notNull(),
});

export const schoolDomains = sqliteTable(
  "school_domains",
  {
    domain: text("domain").primaryKey(),
    schoolId: integer("school_id").notNull(),
  },
  (t) => [index("school_domains_school").on(t.schoolId)],
);

export const schoolMemberships = sqliteTable(
  "school_memberships",
  {
    userId: text("user_id")
      .primaryKey()
      .references(() => users.id, { onDelete: "cascade" }),
    schoolId: integer("school_id").notNull(),
    emailHash: text("email_hash").notNull(),
    verifiedAt: integer("verified_at").notNull(),
  },
  (t) => [index("school_memberships_school").on(t.schoolId)],
);

export const schoolRollupsWeekly = sqliteTable(
  "school_rollups_weekly",
  {
    schoolId: integer("school_id").notNull(),
    week: text("week").notNull(),
    activeMembers: integer("active_members").notNull(),
    hits: integer("hits").notNull(),
    held: integer("held").notNull(),
    passesMedian: real("passes_median").notNull(),
    passesHistogram: text("passes_histogram", { mode: "json" }).$type<number[]>().notNull(),
    byHour: text("by_hour", { mode: "json" }).$type<number[]>().notNull(),
    tagShare: text("tag_share", { mode: "json" }).$type<Record<string, number>>().notNull(),
    examMarks: integer("exam_marks").notNull(),
    computedAt: integer("computed_at").notNull(),
  },
  (t) => [primaryKey({ columns: [t.schoolId, t.week] })],
);
