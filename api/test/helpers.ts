import { env as rawEnv, exports as rawExports } from "cloudflare:workers";
import type { D1Migration } from "@cloudflare/vitest-plugin";
import type { Env } from "../src/env";

export type TestEnv = Env & { TEST_MIGRATIONS: D1Migration[] };

export const env = rawEnv as unknown as TestEnv;
const worker = (rawExports as unknown as { default: Fetcher }).default;

export const BASE = "https://toll.test";

export function call(path: string, init: RequestInit & { token?: string; json?: unknown } = {}) {
  const headers = new Headers(init.headers);
  if (init.token) headers.set("authorization", `Bearer ${init.token}`);
  let body = init.body;
  if (init.json !== undefined) {
    headers.set("content-type", "application/json");
    body = JSON.stringify(init.json);
  }
  return worker.fetch(`${BASE}${path}`, { ...init, headers, body });
}
