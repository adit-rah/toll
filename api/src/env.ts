export interface RateLimiter {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export interface PushMessage {
  deviceToken: string;
  environment: "production" | "sandbox";
  kind: "alert" | "background";
  body?: string;
  data?: Record<string, string>;
}

export interface Env {
  DB: D1Database;
  CONFIG: KVNamespace;
  STORAGE: R2Bucket;
  PUSH_QUEUE: Queue<PushMessage>;
  ASSETS: Fetcher;
  RL_OTP: RateLimiter;
  RL_SOCIAL: RateLimiter;
  RL_INGEST: RateLimiter;

  ENVIRONMENT: string;
  PUBLIC_BASE_URL: string;
  APPLE_BUNDLE_ID: string;
  APPLE_TEAM_ID: string;
  APPLE_KEY_ID: string;
  APNS_KEY_ID: string;
  APNS_HOST: string;
  EMAIL_FROM: string;
  FOUNDERS_EMAIL: string;
  SENTRY_DSN: string;
  APP_STORE_URL?: string;
  // App Review sign-in: this one address gets REVIEW_CODE instead of a random code (both must be set).
  REVIEW_EMAIL?: string;

  // Secrets (wrangler secret put).
  APPLE_PRIVATE_KEY?: string;
  APNS_PRIVATE_KEY?: string;
  RESEND_API_KEY?: string;
  OTP_PEPPER: string;
  CONTACTS_SALT: string;
  TOKEN_ENC_KEY: string;
  ADMIN_TOKEN: string;
  REVIEW_CODE?: string;
}

export interface AppVariables {
  userId: string;
  deviceId: string | null;
}

export type AppEnv = { Bindings: Env; Variables: AppVariables };
