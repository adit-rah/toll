import * as Sentry from "@sentry/cloudflare";
import { createApp } from "./app";
import type { Env } from "./env";

const app = createApp();

export default Sentry.withSentry((env: Env) => ({ dsn: env.SENTRY_DSN || undefined, tracesSampleRate: 0 }), {
  fetch: app.fetch,
} satisfies ExportedHandler<Env>);
