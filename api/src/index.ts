import * as Sentry from "@sentry/cloudflare";
import { createApp } from "./app";
import type { Env, PushMessage } from "./env";
import { runCron } from "./features/jobs/scheduled";
import { deliverPushes } from "./features/notify/consumer";

const app = createApp();

export default Sentry.withSentry((env: Env) => ({ dsn: env.SENTRY_DSN || undefined, tracesSampleRate: 0 }), {
  fetch: app.fetch,
  scheduled: async (controller, env, ctx) => {
    ctx.waitUntil(runCron(controller.cron, env, controller.scheduledTime));
  },
  queue: async (batch, env) => {
    await deliverPushes(batch as MessageBatch<PushMessage>, env);
  },
} satisfies ExportedHandler<Env, PushMessage>);
