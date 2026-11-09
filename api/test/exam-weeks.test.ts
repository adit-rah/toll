import { describe, expect, it } from "vitest";
import { json, newUser } from "./accounts";
import { call } from "./helpers";

describe("exam weeks (E8.40, I-9)", () => {
  it("marks, lists and unmarks Monday-named weeks", async () => {
    const me = await newUser();
    const mark = (week: string, method: "PUT" | "DELETE" = "PUT") =>
      call(`/v1/exam-weeks/${week}`, { method, token: me.token });
    expect((await mark("2026-12-07")).status).toBe(204);
    expect((await mark("2026-12-07")).status).toBe(204);
    await mark("2026-11-30");
    expect((await mark("2026-12-08")).status).toBe(400);
    expect(await json(call("/v1/exam-weeks", { token: me.token }))).toEqual({
      weeks: ["2026-11-30", "2026-12-07"],
    });
    expect((await mark("2026-11-30", "DELETE")).status).toBe(204);
    expect(await json(call("/v1/exam-weeks", { token: me.token }))).toEqual({ weeks: ["2026-12-07"] });
  });
});
