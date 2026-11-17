# Toll (sleep pivot)

iPhone app: when the user is home inside their sleep window, everything is blocked except a keep-open list; one scarce door lets one app through. Seven nights free, then one purchase. No backend. `docs/sleep-pivot-mvp.md` is the source of truth; `docs/design.md` carries the visual and motion rules. Decisions, findings and spec conflicts go in `docs/decisions.md`; add yours there.

## Layout
- `ios/` — Xcode project (`Toll.xcodeproj`) with four targets: `App/`, `ShieldConfig/`, `ShieldAction/`, `Monitor/`. All logic lives in local packages under `ios/Packages/`:
  - `TollCore` — config, copy, pure logic. Linux-testable. Product `TollScreenTime` = Screen Time glue shared with the extensions.
  - `TollData` — app-only services: Keychain, location, StoreKit. Never imported by extensions.
  - `TollUI` — tokens and components. `TollFeatures` — one folder per screen.

## Commands
- Swift core on Linux or macOS: `swift test --package-path ios/Packages/TollCore`. Format: `swift format --in-place --recursive ios/`.
- App build (macOS): `xcodebuild build -project ios/Toll.xcodeproj -scheme Toll -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`. CI does this on every push (`.github/workflows/ios.yml`).
- Seeing a screen. In a cloud session: dispatch `render.yml` with only the scenarios you changed (or push with `[render]`, or `[render light ax5]`, in the commit message), then run `ios/scripts/fetch-renders.sh` in the background and read the PNGs and `ui.json` it unpacks into `build/renders/`. Details: `docs/renders.md` (or the `render` skill). On a Mac: `docs/local-mac.md`.

## Releasing
A build for a phone is the branch merged into `main`, then a GitHub release with a new `v*` tag on `main`; Xcode Cloud builds it and sends it to TestFlight. The tag is the version (`ios/ci_scripts/ci_post_clone.sh`), so tags must be `vX.Y.Z`; take the next number after `git tag -l`. A cloud session can open and merge the pull request when asked, but cannot push a tag. After the merge, hand the person: `gh release create vX.Y.Z --target main --prerelease --title vX.Y.Z --generate-notes`.

## Rules
- Tunables only in `TollConfig.swift`, with spec §10 defaults. User-facing strings only in `Copy.swift` (the one file allowed past 300 lines); match spec §7 exactly. Info.plist purpose strings are the exception.
- Name things by spec §3 terms: `SleepWindow`, `Home`, `Block`, `KeepOpen`, `Door`, `Unlock`, `Night`. Cite rule ids (B-1, D-4, P-2…) in commits.
- Files under ~300 lines; split by feature. Comments say why, never what. No file headers, no commented-out code, no TODO without an issue link.
- Tests only where spec §11 says, in `TollCore` (Swift Testing). No UI or snapshot tests. Device behaviour goes in `docs/device-protocol.md`.
- Swift 6 strict concurrency. No force unwraps outside tests. No `@unchecked Sendable` without a one-line reason.
- Accessibility is part of done: Dynamic Type to AX5, VoiceOver labels per design §4, never colour alone.
- Motion only from design §2.5; if a transition is not in that table there is none.

## Do not
- Add files to `project.pbxproj`. Targets use synchronized folders: drop a `.swift` file in the folder and it builds.
- Import `TollData` or anything large in an extension (the monitor has ~6 MB).
- Write to the App Group from `ShieldConfig` (ignored on device, review risk), use private APIs, or add the App and Website Usage capability.
- Add networking beyond StoreKit, analytics, crash reporting or any third-party code (spec §9).
- Store coordinates other than the home point (spec §9).

## Branches
One branch per build step, `claude/sleep-s<N>-<name>`, stacked in spec §12 order, one pull request each (decisions D3).
