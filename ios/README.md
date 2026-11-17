# ios

`Toll.xcodeproj` has four targets that each need the Family Controls entitlement:

| Target | Folder | Role |
|---|---|---|
| `Toll` | `App/` | The app. Thin: shows `RootView` from `TollFeatures`. |
| `TollShieldConfig` | `ShieldConfig/` | The block screen's text. Reads App Group state, writes nothing, returns in milliseconds. |
| `TollShieldAction` | `ShieldAction/` | The block screen's buttons: "Open" opens the app (iOS 26.5+), "OK" closes. |
| `TollMonitor` | `Monitor/` | DeviceActivity callbacks: window edges, door expiry. Under 6 MB: `TollCore` only. |

The minimum is iOS 26.5, where the block screen can open the app directly (decisions D2). Logic lives in `Packages/` (see each package README). Targets use synchronized folders: add a file to the folder, never to `project.pbxproj`.

## Configuration
`Config/Base.xcconfig` holds the bundle id, App Group and team id. The bundle ids are Toll's: their Family Controls approvals carry over. To sign with a different team locally, put `DEVELOPMENT_TEAM = <team id>` in `Config/Signing.xcconfig` (git-ignored).

## Xcode Cloud
Build + Archive on tags `v*` with a TestFlight post-action. The tag sets the version: `ci_scripts/ci_post_clone.sh` turns `v0.2.0` into version 0.2.0 with Xcode Cloud's run number as the build.

## Not testable here
Shields, DeviceActivity, region monitoring and authorization only run on a device: `docs/device-protocol.md`.

## Seeing screens without a Mac
Debug builds open straight into a screen state with `-TollDemo <scenario>`; `scripts/render.sh` screenshots each one on a simulator and `render.yml` runs it on GitHub. See `docs/renders.md`; on a Mac, `docs/local-mac.md`.
