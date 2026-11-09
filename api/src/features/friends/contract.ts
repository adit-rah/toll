import { z } from "zod";
import { PersonRef } from "../shared/contract";

export const FriendRequest = z
  .object({ userId: z.string().max(100).optional(), code: z.string().max(20).optional() })
  .refine((v) => Boolean(v.userId) !== Boolean(v.code));

export const FriendRequestResult = z.object({
  status: z.enum(["requested", "accepted"]),
  user: PersonRef,
});
export type FriendRequestResult = z.infer<typeof FriendRequestResult>;

export const Invite = z.object({ code: z.string(), url: z.string() });

export const InvitePreview = z.object({ displayName: z.string() });
