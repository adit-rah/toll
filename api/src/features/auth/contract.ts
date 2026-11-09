import { z } from "zod";

const deviceId = z.string().min(1).max(100);

export const AppleSignInRequest = z.object({
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1),
  nonce: z.string().min(1),
  deviceId,
  givenName: z.string().max(100).optional(),
  familyName: z.string().max(100).optional(),
});
