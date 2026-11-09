import { z } from "zod";
import { FriendSummary, Pinned } from "../shared/contract";

export const HomeResponse = z.object({
  friends: z.array(FriendSummary),
  pinned: z.array(Pinned),
  friendsHeldPercent: z.number().nullable(),
  pendingRequests: z.number(),
  asOf: z.number(),
});
export type HomeResponse = z.infer<typeof HomeResponse>;
