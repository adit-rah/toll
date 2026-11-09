import type { TestUser } from "./accounts";
import { call, env } from "./helpers";

export async function befriend(a: TestUser, b: TestUser) {
  const sent = await call("/v1/friends/requests", { method: "POST", token: a.token, json: { userId: b.id } });
  if (sent.status !== 200) throw new Error(`request failed ${sent.status}`);
  const accepted = await call(`/v1/friends/requests/${a.id}/accept`, { method: "POST", token: b.token });
  if (accepted.status !== 204) throw new Error(`accept failed ${accepted.status}`);
}

export async function blockDirect(blocker: TestUser, blocked: TestUser) {
  await env.DB.prepare("INSERT INTO person_blocks VALUES (?, ?, ?)")
    .bind(blocker.id, blocked.id, Date.now())
    .run();
}
