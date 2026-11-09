# Handoff: from this repo to TestFlight

State on 9 Nov 2026. Everything in spec §15 is built except what needs Apple, Cloudflare or a phone. The steps below are in the order they unblock each other.

## Where things stand

| Area | State | Evidence |
|---|---|---|
| Worker (E3–E11 server) | Built | 112 Vitest tests in workerd; lint and typecheck clean |
| `TollCore` (gate, time, metrics, routing, spool, outbox plan) | Built | 61 Swift Testing tests on Linux and macOS |
| App, three extensions, `TollData`, `TollUI`, every screen | Built | Compiles on macOS 26 / Xcode 26.6 in Swift 6 mode with no warnings in our code (`.github/workflows/ios.yml`) |
| Behaviour on a phone | **Not yet run** | `docs/gate-checklist.md` |
| Real Apple / Resend / APNs calls | **Not yet run** | faked in tests (`api/src/lib/deps.ts`) |

Decisions taken along the way: `docs/toll-future-ledger.md` A21–A62. Open founder decisions: §B.

## Order of work

1. **Apple** (`docs/apple-setup.md`): App IDs, App Group, the four Family Controls (Distribution) requests, APNs and Sign in with Apple keys. Record the request ids in that file. The team id goes in `ios/Config/Signing.xcconfig` (git-ignored) and `api/wrangler.jsonc`.
2. **Cloudflare** (`api/DEPLOY.md`): create D1, KV, R2, queues; paste ids into `wrangler.jsonc`; set secrets; apply migrations; seed schools and the review account; route `toll.alders.dev` to the Worker; then set the `DEPLOY_ENABLED` repository variable and the two GitHub secrets so CI deploys.
3. **First device build** with the development entitlement from Xcode on a Mac (Product → Run on a phone). Run `docs/gate-checklist.md` §7 first: whether "Open Toll" opens Toll directly on iOS 26.5+ under individual authorization is the week-one question (ledger D1). If it does not, the notification route already works; file Feedback and tell the team.
4. **Rest of the checklist** on both phones (iOS 26.5+ and 18.x). Fix list at the bottom of that file.
5. **Xcode Cloud** (`ios/README.md`) once the distribution entitlements are approved; TestFlight on a `v*` tag.
6. **Store** (`docs/app-store.md`): listing copy (ledger B1–B3), screenshots, review notes with the review code, privacy labels, age rating.

## Founders still owe

- Team id; the Family Controls request ids.
- Cloudflare resources and secrets (commands in `api/DEPLOY.md`).
- Sentry DSN and TelemetryDeck app id (`ios/Config/Base.xcconfig`, `api/wrangler.jsonc`); empty keeps each off.
- Donation URL (`TOLL_DONATION_URL`; the Settings row hides until set).
- Sign-off on `api/public/privacy.html` and `terms.html` (both marked draft).
- Listing copy (B1–B3) and the identity (`docs/toll-brand-tbd.md`): placeholders are in one token each.

## Branches and PRs

One stacked PR per layer, reviewed in order: E0 setup → E1 gate → E2 data → E3–E11 Worker → app services → TollUI → screens. Each commit names its task id and requirement ids.
