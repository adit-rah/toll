# Renders

How an agent sees the app (ledger A123). On a Mac, render locally: `docs/local-mac.md`. In a cloud session (Linux, no Mac), a GitHub macOS runner builds Toll for a simulator, opens each demo scenario, and pushes what it saw to the branch `renders/<branch>`.

## Quick start (cloud)
1. Push your change. Then either dispatch `render.yml` on your branch with `scenarios` set to just the screens you touched (GitHub `actions_run_trigger`, method `run_workflow`, ref = your branch), or push a commit whose message contains `[render]` to render all nine screens (`[render light ax5]` picks the variants). Dispatch needs `render.yml` on `main`; before that, use the commit message.
2. Run `ios/scripts/fetch-renders.sh` with `run_in_background`. It waits for the renders of `HEAD`, unpacks them into `build/renders/` and prints the index. It needs only git.
3. Read `build/renders/<variant>/<scenario>/screen.png`, and `ui.json` beside it.

Expect about 12 minutes for all nine screens and 7–8 for one or two, most of it the runner setting up. `timings.txt` says where each run's time went.

## What comes back
| File | What it is |
|---|---|
| `README.md` | Index: commit, Xcode, device, and every screenshot in a table. A build failure or a run that stopped early says so here |
| `<variant>/<scenario>/screen.png` | Screenshot, half size (600 px wide) |
| `<variant>/<scenario>/ui.json` | Accessibility tree from `axe describe-ui`: label, value, traits and frame of every element. Read it for VoiceOver labels (design §5), truncated text, and what is actually on screen |
| `<variant>/<scenario>/log.txt` | The app's OSLog lines for that launch (subsystem `com.advan.toll`) |
| `<variant>/<scenario>/launch.txt` | What `simctl` said when installing and opening the app; read it when a screenshot shows the home screen |
| `<variant>/<scenario>/steps.txt` | Output of the AXe steps, when the scenario had any |
| `<variant>/<scenario>/*.ips` | A crash report, if the app crashed |
| `timings.txt` | Build, boot wait, and per screen: total seconds and seconds to first frame |
| `api.log` | The local Worker's request log |

## Scenarios
Defined in `ios/Packages/TollFeatures/Sources/TollFeatures/Demo/DemoLaunch.swift`; Debug builds read `-TollDemo <name>`, Release builds do not contain any of it. Signed-in scenarios talk to a local Worker seeded with the App Review account (`ios/scripts/render-api.sh`): real friends, school and eight weeks of their events, through the real API.

| Scenario | Opens on |
|---|---|
| `welcome` | Welcome |
| `permissions` | Setup: Screen Time permission (solo) |
| `setup-blocks` | Setup: first block (solo, Screen Time approved) |
| `solo-home` | Home, no account, three weeks of local history |
| `home` · `insights` · `people` | The tabs, signed in as the App Review account |
| `gate` | The wait card, from a shield tap on Instagram |
| `screen-time-off` | Home with Screen Time permission revoked |

A screen behind a tap is a scenario plus AXe steps, one per line of the `scenarios` input (or the `SCENARIOS` variable locally):
```
home: tap --label "Settings" --wait-timeout 5
insights: gesture scroll-down; gesture scroll-down
```
Steps are AXe commands without `axe` and `--udid` (`tap --label`, `tap --id`, `gesture scroll-up|down`, `type 'text'`, `swipe …`). Find labels in a scenario's `ui.json`. For a state no tap reaches, add a case to `DemoScenario` and its data to `DemoSeed`.

Variants: `light`, `dark`, `ax5` (largest Dynamic Type), `dark-ax5`. Pushes render `light`; ask for `ax5` (and `dark` for colour) whenever a change touches layout or type. AX5 renders have already caught truncation that light renders did not.

## How it works, and why it takes the time it does
- **Runner.** GitHub's free macOS runner (3 cores). The simulator starts booting first and boots behind the setup and build; the device script also opens Settings once, so the simulator's slow first app launch happens during the build rather than the first screenshot. AXe is cached after its first install.
- **Build.** Debug, arm64 simulator, no index store, about 2–3 minutes cold. A build cache restored from `main` was tried and measured: it saved what restoring it cost, so it is not used (ledger A124).
- **Capture.** Each screen gets a fresh install, so no scenario sees another's data, and is captured once its accessibility tree has content and reads the same twice in a row (at most `SETTLE`, 12 s). A screen with a running countdown, such as the gate, always takes the full 12 s. The app takes 5–15 s to its first frame on the runner.

## What it cannot show
- Real app names and icons. Picker tokens do not exist in the simulator, so in demo launches an app shows its tag's name with a generic icon, and blocks never read as needing re-picking (`DemoStandIns`). On a phone the same places show the system's name and icon.
- Shields, the picker, and anything else that needs Family Controls. Those stay in `docs/gate-checklist.md`.
- Push notifications and Sign in with Apple.
