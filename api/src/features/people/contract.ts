import { z } from "zod";
import { FriendSummary, Level, PersonRef } from "../shared/contract";

export const MutualRow = z.object({
  user: PersonRef,
  via: z.array(z.string()),
  viaCount: z.number(),
  level: Level.nullable(),
  trend: z.number().nullable(),
});

export const SchoolSummary = z.object({
  id: z.number(),
  name: z.string(),
  members: z.number(),
  heldPercent: z.number().nullable(),
});
export type SchoolSummary = z.infer<typeof SchoolSummary>;

export const PeopleResponse = z.object({
  requests: z.array(z.object({ user: PersonRef, mutualNames: z.array(z.string()) })),
  outgoing: z.array(PersonRef),
  friends: z.array(FriendSummary),
  mutuals: z.array(MutualRow),
  school: SchoolSummary.nullable(),
});
export type PeopleResponse = z.infer<typeof PeopleResponse>;
