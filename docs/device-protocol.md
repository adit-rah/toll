# Device protocol

MVP spec §11 and the device checks of §5. Two phones, five nights. Everything is read from the transition log (the Trigger screen's last section until Settings exists). Write results in the tables below and anything that changes the mechanism in `docs/decisions.md`. **A missed or late transition is a stop-and-ask (spec §13): report it before building on it.**

## Install
1. Merge the step 2 pull request, then `gh release create vX.Y.Z --target main --prerelease --title vX.Y.Z --generate-notes` (next number after `git tag -l`). Xcode Cloud sends it to TestFlight.
2. On each phone, on the Trigger screen, in order:
   1. Permissions → Screen Time → Allow.
   2. Permissions → Location → Allow, choose **Allow While Using App**. Tap Allow again for **Change to Always Allow**. Check Precise Location is on (Settings → the app → Location). Note every prompt's exact words for unknown 5.
   3. Sleep window: set a wake time, adjust the start, Save. For daytime testing, set a window that covers the next hour.
   4. Home: stand at home, tap **Set home here**.
   5. Keep open: Choose. Pick a few apps; note whether Messages, Phone, Clock and Maps appear in the picker at all.

## Reading the log
Each line: time · cause · `→ on/off` (changed) or `= on/off` (a wake that changed nothing) · home/away · window. Causes: `windowStart`, `windowEnd`, `sweepStart`, `sweepEnd` (the monitor), `arrived`, `left` (region events), `blockScreen` (a button on the block screen), `edit`, `launch`, `foreground` (the app; logged only when they change something).

Pass (spec §11): every expected transition within two minutes of the real event, no missed block-on, no block on after the window ends.

## Nightly scenarios
| # | Scenario | Expect in the log | Phone A | Phone B |
|---|---|---|---|---|
| 1 | Home at window start | `windowStart → on` at the start time | | |
| 2 | Arrive after start | `arrived → on` within 2 min of crossing the radius | | |
| 3 | Leave and return mid-window | `left → off`, later `arrived → on` | | |
| 4 | Restart mid-window, do not unlock for 10 min, then unlock | Block still on after unlock; note what the log shows before unlocking | | |
| 5 | Force-quit the app mid-window, then leave and return | `left`/`arrived` still arrive with the app force-quit | | |
| 6 | Low Power Mode all night | 1 and the morning end as normal | | |
| 7 | Airplane mode overnight | Morning `windowEnd → off` or `sweepStart → off`; note region events after | | |
| 8 | Location downgraded to While Using mid-window, open the app, then leave | `permission` line; Trigger shows "Location off"; the block stays on wherever you go until the window ends (D8) | | |
| 9 | Morning | `windowEnd → off` at the end time, `sweepStart = off` a minute later | | |
| 10 | Clock moved forward an hour during a block (Settings → General → Date & Time) | Block stays on; it ends at the real end time | | |
| 11 | Edit the window during a block | Trigger shows "An edit waits…"; it applies after `→ off` | | |
| 12 | Tap OK on the block screen after the end time (if the block is ever still up) | `blockScreen → off` | | |

Door used, cancelled and regretted are added with step 6.

## Unknowns (spec §5)
| # | Check | Result |
|---|---|---|
| 1 | During a block, with none of them on the keep-open list: receive and place a phone call; an alarm rings; Emergency SOS screen opens (do not complete a call) | |
| 2 | During a block, Messages opens without being on the list | |
| 3 | Region enter and exit timing with the app closed; after restart; force-quit; Low Power Mode; airplane mode (scenarios 2–7) | |
| 4 | `windowStart → on` appears for scenario 1 with the app closed (the monitor read the home flag) | |
| 5 | Exact location prompts, in order, and when the Always prompt appeared | |

Also note: which system apps (Phone, Messages, Maps, Clock, Settings, Safari) stay open without being on the list, and whether websites in Safari are blocked.
