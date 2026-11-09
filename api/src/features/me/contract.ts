import { z } from "zod";

export const PatchMeRequest = z.object({
  displayName: z.string().max(200).optional(),
  handle: z.string().max(100).optional(),
  discoverable: z.boolean().optional(),
  timezone: z.string().max(100).optional(),
  notifyEnabled: z.boolean().optional(),
  notifyHour: z.int().min(0).max(23).nullable().optional(),
});
export type PatchMeRequest = z.infer<typeof PatchMeRequest>;

export const HandleAvailability = z.object({
  available: z.boolean(),
  reason: z.enum(["taken", "invalid"]).nullable(),
  suggestions: z.array(z.string()),
});

export const HandleSuggestion = z.object({ handle: z.string() });

export const DeviceRequest = z.object({
  deviceId: z.string().min(1).max(100),
  pushToken: z
    .string()
    .regex(/^[0-9a-fA-F]{16,200}$/)
    .nullable()
    .optional(),
  pushEnvironment: z.enum(["production", "sandbox"]).optional(),
  timezone: z.string().max(100),
});
