import { index, integer, primaryKey, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { users } from "./identity";

const userRef = (name: string) =>
  text(name)
    .notNull()
    .references(() => users.id, { onDelete: "cascade" });

// One row per pair, ordered so (a,b) and (b,a) can never both exist.
export const friendships = sqliteTable(
  "friendships",
  {
    userLo: userRef("user_lo"),
    userHi: userRef("user_hi"),
    status: text("status", { enum: ["requested", "accepted"] }).notNull(),
    requestedBy: text("requested_by").notNull(),
    createdAt: integer("created_at").notNull(),
    acceptedAt: integer("accepted_at"),
  },
  (t) => [primaryKey({ columns: [t.userLo, t.userHi] }), index("friendships_hi").on(t.userHi)],
);

export const invites = sqliteTable(
  "invites",
  {
    code: text("code").primaryKey(),
    userId: userRef("user_id"),
    createdAt: integer("created_at").notNull(),
  },
  (t) => [index("invites_user").on(t.userId)],
);

export const personBlocks = sqliteTable(
  "person_blocks",
  {
    blockerId: userRef("blocker_id"),
    blockedId: userRef("blocked_id"),
    createdAt: integer("created_at").notNull(),
  },
  (t) => [
    primaryKey({ columns: [t.blockerId, t.blockedId] }),
    index("person_blocks_blocked").on(t.blockedId),
  ],
);

export const reports = sqliteTable("reports", {
  id: text("id").primaryKey(),
  // Reports outlive either account so the founders keep the record after a deletion.
  reporterId: text("reporter_id").notNull(),
  subjectId: text("subject_id").notNull(),
  reason: text("reason", { enum: ["name", "photo", "harassment", "other"] }).notNull(),
  text: text("text"),
  createdAt: integer("created_at").notNull(),
});

export const contactHashes = sqliteTable(
  "contact_hashes",
  {
    userId: userRef("user_id"),
    hash: text("hash").notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.hash] }), index("contact_hashes_hash").on(t.hash)],
);
