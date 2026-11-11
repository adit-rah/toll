# ios

`Toll.xcodeproj` has four targets that each need the Family Controls entitlement (spec §6):

| Target | Folder | Role |
|---|---|---|
| `Toll` | `App/` | The app. Thin: builds `Dependencies.live` and shows `RootView` from `TollFeatures`. |
| `TollShieldConfig` | `ShieldConfig/` | Shield text. Reads App Group defaults, writes nothing, returns in milliseconds. |
| `TollShieldAction` | `ShieldAction/` | "Open Toll": appends `block_hit` to the spool, then opens Toll or posts the fallback notification. |
| `TollMonitor` | `Monitor/` | DeviceActivity callbacks: schedules, session expiry, daily check-in. Under 6 MB: `TollCore` only. |

Logic lives in `Packages/` (see each package README). Targets use synchronized folders: add a file to the folder, never to `project.pbxproj`.

## Configuration
`Config/Base.xcconfig` holds the bundle id, App Group, link host, API URL and team id. To sign with a different team locally, put `DEVELOPMENT_TEAM = <team id>` in `Config/Signing.xcconfig` (git-ignored).

## Xcode Cloud (founders, once)
In Xcode: Product → Xcode Cloud → Create Workflow, on `main`. Actions: Test → `swift test` is covered by GitHub Actions, so use Build + Archive (iOS) and a TestFlight post-action on tags `v*`. Xcode Cloud needs the four Family Controls (Distribution) entitlements approved before the first TestFlight upload.

## Not testable here
Shield, DeviceActivity and authorization behaviour only run on a device. They are verified with `docs/gate-checklist.md`.
