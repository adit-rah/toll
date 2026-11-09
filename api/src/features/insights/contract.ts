import { z } from "zod";
import { PersonRef, Tag } from "../shared/contract";

export const WeekQuery = z.object({ week: z.string().optional() });

export const Distribution = z.object({
  bins: z.array(z.object({ from: z.number(), to: z.number(), count: z.number(), includesMe: z.boolean() })),
});

export const FriendsInsights = z.object({
  week: z.string(),
  people: z.array(
    z.object({
      user: PersonRef.nullable(),
      isMe: z.boolean(),
      passes: z.number(),
      hits: z.number(),
      held: z.number(),
      heldPercent: z.number().nullable(),
    }),
  ),
  distribution: Distribution.nullable(),
  friendsByHour: z.array(z.number()),
  myByHour: z.array(z.number()),
  weekly: z.array(
    z.object({
      week: z.string(),
      heldPercent: z.number().nullable(),
      passesPerPerson: z.number().nullable(),
    }),
  ),
  sameAppSameHour: z.object({ tag: Tag, count: z.number() }).nullable(),
  friendsHeldPercent: z.number().nullable(),
});
export type FriendsInsights = z.infer<typeof FriendsInsights>;

export const SchoolInsights = z.object({
  enough: z.boolean(),
  school: z.object({ id: z.number(), name: z.string() }).nullable(),
  week: z.string(),
  asOf: z.number().nullable(),
  distribution: Distribution.nullable(),
  myBin: z.number().nullable(),
  schoolHeldPercent: z.number().nullable(),
  myHeldPercent: z.number().nullable(),
  weekly: z.array(
    z.object({
      week: z.string(),
      schoolHeldPercent: z.number().nullable(),
      myHeldPercent: z.number().nullable(),
    }),
  ),
  byHour: z.array(z.number()),
  myByHour: z.array(z.number()),
  tagShare: z.record(Tag, z.number()),
  examWeeks: z.array(z.string()),
});
export type SchoolInsights = z.infer<typeof SchoolInsights>;
