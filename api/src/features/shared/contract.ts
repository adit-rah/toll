import { z } from "zod";
import { TAGS } from "../../config";

export const Tag = z.enum(TAGS);

const clock = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);

export const Schedule = z.object({
  kind: z.enum(["always", "nights", "weekdays", "custom"]),
  start: clock,
  end: clock,
  days: z.array(z.int().min(1).max(7)).max(7),
});
export type Schedule = z.infer<typeof Schedule>;

export const Day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const PersonRef = z.object({
  id: z.string(),
  displayName: z.string(),
  handle: z.string(),
  photoUrl: z.string().nullable(),
});
export type PersonRef = z.infer<typeof PersonRef>;

export const Level = z.union([z.literal(1), z.literal(2), z.literal(3)]);
export type Level = z.infer<typeof Level>;

export const PassLine = z.object({
  at: z.number(),
  tzOffset: z.number(),
  tag: Tag.nullable(),
  free: z.boolean(),
  waitMinutes: z.number(),
});
export type PassLine = z.infer<typeof PassLine>;

export const WeekStats = z.object({
  passes: z.number(),
  lastWeek: z.number(),
  trend: z.number().nullable(),
  cleanDays: z.number(),
  hits: z.number(),
  held: z.number(),
  waited: z.number(),
  waitMinutes: z.number(),
});
export type WeekStats = z.infer<typeof WeekStats>;

export const BlockSummary = z.object({ tags: z.array(Tag.nullable()), schedule: Schedule });

export const FriendSummary = z.object({
  user: PersonRef,
  today: z.object({ passes: z.number(), level: Level.nullable() }),
  week: WeekStats,
  silentSince: Day.nullable(),
  latestPass: PassLine.nullable(),
  todayPasses: z.array(PassLine),
  yesterdayPasses: z.array(PassLine),
  blocks: z.array(BlockSummary),
  friendsSince: z.number(),
});
export type FriendSummary = z.infer<typeof FriendSummary>;

export const Pinned = z.object({
  kind: z.enum(["removal", "loosened", "silence"]),
  user: PersonRef,
  tags: z.array(Tag.nullable()),
  schedule: Schedule.nullable(),
  since: z.number(),
});
export type Pinned = z.infer<typeof Pinned>;

export const Me = z.object({
  id: z.string(),
  displayName: z.string().nullable(),
  handle: z.string().nullable(),
  photoUrl: z.string().nullable(),
  email: z.string().nullable(),
  discoverable: z.boolean(),
  timezone: z.string(),
  notifyEnabled: z.boolean(),
  notifyHour: z.number().nullable(),
  handleChangedAt: z.number().nullable(),
  school: z.object({ id: z.number(), name: z.string() }).nullable(),
  inviteCode: z.string(),
  createdAt: z.number(),
});
export type Me = z.infer<typeof Me>;

export const AuthSession = z.object({ token: z.string(), user: Me, isNew: z.boolean() });
export type AuthSession = z.infer<typeof AuthSession>;
