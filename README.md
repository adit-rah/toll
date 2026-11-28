# Renders

Commit `ec97b6b` · 2026-11-28 18:37 UTC · Xcode 26.6 · iPhone-17 iOS-26-5

Each folder holds screen.png, ui.json (accessibility tree), log.txt (app log), launch.txt, and any
crash report. Where the time went: timings.txt.

| Scenario | light | dark | xxxl | ax5 | dark-ax5 | wordless |
|---|---|---|---|---|---|---|
| `settings-sleep` | ![](light/settings-sleep/screen.png) | ![](dark/settings-sleep/screen.png) | ![](xxxl/settings-sleep/screen.png) | ![](ax5/settings-sleep/screen.png) | ![](dark-ax5/settings-sleep/screen.png) | ![](wordless/settings-sleep/screen.png) |
| `settings-sleep: swipe --start-x 200 --start-y 500 --end-x 200 --end-y 100 --duration 0.15; swipe --start-x 200 --start-y 500 --end-x 200 --end-y 100 --duration 0.15; swipe --start-x 200 --start-y 500 --end-x 200 --end-y 100 --duration 0.15; swipe --start-x 200 --start-y 500 --end-x 200 --end-y 100 --duration 0.15; swipe --start-x 200 --start-y 500 --end-x 200 --end-y 100 --duration 0.15; swipe --start-x 200 --start-y 500 --end-x 200 --end-y 100 --duration 0.15; swipe --start-x 200 --start-y 500 --end-x 200 --end-y 100 --duration 0.15; swipe --start-x 200 --start-y 500 --end-x 200 --end-y 100 --duration 0.15` | ![](light/settings-sleep-swipe-start-x-200-start-y-500-end-x-200-end-y/screen.png) | ![](dark/settings-sleep-swipe-start-x-200-start-y-500-end-x-200-end-y/screen.png) | ![](xxxl/settings-sleep-swipe-start-x-200-start-y-500-end-x-200-end-y/screen.png) | ![](ax5/settings-sleep-swipe-start-x-200-start-y-500-end-x-200-end-y/screen.png) | ![](dark-ax5/settings-sleep-swipe-start-x-200-start-y-500-end-x-200-end-y/screen.png) | ![](wordless/settings-sleep-swipe-start-x-200-start-y-500-end-x-200-end-y/screen.png) |
