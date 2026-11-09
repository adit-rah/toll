import type { Env } from "../env";
import { deps, type EmailMessage } from "./deps";

// Email never fails the request that triggered it: a lost code is fixed by Resend.
export async function sendEmail(env: Env, message: EmailMessage): Promise<void> {
  try {
    await deps.sendEmail(env, message);
  } catch (err) {
    console.error("email failed", err);
  }
}
