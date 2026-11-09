import type { Env, PushMessage } from "../../env";
import { apnsConfigured, isDeadToken, sendPush } from "../../lib/apns";

// Spec §11.3: a failed push is not retried and has no fallback; a dead token is forgotten.
export async function deliverPushes(batch: MessageBatch<PushMessage>, env: Env): Promise<void> {
  if (!apnsConfigured(env)) {
    console.log("push skipped: APNs key not configured", batch.messages.length);
    batch.ackAll();
    return;
  }
  const dead = new Set<string>();
  for (const message of batch.messages) {
    try {
      const result = await sendPush(env, message.body);
      if (isDeadToken(result)) dead.add(message.body.deviceToken);
      else if (result.status >= 400) console.error("apns rejected", result.status, result.reason);
    } catch (err) {
      console.error("apns failed", err);
    }
    message.ack();
  }
  if (dead.size === 0) return;
  const tokens = [...dead];
  await env.DB.batch(
    tokens.map((token) =>
      env.DB.prepare("UPDATE devices SET push_token = NULL WHERE push_token = ?").bind(token),
    ),
  );
}
