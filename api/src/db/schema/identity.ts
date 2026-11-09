import { index, integer, primaryKey, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const users = sqliteTable("users", {
  id: text("id").primaryKey(),
  displayName: text("display_name"),
  handle: text("handle").unique(),
  photoKey: text("photo_key"),
  handleChangedAt: integer("handle_changed_at"),
  // Kept only to deliver codes and recover the account (spec §13); identity lookups use hashes.
  email: text("email"),
  discoverable: integer("discoverable", { mode: "boolean" }).notNull().default(true),
  timezone: text("timezone").notNull().default("UTC"),
  notifyEnabled: integer("notify_enabled", { mode: "boolean" }).notNull().default(true),
  notifyHour: integer("notify_hour"),
  createdAt: integer("created_at").notNull(),
  lastHomeAt: integer("last_home_at"),
});

export const authIdentities = sqliteTable(
  "auth_identities",
  {
    subjectHash: text("subject_hash").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    provider: text("provider", { enum: ["apple", "email"] }).notNull(),
    appleRefreshTokenEnc: text("apple_refresh_token_enc"),
    createdAt: integer("created_at").notNull(),
  },
  (t) => [index("auth_identities_user").on(t.userId)],
);

export const sessions = sqliteTable(
  "sessions",
  {
    tokenHash: text("token_hash").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    deviceId: text("device_id"),
    createdAt: integer("created_at").notNull(),
    expiresAt: integer("expires_at").notNull(),
  },
  (t) => [index("sessions_user").on(t.userId)],
);

export const emailCodes = sqliteTable("email_codes", {
  key: text("key").primaryKey(),
  codeHash: text("code_hash").notNull(),
  expiresAt: integer("expires_at").notNull(),
  attempts: integer("attempts").notNull().default(0),
  lockedUntil: integer("locked_until"),
  sentAt: integer("sent_at").notNull(),
  schoolId: integer("school_id"),
});

export const devices = sqliteTable(
  "devices",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    pushToken: text("push_token"),
    pushEnvironment: text("push_environment", { enum: ["production", "sandbox"] }),
    timezone: text("timezone"),
    updatedAt: integer("updated_at").notNull(),
  },
  (t) => [index("devices_user").on(t.userId)],
);

export const tombstones = sqliteTable("tombstones", {
  subjectHash: text("subject_hash").primaryKey(),
  createdAt: integer("created_at").notNull(),
});

export const idempotencyKeys = sqliteTable(
  "idempotency_keys",
  {
    userId: text("user_id").notNull(),
    key: text("key").notNull(),
    status: integer("status").notNull(),
    body: text("body").notNull(),
    createdAt: integer("created_at").notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.key] })],
);
