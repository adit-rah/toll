---
name: render
description: See Toll's iOS screens from a Linux cloud session, with no Mac. Use after changing anything under ios/ that shows on screen, to check layout, Dynamic Type (AX5), dark mode or VoiceOver labels, or when asked to run, screenshot or look at the app.
---

# Render the app

The Linux container cannot build or run iOS. The `render` workflow does it on a GitHub macOS runner and pushes screenshots, accessibility trees and logs to the branch `renders/<branch>`. Full reference: `docs/renders.md`.

1. Commit the change with `[render]` in the message and push. To render particular screens or variants, dispatch `render.yml` on the branch instead (GitHub `actions_run_trigger`, `run_workflow`) with `scenarios` and `variants` inputs.
2. Run `ios/scripts/fetch-renders.sh` with `run_in_background`; it waits for the renders of HEAD (10–15 min) and prints the index.
3. Read `build/renders/<variant>/<scenario>/screen.png` to see each screen. Read `ui.json` beside it for labels and frames; check every control has a label per design §5, and that nothing is cut off at AX5.
4. A blank or wrong screen: read `log.txt`, any `.ips` crash report, and `api.log`. A build failure is in `README.md`.

The simulator cannot show real app names or icons, shields, or the picker; those stay in `docs/gate-checklist.md`. Renders are for looking. Do not add assertions or snapshot comparisons (spec §12).
