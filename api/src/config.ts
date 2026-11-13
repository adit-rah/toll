import { z } from "zod";

export const TAGS = ["instagram", "tiktok", "youtube", "snapchat", "x", "reddit", "other"] as const;
export type Tag = (typeof TAGS)[number];

export const TAG_DISPLAY: Record<Tag, string> = {
  instagram: "Instagram",
  tiktok: "TikTok",
  youtube: "YouTube",
  snapchat: "Snapchat",
  x: "X",
  reddit: "Reddit",
  other: "a blocked app",
};

// Spec §14 and insights §9. The app gets the same document from GET /config; KV may override any key.
export const defaultConfig = {
  gate: {
    freePassesPerDay: 2,
    waits: [3, 5, 8],
    dayResetHour: 4,
    sessionMinutes: [5, 10, 15],
    resumeWindowSeconds: 120,
    clockSkewToleranceSeconds: 60,
  },
  status: {
    // Upper bounds of level 1 and level 2: 0–2, 3–4, 5+.
    levelBounds: [2, 4],
    personalise: true,
  },
  network: {
    pinHours: 24,
    schoolMinMembers: 20,
    silenceMissedCheckins: 2,
    tags: [...TAGS],
  },
  identity: { handleCooldownDays: 30, photoMaxPx: 512 },
  notify: { hour: 10 },
  blocks: {
    maxTokens: 40,
    max: 8,
    presets: {
      nights: { start: "23:00", end: "07:00", days: [1, 2, 3, 4, 5, 6, 7] },
      weekdays: { start: "09:00", end: "17:00", days: [1, 2, 3, 4, 5] },
    },
  },
  sync: { flushIntervalSeconds: 300 },
  retention: { rawEventDays: 90 },
  insights: {
    lateStart: 23,
    minN: 5,
    friendsMinN: 3,
    schoolBinMin: 5,
    examMarkMin: 10,
    maxBins: 8,
  },
  share: { formats: ["story", "square"] },
};

export type TollConfig = typeof defaultConfig;

// Server-only operating limits; never sent to the app.
export const serverConfig = {
  sessionTtlDays: 90,
  otpTtlMinutes: 10,
  otpMaxAttempts: 5,
  otpLockMinutes: 10,
  otpResendCooldownSeconds: 30,
  eventSkewDays: 7,
  eventBatchMax: 100,
  photoMaxUploadBytes: 2 * 1024 * 1024,
  idempotencyTtlHours: 24,
  configCacheSeconds: 300,
  apnsJwtTtlMinutes: 50,
  pushBatchSize: 100,
  displayNameMin: 2,
  displayNameMax: 24,
  handleSuggestions: 3,
  inviteCodeLength: 6,
  // No 0/O, 1/I: codes are read aloud and typed by hand.
  inviteAlphabet: "23456789ABCDEFGHJKLMNPQRSTUVWXYZ",
  contactsMatchMax: 2000,
  reportTextMax: 500,
  photoCacheSeconds: 31_536_000,
  insightsWeeks: 8,
  mutualsMax: 200,
  schoolMembersMax: 500,
  nightlyRecomputeDays: 2,
  nightlyUserBatch: 100,
  exportPageRows: 1000,
  appStoreUrl: "https://apps.apple.com/app/id0000000000",
};

const overrideSchema: z.ZodType<unknown> = z.record(z.string(), z.unknown());

export const remoteConfigSchema = z.object({
  overrides: overrideSchema.optional(),
  byVersion: z.record(z.string(), overrideSchema).optional(),
});

type Json = Record<string, unknown>;

function deepMerge(base: Json, patch: Json): Json {
  const out: Json = { ...base };
  for (const [key, value] of Object.entries(patch)) {
    const current = out[key];
    const bothObjects =
      value && typeof value === "object" && !Array.isArray(value) && current && typeof current === "object";
    out[key] = bothObjects && !Array.isArray(current) ? deepMerge(current as Json, value as Json) : value;
  }
  return out;
}

export function resolveConfig(remote: unknown, appVersion?: string): TollConfig {
  const parsed = remoteConfigSchema.safeParse(remote);
  if (!parsed.success) return defaultConfig;
  let merged = deepMerge(defaultConfig, (parsed.data.overrides ?? {}) as Json);
  const versioned = appVersion ? parsed.data.byVersion?.[appVersion] : undefined;
  if (versioned) merged = deepMerge(merged, versioned as Json);
  return merged as TollConfig;
}

export async function loadConfig(kv: KVNamespace, appVersion?: string): Promise<TollConfig> {
  const remote = await kv.get("config:v1", { type: "json", cacheTtl: serverConfig.configCacheSeconds });
  return resolveConfig(remote, appVersion);
}
