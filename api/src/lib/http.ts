import type { Context } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ContentfulStatusCode } from "hono/utils/http-status";

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
