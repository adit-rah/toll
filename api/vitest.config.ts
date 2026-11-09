import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => {
  const migrations = await readD1Migrations("./migrations");
  return {
    plugins: [
      cloudflareTest({
        wrangler: { configPath: "./wrangler.jsonc" },
        miniflare: {
          bindings: {
            TEST_MIGRATIONS: migrations,
            ENVIRONMENT: "test",
            PUBLIC_BASE_URL: "https://toll.test",
            APPLE_TEAM_ID: "TESTTEAM00",
            OTP_PEPPER: "test-pepper",
            CONTACTS_SALT: "test-salt",
            TOKEN_ENC_KEY: "dGVzdC1rZXktdGVzdC1rZXktdGVzdC1rZXktdGVzdC0=",
            ADMIN_TOKEN: "test-admin",
            REVIEW_EMAIL: "review@toll.alders.dev",
            REVIEW_CODE: "424242",
          },
        },
      }),
    ],
    test: { setupFiles: ["./test/setup.ts"] },
  };
});
