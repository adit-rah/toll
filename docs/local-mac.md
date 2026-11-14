# Working on the Mac

For an agent running on a founder's Mac (Claude Code in a terminal, or a cloud session attached to the Mac through Remote Control). Everything a cloud session does through `render.yml` runs here directly, without the 10-minute round trip: the first build takes a couple of minutes, after that a change builds in seconds and a screen renders in about ten. Do not push `[render]` commits from here; render locally.

## Once
1. Xcode 26 (App Store), opened once to install the iOS simulator runtime.
2. `brew install cameroncooke/axe/axe` (screenshots' accessibility trees, taps) and Node 22 (`brew install node@22`).
3. `cd api && npm ci`.
4. Optional, for driving the simulator from Claude without scripts:
   - MobileBuildMCP (formerly XcodeBuildMCP): `claude mcp add MobileBuildMCP -- npx -y mobilebuildmcp@latest mcp`. It builds, runs, screenshots, reads the accessibility tree and taps. `npx -y mobilebuildmcp@latest tools` lists its tools.
   - Xcode's own MCP server: in Xcode, Settings → Intelligence → turn on the MCP server, then `claude mcp add --transport stdio xcode -- xcrun mcpbridge`. Needs Xcode open with `ios/Toll.xcodeproj`; its `RenderPreview` draws a `#Preview` to an image.

## The fast loop
```sh
ios/scripts/render-api.sh > /tmp/toll-api.env   # once per session; the Worker keeps running
set -a; . /tmp/toll-api.env; set +a
SCENARIOS=home ios/scripts/render.sh             # build (incremental) and render one screen
```
Then read `build/renders/light/home/screen.png`, `ui.json` and `log.txt`. Same scenarios, steps (`home: tap --label "Settings"`), variants (`VARIANTS="light ax5 dark"`) and output as the cloud renders; `docs/renders.md` has them. `timings.txt` shows the build and each screen. The simulator stays booted between runs, so only the first run waits for it. Stop the Worker with `pkill -f "wrangler dev"`.

Builds: `ios/scripts/render.sh` keeps its own build folder (`build/render-derived`), separate from Xcode's, so Xcode and the script never invalidate each other. `BUILD_ONLY=1 ios/scripts/render.sh` is the fastest compile check there is. The CI command in `CLAUDE.md` builds every architecture with a cold cache; locally it is only worth running before a push that touches the project file or build settings.

## By hand, or from an MCP tool
Any build of the Debug app opens a scenario when launched with `-TollDemo <scenario>`; signed-in scenarios also need the session from `render-api.sh` in the environment:
```sh
SIMCTL_CHILD_TOLL_DEMO_TOKEN=$TOKEN SIMCTL_CHILD_TOLL_DEMO_API=$API \
  xcrun simctl launch booted com.advan.toll -TollDemo insights
```
The token goes in the environment, never as an argument: a base64url token can start with `-`. In Xcode, the same goes in the scheme: Edit Scheme → Run → Arguments.

## Tests
- `swift test --package-path ios/Packages/TollCore`
- `cd api && npm run check`

## What still needs the phone
Shields, the picker, DeviceActivity and Screen Time authorization do not exist in the simulator (spec §6). Install from Xcode on a device with the Family Controls (Development) entitlement and work through `docs/gate-checklist.md`.
