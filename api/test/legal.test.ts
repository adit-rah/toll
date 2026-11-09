import { describe, expect, it } from "vitest";
import { env } from "./helpers";

describe("legal pages (E10.44)", () => {
  for (const page of ["privacy", "terms"]) {
    it(`serves /${page} as a draft awaiting sign-off`, async () => {
      const res = await env.ASSETS.fetch(`https://toll.test/${page}`);
      expect(res.status).toBe(200);
      const html = await res.text();
      expect(html).toContain("Draft — pending founder sign-off");
      expect(html).toContain("support@toll.alders.dev");
    });
  }
});
