# First deploy (founders)

Every command runs from `api/` after `npm ci`. Production uses the top-level settings in `wrangler.jsonc`; the preview Worker uses `env.preview` (add `--env preview` to each command). Do production and preview the same way.

## 1. Account
- Cloudflare: Workers Paid plan ($5/month). The zone `alders.dev` must be on this account.
- `npx wrangler login`

## 2. Resources, then paste their ids into `wrangler.jsonc`
```sh
npx wrangler d1 create toll                 # → d1_databases[0].database_id
npx wrangler d1 create toll-preview         # → env.preview.d1_databases[0].database_id
npx wrangler kv namespace create toll-config          # → kv_namespaces[0].id
npx wrangler kv namespace create toll-config-preview  # → env.preview.kv_namespaces[0].id
npx wrangler r2 bucket create toll
npx wrangler r2 bucket create toll-preview
npx wrangler queues create toll-push
npx wrangler queues create toll-push-preview
# Weekly exports expire after 90 days (the privacy policy says so):
npx wrangler r2 bucket lifecycle add toll exports-90d exports/ --expire-days 90
```
The rate-limit `namespace_id`s are arbitrary numbers already set; nothing to create.

## 3. Vars in `wrangler.jsonc` (both blocks)
`APPLE_TEAM_ID` (10 characters, developer.apple.com → Membership), `APPLE_KEY_ID` (the Sign in with Apple key), `APNS_KEY_ID` (the push key), `SENTRY_DSN` (Sentry project for Cloudflare Workers), `APP_STORE_URL` (once the listing exists; until then the invite page uses the placeholder in `config.ts`). Preview: set `PUBLIC_BASE_URL` to the preview Worker's real URL.

## 4. Secrets (`npx wrangler secret put NAME`, then again with `--env preview`)
| Secret | Value |
|---|---|
| `APPLE_PRIVATE_KEY` | `npx wrangler secret put APPLE_PRIVATE_KEY < AuthKey_<APPLE_KEY_ID>.p8` |
| `APNS_PRIVATE_KEY` | `npx wrangler secret put APNS_PRIVATE_KEY < AuthKey_<APNS_KEY_ID>.p8` (same file if one key has both capabilities) |
| `RESEND_API_KEY` | From resend.com after verifying `toll.alders.dev` (add its DNS records). Without it emails are logged, not sent. |
| `OTP_PEPPER` | `openssl rand -base64 32 \| npx wrangler secret put OTP_PEPPER` |
| `CONTACTS_SALT` | `openssl rand -hex 16 \| npx wrangler secret put CONTACTS_SALT`. Never change it: stored hashes would stop matching. |
| `TOKEN_ENC_KEY` | `openssl rand -base64 32 \| npx wrangler secret put TOKEN_ENC_KEY` (must decode to exactly 32 bytes). Never change it: stored Apple tokens could not be revoked. |
| `ADMIN_TOKEN` | `openssl rand -base64 32 \| npx wrangler secret put ADMIN_TOKEN`. Keep it in the password manager. |
| `REVIEW_CODE` | Optional. Six digits, e.g. `openssl rand -hex 3 \| tr -dc 0-9 \| cut -c1-6`. With `REVIEW_EMAIL` set, that address always gets this code. |

## 5. Database
```sh
npx wrangler d1 migrations apply toll --remote
npx wrangler d1 execute toll --remote --file seed/schools-launch.sql
```

## 6. Deploy and the domain
```sh
npx wrangler deploy
```
Dashboard → Workers → `toll-api` → Settings → Domains & Routes → Add → Custom domain `toll.alders.dev`. Then check:
```sh
curl https://toll.alders.dev/health
curl https://toll.alders.dev/v1/config
curl https://toll.alders.dev/.well-known/apple-app-site-association   # appIDs must read <TEAM>.com.advan.toll
curl -H "Authorization: Bearer $ADMIN_TOKEN" https://toll.alders.dev/v1/admin/stats
```
`/privacy` and `/terms` are drafts until signed off: edit `public/privacy.html` and `public/terms.html`, remove the draft line, redeploy.

## 7. App Review account
Right before each submission (the events are relative to the moment the script runs):
```sh
npm run seed:review                                        # writes seed/review.sql, prints a curl
npx wrangler d1 execute toll --remote --file seed/review.sql
BASE=https://toll.alders.dev ADMIN_TOKEN=... <the printed curl>   # rebuilds rollups and school numbers
```
Review notes: sign in with email `review@toll.alders.dev` and the `REVIEW_CODE`.

## 8. CI deploys
GitHub → Settings → Secrets: `CLOUDFLARE_API_TOKEN` (template "Edit Cloudflare Workers", plus D1 Edit) and `CLOUDFLARE_ACCOUNT_ID`. Variables: `DEPLOY_ENABLED=true`. Create a GitHub environment named `production`. Pull requests then deploy to preview; `main` deploys to production and applies migrations.

## 9. Operations
- Sentry (E11.51): alert rules on the Worker project: "A new issue is created" → email both founders; "Number of events > 10 in 1 hour" → email.
- Founders' numbers (spec §1): `GET /v1/admin/stats` with `ADMIN_TOKEN`. `installs` counts signed-in devices (solo phones never reach the server).
- Restore rehearsal once (E11.49), on preview: `npx wrangler d1 time-travel info toll-preview`, then `npx wrangler d1 time-travel restore toll-preview --timestamp=<ISO time>`. Weekly NDJSON copies are in R2 under `exports/<date>/`.
- Remote config: see README.
- APNs does not work under `wrangler dev` (no HTTP/2); test pushes on the preview Worker with a sandbox device token.
