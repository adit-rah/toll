---
name: render
description: See Toll's iOS screens, from a Linux cloud session or on a Mac. Use after changing anything under ios/ that shows on screen, to check layout, Dynamic Type (AX5), dark mode or VoiceOver labels, or when asked to run, screenshot or look at the app.
---

# Render the app

On a Mac (`xcodebuild` exists): do not use the workflow. Follow `docs/local-mac.md`; `SCENARIOS=<name> ios/scripts/render.sh` renders a screen in seconds after the first build.

In a cloud session the Linux container cannot build or run iOS. The `render` workflow does it on a GitHub macOS runner and pushes screenshots, accessibility trees and logs to the branch `renders/<branch>`. Full reference: `docs/renders.md`.

1. Push the change, then dispatch `render.yml` on the branch (GitHub `actions_run_trigger`, `run_workflow`) with `scenarios` set to just the screens you touched, one per line; that is the fast loop. Add `ax5` (and `dark` for colour changes) to `variants` when layout or type changed. Or commit with `[render]` in the message to render every screen in light mode, `[render light ax5]` to add AX5; that is the only way before `render.yml` is on `main`.
2. Run `ios/scripts/fetch-renders.sh` with `run_in_background`; it waits for the renders of HEAD and prints the index. `timings.txt` beside it says how long each part took.
3. Read `build/renders/<variant>/<scenario>/screen.png` to see each screen. Read `ui.json` beside it for labels and frames; check every control has a label per design §5, and that nothing is cut off at AX5.
4. A blank or wrong screen: read `log.txt`, any `.ips` crash report, and `api.log`. A build failure is in `README.md`.

Apps show their tag's name and a generic icon, standing in for the system's (`DemoStandIns`); that is not a bug to fix. Shields and the picker cannot be shown; those stay in `docs/gate-checklist.md`. Renders are for looking. Do not add assertions or snapshot comparisons (spec §12).
