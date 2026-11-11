# Toll

Free iPhone app blocker with a social layer. Specs in `docs/` are the source of truth: `toll-mvp-spec.md` wins, then `toll-design.md`, then the others. Resolved conflicts and defaults are recorded in `docs/toll-future-ledger.md` §A; add yours there.

## Layout
- `api/` — Cloudflare Worker (Hono, Zod, Drizzle on D1, KV, Queues, R2). One folder per feature in `src/features/<name>/` (`routes.ts`, `contract.ts` Zod schemas, `service.ts`). Pure domain logic in `src/domain/`. DB tables in `src/db/schema/*.ts`.
- `ios/` — Xcode project (`Toll.xcodeproj`) with four targets: `App/`, `ShieldConfig/`, `ShieldAction/`, `Monitor/`. All logic lives in local packages under `ios/Packages/`:
  - `TollCore` — domain model, config, copy, pure logic. Linux-testable. Product `TollScreenTime` = Screen Time glue shared with the extensions.
  - `TollData` — GRDB store, spool ingest, outbox, API client, Keychain, analytics. Never imported by extensions.
  - `TollUI` — tokens and components. `TollFeatures` — one folder per screen.
- `fixtures/` — JSON fixtures shared by the Swift and TypeScript test suites (same inputs, same expected outputs).

## Commands
- Worker: `cd api && npm ci && npm run check` (Biome, tsc, Vitest in workerd). `npm run db:generate` after editing `src/db/schema`.
- Swift core on Linux or macOS: `swift test --package-path ios/Packages/TollCore`. Format: `swift format --in-place --recursive ios/`.
- App build (macOS): `xcodebuild build -project ios/Toll.xcodeproj -scheme Toll -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`. CI does this on every push (`.github/workflows/ios.yml`).

## Releasing
A build for a phone is a GitHub release with a new `v*` tag, nothing more: an automation picks the tag up, builds that commit and sends it to TestFlight. Take the next patch number after `git tag -l` (the first was `v0.1.0`, a pre-release). The tag can target a feature branch; no merge to `main`, version edit or workflow change is needed first. Claude cloud sessions cannot do this themselves: pushing a tag is refused (HTTP 403) and there is no release tool, so finish the branch, then hand the person the tag name and the commit to release.

## Rules
- Tunables only in `TollConfig.swift` / `api/src/config.ts`, with spec §14 defaults. User-facing strings only in `Copy.swift` (app; the one file allowed past 300 lines) or `api/src/copy.ts` (push and email); match spec §10 exactly, including the middle dot `·`.
- Name things by spec §4 terms: `GateEvent`, `Pass`, `Wait`, `Session`, `Block`, `AppRef`, `Tag`, `Rollup`.
- Files under ~300 lines; split by feature. Comments say why, never what. No file headers, no commented-out code, no TODO without an issue link.
- Tests only where spec §12 says: `TollCore` (Swift Testing) and `api/` (Vitest). No UI or snapshot tests. Gate behaviour on a phone goes in `docs/gate-checklist.md`.
- Every read of another person's data in the Worker goes through `src/domain/visibility.ts`.
- Migrations are additive only; generate them with drizzle-kit, never hand-edit an applied one.
- Swift 6 strict concurrency. No force unwraps outside tests. No `@unchecked Sendable` without a one-line reason.
- Accessibility is part of done: Dynamic Type to AX5, VoiceOver labels per design §5, never colour alone.
- Motion only from design §2.5; if a transition is not in that table there is none.

## Do not
- Add files to `project.pbxproj`. Targets use synchronized folders: drop a `.swift` file in the folder and it builds.
- Import `TollData`, GRDB, or anything large in an extension (DeviceActivityMonitor has ~6 MB).
- Write to the App Group from `ShieldConfig` (ignored on device, review risk), use private APIs, or add the App and Website Usage capability (spec §6).
- Add libraries, services or SDKs beyond spec §11 without a ledger entry.
- Send tokens, bundle ids or block names to the server. The server knows app refs and tags only.

## Branches
One branch per epic (`claude/toll-eN-…`), stacked in spec §15 order; one commit per task citing requirement ids (G-4, N-9…).
