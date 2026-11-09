import type { RateLimiter } from "../env";

// Bindings are absent in some local setups; a missing or failing limiter must not lock users out.
export async function allowed(limiter: RateLimiter | undefined, key: string): Promise<boolean> {
  if (!limiter) return true;
  try {
    return (await limiter.limit({ key })).success;
  } catch (err) {
    console.error("rate limiter failed", err);
    return true;
  }
}
