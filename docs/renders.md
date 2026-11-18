# Renders

How an agent sees the app. On a Mac, render locally: `docs/local-mac.md`. In a cloud session (Linux, no Mac), a GitHub macOS runner builds Toll for a simulator, opens each demo scenario, and pushes what it saw to the branch `renders/<branch>`.

## Quick start (cloud)
1. Push your change. Then either dispatch `render.yml` on your branch with `scenarios` set to just the screens you touched (GitHub `actions_run_trigger`, method `run_workflow`, ref = your branch), or push a commit whose message contains `[render]` to render every screen (`[render light ax5]` picks the variants). Dispatch needs `render.yml` on `main`; before that, use the commit message.
2. Run `ios/scripts/fetch-renders.sh` with `run_in_background`. It waits for the renders of `HEAD`, unpacks them into `build/renders/` and prints the index. It needs only git.
3. Read `build/renders/<variant>/<scenario>/screen.png`, and `ui.json` beside it.

Expect 7–8 minutes for one or two screens, most of it the runner setting up. `timings.txt` says where each run's time went.

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

## Scenarios
Defined in `ios/Packages/TollFeatures/Sources/TollFeatures/Demo/` as each screen arrives (MVP spec §12 steps 4–8); Debug builds read `-TollDemo <name>`, Release builds contain none of it. The default list is `ALL` in `ios/scripts/render.sh`.

| Scenario | Opens on |
|---|---|
| `empty` | The empty window |
| `welcome` · `wake` · `home` · `permissions` · `blocklist` · `ready` | Each setup screen (spec §7 Setup 1–6); home is placed in London, Screen Time is assumed from `blocklist` on |
| `status-blocked` · `status-starts` · `status-away` | Status in each of its three states, built around the time of the render |
| `door-choosing` · `door-waiting` · `door-open` · `door-none` | The door sheet over a blocked Status in each of its states; no app icon (no tokens in the simulator) |
| `trial-ended` | The trial-ended screen with a sample week; `status-starts` also shows the trial line |

A screen behind a tap is a scenario plus AXe steps, one per line of the `scenarios` input (or the `SCENARIOS` variable locally):
```
home: tap --label "Settings" --wait-timeout 5
insights: gesture scroll-down; gesture scroll-down
```
Steps are AXe commands without `axe` and `--udid` (`tap --label`, `tap --id`, `gesture scroll-up|down`, `type 'text'`, `swipe …`). Find labels in a scenario's `ui.json`. For a state no tap reaches, add a scenario.

Variants: `light`, `dark`, `ax5` (largest Dynamic Type), `dark-ax5`. Pushes render `light`; ask for `ax5` (and `dark` for colour) whenever a change touches layout or type. AX5 renders have already caught truncation that light renders did not.

## How it works, and why it takes the time it does
- **Runner.** GitHub's free macOS runner (3 cores). The simulator starts booting first and boots behind the setup and build; the device script also opens Settings once, so the simulator's slow first app launch happens during the build rather than the first screenshot. AXe is cached after its first install.
- **Build.** Debug, arm64 simulator, no index store, about 2–3 minutes cold. A build cache restored from `main` was tried and measured: it saved what restoring it cost, so it is not used.
- **Capture.** Each screen gets a fresh install, so no scenario sees another's data, and is captured once its accessibility tree has content and reads the same twice in a row (at most `SETTLE`, 12 s). A screen with a running countdown, such as the door, always takes the full 12 s. The app takes 5–15 s to its first frame on the runner.

## What it cannot show
- Real app names and icons: picker tokens do not exist in the simulator.
- The block screen, the picker, region monitoring, and anything else that needs Family Controls or a real location. Those are in `docs/device-protocol.md`.
