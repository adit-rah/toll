import { zValidator } from "@hono/zod-validator";
import type { Context } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import type { ZodType } from "zod";

// Every error body is `{ error: code }`; the app maps codes to Copy, so no user-facing text lives here.
export function fail(status: ContentfulStatusCode, code: string, extra?: Record<string, unknown>): never {
  throw new HTTPException(status, {
    res: new Response(JSON.stringify({ error: code, ...extra }), {
      status,
      headers: { "content-type": "application/json" },
    }),
  });
}

export function noContent(c: Context) {
  return c.body(null, 204);
}

export function validate<T extends ZodType, Target extends "json" | "query" | "param">(
  target: Target,
  schema: T,
) {
  return zValidator(target, schema, (result) => {
    if (!result.success) fail(400, "invalid");
  });
}
