import type { AuthSession, Me } from "../src/features/shared/contract";
import { call } from "./helpers";
import { lastCodeFor, uniqueEmail } from "./mail";

export interface TestUser {
  id: string;
  token: string;
  email: string;
  name: string;
  handle: string;
}

export const uniqueHandle = (prefix = "u") =>
  `${prefix}${crypto.randomUUID().replace(/-/g, "").slice(0, 10)}`;

export async function newUser(options: { name?: string; handle?: string; timezone?: string } = {}) {
  const email = uniqueEmail();
  await call("/v1/auth/email/start", { method: "POST", json: { email } });
  const res = await call("/v1/auth/email/verify", {
    method: "POST",
    json: { email, code: lastCodeFor(email), deviceId: crypto.randomUUID() },
  });
  const session = (await res.json()) as AuthSession;
  const name = options.name ?? "Test Person";
  const handle = options.handle ?? uniqueHandle();
  const patched = await call("/v1/me", {
    method: "PATCH",
    token: session.token,
    json: { displayName: name, handle, timezone: options.timezone ?? "America/Toronto" },
  });
  if (patched.status !== 200) throw new Error(`patch failed ${patched.status} ${await patched.text()}`);
  const me = (await patched.json()) as Me;
  return { id: me.id, token: session.token, email, name, handle } satisfies TestUser;
}

export async function json<T>(res: Response | Promise<Response>): Promise<T> {
  return (await (await res).json()) as T;
}
