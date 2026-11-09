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

export const EmailStartRequest = z.object({ email: z.string().max(254) });

export const EmailVerifyRequest = z.object({
  email: z.string().max(254),
  code: z.string().regex(/^\d{6}$/),
  deviceId,
});
