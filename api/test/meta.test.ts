import { describe, expect, it } from "vitest";
import { defaultConfig, resolveConfig } from "../src/config";
import { call, env } from "./helpers";

describe("meta", () => {
  it("answers health", async () => {
    expect((await call("/health")).status).toBe(200);
  });

  it("serves the default config when KV is empty, cacheable for five minutes", async () => {
    const res = await call("/v1/config");
    expect(res.headers.get("cache-control")).toBe("public, max-age=300");
    expect(await res.json()).toEqual(defaultConfig);
  });

  it("carries the block presets the app's When chips use", () => {
    expect(defaultConfig.blocks.presets).toEqual({
      nights: { start: "23:00", end: "07:00", days: [1, 2, 3, 4, 5, 6, 7] },
      weekdays: { start: "09:00", end: "17:00", days: [1, 2, 3, 4, 5] },
    });
  });

  it("applies KV overrides, then the per-version overrides", async () => {
    await env.CONFIG.put(
      "config:v1",
      JSON.stringify({
        overrides: { gate: { waits: [4, 6] } },
        byVersion: { "1.1": { gate: { freePassesPerDay: 1 } } },
      }),
    );
    const body = (await (await call("/v1/config?v=1.1")).json()) as typeof defaultConfig;
    expect(body.gate.waits).toEqual([4, 6]);
    expect(body.gate.freePassesPerDay).toBe(1);
    expect(body.gate.dayResetHour).toBe(4);
  });

  it("ignores malformed remote config", () => {
    expect(resolveConfig({ overrides: "nope" })).toEqual(defaultConfig);
  });
});
