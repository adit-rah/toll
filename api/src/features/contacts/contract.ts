import { z } from "zod";
import { serverConfig } from "../../config";
import { PersonRef } from "../shared/contract";

export const ContactsSalt = z.object({ salt: z.string() });

// Hex SHA-256 of salt + normalized email or phone, computed on the phone (N-12); raw contacts never arrive.
export const ContactsMatchRequest = z.object({
  hashes: z.array(z.string().regex(/^[0-9a-f]{64}$/)).max(serverConfig.contactsMatchMax),
});

export const ContactsMatchResponse = z.object({ matches: z.array(PersonRef) });
