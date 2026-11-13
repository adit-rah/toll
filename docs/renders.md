# Renders

How an agent with no Mac sees the app (ledger A123). A GitHub macOS runner builds Toll for a simulator, opens each demo scenario, and pushes what it saw to the branch `renders/<branch>`:

| File | What it is |
|---|---|
| `README.md` | Index: commit, Xcode, device, and every screenshot in a table |
| `<variant>/<scenario>/screen.png` | Screenshot, half size (600 px wide) |
| `<variant>/<scenario>/ui.json` | Accessibility tree from `axe describe-ui`: label, value, traits and frame of every element. Read it for VoiceOver labels (design §5) and for what is actually on screen |
| `<variant>/<scenario>/log.txt` | The app's OSLog lines for that launch (subsystem `com.advan.toll`) |
| `<variant>/<scenario>/*.ips` | A crash report, if the app crashed |
| `<variant>/<scenario>/launch.txt` | What `simctl` said when installing and opening the app; read it when a screenshot shows the home screen |
| `timings.txt` | Build time (and whether the cache was used), boot wait, seconds per capture |
| `<variant>/<scenario>/steps.txt` | Output of the AXe steps, when the scenario had any |
| `api.log` | The local Worker's request log |

## Running it
1. Push a commit whose message contains `[render]`, or dispatch `render.yml` on the branch (inputs: `scenarios`, `variants`). A cloud session can dispatch it with the GitHub tools (`actions_run_trigger`, `run_workflow`).
2. `ios/scripts/fetch-renders.sh` (run it in the background) waits for the renders of `HEAD` and unpacks them into `build/renders/`. It needs only git. `COMMIT=<sha>` waits for another commit; `WAIT=0` takes whatever is there.
3. Open the PNGs and read `ui.json`. `timings.txt` says where the time went.

## Speed
Fastest loop: dispatch with only the scenarios the change touches and one variant. Every render of the light set renders nine screens.
- **Build cache.** Each push to `main` builds the app and saves Xcode's build output; a branch's first render starts from it, later renders from the branch's own last one. Xcode 26's compilation cache (`COMPILATION_CACHE_ENABLE_CACHING`) is keyed by content, so only what differs recompiles and the app is the same as a clean build. File times are reset to commit times first (`restore-mtimes.sh`) so unchanged files look unchanged. If a cached build fails anywhere but our own sources, `render.sh` builds clean once before it reports a failure.
- **Simulator.** It starts booting before anything else and boots behind the setup and build.
- **Settling.** Each screen is captured once its accessibility tree reads the same twice in a row (at most `SETTLE`, 12 s), not after a fixed wait. A screen with a running countdown, such as the gate, always takes the full 12 s.
- Each capture reinstalls the app, so no scenario sees another's data.

On a Mac with Xcode and AXe the same thing runs locally: `ios/scripts/render-api.sh > /tmp/api.env && set -a && . /tmp/api.env && set +a && ios/scripts/render.sh`.

## Scenarios
Defined in `ios/Packages/TollFeatures/Sources/TollFeatures/Demo/DemoLaunch.swift`; the app reads `-TollDemo <name>` in Debug builds only.

| Scenario | Opens on |
|---|---|
| `welcome` | Welcome |
| `permissions` | Setup: Screen Time permission (solo) |
| `setup-blocks` | Setup: first block (solo, Screen Time approved) |
| `solo-home` | Home, no account, three weeks of local history |
| `home` · `insights` · `people` | The tabs, signed in as the App Review account (friends, school, eight weeks of their events) |
| `gate` | The wait card, from a shield tap on Instagram |
| `screen-time-off` | Home with Screen Time permission revoked |

A screen behind a tap is a scenario plus AXe steps, one per line of the `scenarios` input:
```
home: tap --label "Settings" --wait-timeout 5
insights: gesture scroll-down; gesture scroll-down
```
Steps are AXe commands without `axe` and `--udid` (`tap --label`, `tap --id`, `gesture scroll-up|down`, `type 'text'`, `swipe …`). Find labels in a scenario's `ui.json`. For a state no tap reaches, add a scenario to `DemoScenario` and its data to `DemoSeed`.

Variants: `light`, `dark`, `ax5` (largest Dynamic Type), `dark-ax5`. Pushes render `light`; ask for `ax5` and `dark` (dispatch input `variants`) when a change touches layout, type or colour.

## What it cannot show
- Real app names and icons: picker tokens do not exist in the simulator, so apps read "This app".
- Shields, the picker, and anything that needs Family Controls. Those stay in `docs/gate-checklist.md`.
- Push notifications and Sign in with Apple.
