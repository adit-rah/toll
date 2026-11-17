# Working on the Mac

For an agent running on a founder's Mac (Claude Code in a terminal, or a cloud session attached to the Mac through Remote Control). Everything a cloud session does through `render.yml` runs here directly: the first build takes a couple of minutes, after that a change builds in seconds and a screen renders in about ten. Do not push `[render]` commits from here; render locally.

## Once
1. Xcode 26.5 or later (App Store), opened once to install the iOS simulator runtime.
2. `brew install cameroncooke/axe/axe` (accessibility trees, taps).
3. Optional, for driving the simulator from Claude without scripts:
   - MobileBuildMCP: `claude mcp add MobileBuildMCP -- npx -y mobilebuildmcp@latest mcp`.
   - Xcode's own MCP server: in Xcode, Settings → Intelligence → turn on the MCP server, then `claude mcp add --transport stdio xcode -- xcrun mcpbridge`.

## The fast loop
```sh
SCENARIOS=empty ios/scripts/render.sh   # build (incremental) and render one screen
```
Then read `build/renders/light/empty/screen.png`, `ui.json` and `log.txt`. Scenarios, steps, variants (`VARIANTS="light ax5 dark"`) and output are the same as the cloud renders; see `docs/renders.md`. `BUILD_ONLY=1 ios/scripts/render.sh` is the fastest compile check there is.

## By hand
Any Debug build opens a scenario when launched with `-TollDemo <scenario>`: `xcrun simctl launch booted com.advan.toll -TollDemo <scenario>`. In Xcode: Edit Scheme → Run → Arguments.

## Tests
`swift test --package-path ios/Packages/TollCore`

## What still needs the phone
Shields, the picker, DeviceActivity, region monitoring and Screen Time authorization do not work in the simulator. Install from Xcode on a device with the Family Controls (Development) entitlement and run `docs/device-protocol.md`.
