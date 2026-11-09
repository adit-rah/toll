import { z } from "zod";
import { Level, PersonRef } from "../shared/contract";

export const SchoolStartRequest = z.object({ email: z.string().max(254) });
export const SchoolVerifyRequest = z.object({
  email: z.string().max(254),
  code: z.string().regex(/^\d{6}$/),
});

export const SchoolRef = z.object({ id: z.number(), name: z.string() });
export type SchoolRef = z.infer<typeof SchoolRef>;

export const SchoolResponse = z.object({
  school: SchoolRef,
  activeMembers: z.number(),
  enough: z.boolean(),
  heldPercent: z.number().nullable(),
  medianPasses: z.number().nullable(),
  week: z.string(),
  asOf: z.number().nullable(),
});

export const SchoolMembersResponse = z.object({
  members: z.array(
    z.object({
      user: PersonRef,
      relation: z.enum(["friend", "mutual", "requested", "none"]),
      level: Level.nullable(),
    }),
  ),
});
export type SchoolMembersResponse = z.infer<typeof SchoolMembersResponse>;
