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
| `welcome` · `fit` · `setup-sleep-found` · `setup-sleep-weekends` · `setup-sleep-ask` · `setup-sleep-none` · `setup-around` · `setup-around-before` · `setup-around-off` · `screen-time` · `screen-time-allowed` · `screen-time-denied` · `blocklist` · `ready` · `ready-health` | Each onboarding screen (D68, #144: no map, no location). Welcome with "Buy it now"; Fit Dusk to your sleep; Your sleep found in Health (a demo watch's four weeks, asleep about 11:20 pm, up about 7:10 am), with Fri and Sat nights apart, asked, and asked after Health had fewer than 7 nights; the time around sleep as recommended (30 growing to 60 before, 15 growing to 30 after), the sheet for the side before sleep, and with the side after set to none; Ready as recommended and after Health. Screen Time is assumed from `blocklist` on |
| `home-fit-card` · `fit-sheet` · `fit-sheet-sleep` · `fit-sheet-around` | One-time flow #1 for people set up before #144: its card on Tonight's evening, and its sheet on each of its three steps, from their own night and gap |
| `settings-how-it-works` | Settings' How it works sheet, its numbers from the config (#52) |
| `fit-sheet-around-fitted` | The flow's last step for someone whose weeks fitted their targets (#145): before sleep grows to 45, and the footnote says so |
| `settings-sleep` · `settings-sleep-after` | Settings › Sleep: the night drawn lock · sleep · open, the hours, a row for each buffer and the helpers; `-after`: the sheet for the buffer after waking (growing, fixed or none) |
| `set-home` · `set-home-off` · `set-home-location` · `set-home-always` · `set-home-location-off` · `set-home-set` | "Only when I'm home" as a sheet over Tonight: the map (home placed in London; `-off` with location denied), the location prompt, Always, and location off; `-set`: the map with home already set, offering "Use anywhere" |
| `home-evening` · `home-blocked` · `home-away` · `home-first-week` · `home-last-night` · `home-paused` · `home-location` | Home in each state, with a Sleep and a Study block and a sample week of log, built around the time of the render |
| `home-recovered` | Tonight after the state file was lost and the night came back from its record without its apps: the quiet note with "Choose apps" (#140) |
| `home-read-only` | Tonight on a TestFlight build older than the one that wrote the state file: the note that changes can't be saved (#140) |
| `home-morning` · `home-morning-gap` · `home-morning-away` · `home-morning-card` | Tonight at 8:10 am with last night folded to its row in the band: after a night with taps, with a ten-minute pause, and away; `-card`: after the first night with home not set, so the home card shows with it. A tap opens the row: `home-morning: tap --id tonight.lastNight --wait-timeout 5` |
| `home-morning-open` · `home-morning-landmark-open` | The same morning with last night's card open, grown up from its row; and the 30th night's, a landmark, open |
| `home-morning-location` · `home-morning-gap-week` · `home-morning-flow` · `home-morning-card-open` | Tonight's band (`TonightBand`) at 8:10 am, last night's row under one card: the location note (While Using); Monday's card on Tuesday morning; one-time flow #1's card, "Fit Dusk to your sleep" (#144, once-fit-sleep.md); and the home card with last night open under it, which fades the card out |
| `home-night-hour` · `home-night-hour-monday` | The hour before the lock, 9:30 pm: the heads-up offer is due and waits for tomorrow, so the band is empty; on Monday, after the gap grew to 30, Monday's card is the one card |
| `home-anywhere` · `home-card` | Home not set yet: the first evening ("Anywhere"), and the morning-after card offering home |
| `home-day` | Tonight on a weekday at 11 am with Study on: the one quiet line about another block (D68, #89), and Study and Gym on the day's strip (D75) |
| `home-strip-night` · `home-strip-day` | The strip's snippet open (D75): on the night in the evening, and on Study at 11 am. A tap reaches the same: `home-evening: tap --id strip.sleep --wait-timeout 5` |
| `home-pill-purchase` · `home-pause-open` | The purchase sheet the free-week pill opens, over Tonight in the first week (D75; a tap reaches it too: `home-first-week: tap --id tonight.pill --wait-timeout 5`), and Tonight's hero while a pause is open ("Paused until") |
| `home-heads-up` · `home-heads-up-on` · `home-heads-up-denied` | Home set, the evening after the first night: the card asking for the heads-up (#104), and its answer after "Turn on" (#160): on, with its time, and refused in iOS's prompt |
| `home-before-bed` · `home-before-bed-card` · `before-bed` · `before-bed-list` · `before-bed-breathe` · `before-bed-words` | The helpers before sleep (D80), at 10:15 pm in a 30-minute gap: Tonight's "Before sleep" capsule, its one card, the sheet's three choices and each page (the tone drawn as playing, with no sound). Settings' switch and the breath's length are on `settings-sleep` |
| `home-gap-week` · `home-gap-offer` | The gap before bed (D76): Monday evening after the gap grew from 15 to 30 minutes ("Keep 15"), and the one card offering the gap to an install from before it |
| `purchase` · `settings` · `settings-anywhere` · `settings-heads-up-denied` · `settings-while-using` · `insights` | The purchase sheet, Settings (with home set, and not set; with notifications denied, the heads-up row offers iOS Settings; with location While Using, the Location row does) and Your sleep |
| `blocks` · `blocks-day` · `blocks-many` · `blocks-many-day` | The Blocks tab (the night, Study and Gym), in the evening and on a weekday at 11 am with Study on; `-many`: four other blocks folded into one row (#110), and at 11 am with Study on, open by itself |
| `block-new` · `block-new-gym` | New block: the kinds, then Gym picked with its default hours and no apps yet. The simulator has no app tokens, so editors of a block with apps draw its fixture's count and plain stand-in tiles for the icons (#110) |
| `block-edit` · `block-edit-on` · `block-night` · `block-place` · `block-delete` | Editing Study, editing it while it's on, and editing the night; Study's place picker, and its delete sheet (#141) |
| `blocks-off` · `block-edit-off` | Study switched off (#161): its row on Blocks in the evening, and its editor at 11 am on a weekday, inside its hours. Its switch turned on there says it waits for the next start: `block-edit-off: tap --label "On"` |
| `sleep-monday` · `sleep-best` | Your sleep at 8:10 am on the latest Monday ("A new week") and Sunday (a personal best) (#103) |
| `sleep-sky-5` · `sleep-sky-7` · `sleep-sky-30` · `sleep-sky-100` · `home-morning-landmark` · `sky-share` | Your sky (D79) at 8:10 am after 5, 7, 30 and 100 nights, and Tonight's morning on the 30th, a landmark, its row saying the landmark's line; `sky-share`: the picture a landmark shares |
| `door-choosing` · `door-waiting` · `door-open` · `door-none` | The pause sheet (D67) over a blocked Tonight |
| `sleep-sky-0` · `sleep-sky-180` · `sleep-sky-star` · `sleep-sky-evening` · `sleep-sky-night` · `sleep-sky-morning` | Your sky: empty (no nights yet); the second pass at 180 nights; Betelgeuse's night open in its popover, with Orion brought forward (30 nights, 8:10 am); and 30 nights in each light by the demo clock: evening 7:55 pm, night 11:40 pm, morning 8:10 am |
| `welcome-running` · `welcome-used` · `welcome-bought` | Welcome's other offers (#141): a trial started on this phone 3 days ago, one that ended (30 days ago), and bought |
| `home-pause-waiting` · `door-open-used` | Tonight with the pause's wait running and its sheet swiped away (Pause brings it back); the pause open past its 2 minutes, "This pause is used" over Lock again (#129, #141) |
| `home-held-home` · `home-blocked-anywhere` | The night locked with "Use anywhere" chosen during it, held until it ends (B-3, #129); and locked with home not set (#141) |
| `sleep-after-trial` | Your sleep after the free nights ended, not bought: the free nights' dots, two rows of seven (#129) |
| `settings-screen-time-off` · `settings-log` | Settings with Screen Time off for Dusk, and the activity log (#141) |
| `sleep-health-improving` · `sleep-health-flat` · `sleep-health-noisy` · `sleep-dusk` · `sleep-few` | Your sleep's measures (#88) at 8:10 am, after four weeks of a watch's nights falling asleep earlier, staying about the same, and too noisy to say; the same improving weeks from Dusk's own nights alone (Health not chosen: the stand-ins and "Add your sleep from Apple Health"); and three nights with Health (values, no comparisons). Scroll to them: `sleep-health-improving: gesture scroll-down` |
| `home-morning-asleep` · `home-morning-asleep-open` · `home-morning-ask-open` | Last night's row and open card led by Health's sleep ("Asleep 11:20 pm – 6:55 am · 7 h 35 m"); and the morning after the first night for someone who skipped Health, open on "See how you slept" (#86) |
| `sleep-sky-names` | Your sky at 30 nights, 8:10 am, with every name and line brought forward, as a tap on the open sky does. A tap reaches it in any light: `sleep-sky-evening: tap -x 340 -y 270` (open sky at 30 nights) |

A screen behind a tap is a scenario plus AXe steps, one per line of the `scenarios` input (or the `SCENARIOS` variable locally):
```
home: tap --label "Settings" --wait-timeout 5
insights: gesture scroll-down; gesture scroll-down
```
Steps are AXe commands without `axe` and `--udid` (`tap --label`, `tap --id`, `gesture scroll-up|down`, `type 'text'`, `swipe …`). Find labels in a scenario's `ui.json`. For a state no tap reaches, add a scenario.

Demo scenarios run on a pinned clock (`DemoClock`): 11:40 pm for states inside Sleep's 10:30 pm – 7:00 am, 7:55 pm for the evening before it, 8:10 am for the mornings, whatever the runner's time; the fixture is in place before the first frame, and demos never reconcile against the real store. Door countdowns use the real clock.

Variants: `light`, `dark`, `ax5` (largest Dynamic Type), `dark-ax5`, `xxxl` (the largest size below the accessibility sizes, where Tonight still floats its band), and `wordless` / `dark-wordless`, which draw every line of text as a placeholder bar for the wordless test (design §5). The device is the newest "iPhone N" unless a dispatch names another in `device` (`RENDER_DEVICE` locally), such as `iPhone SE (3rd generation)` for the smallest screen; each run replaces the branch's renders, so fetch one device's before dispatching the next. Pushes render `light`; ask for `ax5` (and `dark` for colour) whenever a change touches layout or type. AX5 renders have already caught truncation that light renders did not.

## How it works, and why it takes the time it does
- **Runner.** GitHub's free macOS runner (3 cores). The simulator starts booting first and boots behind the setup and build; the device script also opens Settings once, so the simulator's slow first app launch happens during the build rather than the first screenshot. AXe is cached after its first install.
- **Build.** Debug, arm64 simulator, no index store, about 2–3 minutes cold. A build cache restored from `main` was tried and measured: it saved what restoring it cost, so it is not used.
- **Capture.** Each screen gets a fresh install, so no scenario sees another's data, and is captured once its accessibility tree has content and reads the same twice in a row (at most `SETTLE`, 12 s). A screen with a running countdown, such as the door, always takes the full 12 s. The app takes 5–15 s to its first frame on the runner.

## What it cannot show
- Real app names and icons: picker tokens do not exist in the simulator.
- The block screen, the picker, region monitoring, and anything else that needs Family Controls or a real location. Those are in `docs/device-protocol.md`.

## Last night on the strip
`home-strip-last-night`: Tonight at 8:10 am with last night's card already put away, and the strip's popover open on last night at its start. It is not in `ALL`; dispatch it by name.

## Motion
A still can't show a pop or a stutter, so a scenario line can also be filmed. Mark it `motion`:
```
motion home-morning: tap --id tonight.lastNight
motion home-morning: tap -x 150 -y 645; wait 1.5; tap -x 150 -y 465
```
- **What the runner does.** It opens the scenario and waits for it to settle as for a still, starts `xcrun simctl io <udid> recordVideo --codec=h264`, runs the steps back to back (no settling between them; `wait <seconds>` is a step), waits 1.5 s, and stops the recording with SIGINT so the file is finalised. Then it takes the usual screenshot and tree.
- **What comes back,** beside `screen.png`: `motion.mp4`, and `motion.txt`, each step's start in seconds from the recording's start. `fetch-renders.sh` lists the videos after the index. A motion line runs in every variant asked for, so dispatch motion lines with one variant.
- **Steps are slow.** Each AXe command takes 2–3 s on the runner and they run one at a time (a second one waits, or fails with "Another AXe command is using the simulator"), so a tap can't land mid-animation: check interrupting on a device. Taps by position (points, from the scenario's `ui.json`) skip the lookup that `--id` and `--label` do. After a tap, hit testing follows where things are going, so the next tap aims where the element ends up. Many demo actions do nothing ("Not now", "Pause for 10 min", "Lock again", the tab bar): film what a demo can show, and leave the rest to the device protocol.
- **A video of one frame** means the steps changed nothing: a lost tap (it has happened to the first motion line of a run) or a demo action that does nothing. `steps.txt` says where each tap landed; render it again.
- **Reading it, in a Linux session:** `ios/scripts/motion-strip.sh build/renders/light/<line>/motion.mp4`. It needs ffmpeg and python3 with Pillow, and writes beside the video, in `strip/`:
  - `frames/`: every frame at 60 fps, from 100 ms before the interaction to 400 ms after the strip.
  - `strip.png`: every 2nd frame for 600 ms (`SPAN`) after the interaction, each with its time, and a bar per frame of how much it changed from the one before.
  - `change.txt`: per frame, the time from the interaction, the mean absolute difference from the frame before (0–255) and a flag: `pop` (one frame carries far more change than its neighbours: a jump), `dead` (a still frame between moving ones: a dropped frame), `restart` (the screen stood still 50 ms or more, then moved again: two animations where one was meant).
  - The interaction is the first frame that changes after the first step in `motion.txt`; `AT=<seconds>` sets it (the second tap of a line, say). `CROP=w:h:x:y` (video pixels, 3× points on the render device) looks closer at one part, which also makes small changes count.
- **What it can't judge.** The simulator writes a frame only when the screen changes, runs well below the phone's 120 Hz, and often catches the first 50–100 ms of a change late, so judge the order and continuity of things (what rides with what, what overlaps, what jumps), not the exact curve, smoothness or frame rate; a `dead` frame on the runner is not a dropped frame on a phone. Haptics and Reduce Motion are checked on a device (`docs/device-protocol.md`).
