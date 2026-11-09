import { z } from "zod";
import { serverConfig } from "../../config";
import { PersonRef } from "../shared/contract";

export const ReportRequest = z.object({
  userId: z.string().min(1).max(100),
  reason: z.enum(["name", "photo", "harassment", "other"]),
  text: z.string().max(serverConfig.reportTextMax).optional(),
});

export const BlockedPeople = z.object({ people: z.array(PersonRef) });
