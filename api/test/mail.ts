import { deps, type EmailMessage } from "../src/lib/deps";

export const outbox: EmailMessage[] = [];
deps.sendEmail = async (_env, message) => {
  outbox.push(message);
};

export function lastCodeFor(to: string): string {
  const message = outbox.findLast((m) => m.to === to);
  const code = message?.text.match(/\b\d{6}\b/)?.[0];
  if (!code) throw new Error(`no code sent to ${to}`);
  return code;
}

export const uniqueEmail = (prefix = "user") => `${prefix}-${crypto.randomUUID().slice(0, 8)}@example.com`;
