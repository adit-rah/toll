# Device protocol

MVP spec §11 and the device checks of §5. Two phones, five nights. Everything is read from the transition log (Settings → Transition log). Write results in the tables below and anything that changes the mechanism in `docs/decisions.md`. **A missed or late transition is a stop-and-ask (spec §13): report it before building on it.**

## Install
1. Merge the step 2 pull request, then `gh release create vX.Y.Z --target main --prerelease --title vX.Y.Z --generate-notes` (next number after `git tag -l`). Xcode Cloud sends it to TestFlight.
2. On each phone, go through setup. Note every location prompt's exact words and when it appeared, for unknown 5. Choose **Allow While Using App**, then **Change to Always Allow** when asked, and check Precise Location is on (Settings → the app → Location). On the blocklist screen, block a few apps and one whole category (decisions D27).
3. For daytime testing, set Settings → Sleep window to cover the next hour (outside a block it applies at once).

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
| 8 | Location downgraded to While Using mid-window, open the app, then leave | `permission` line; Status drops "if you're home"; the block stays on wherever you go until the window ends (D8) | | |
| 9 | Morning | `windowEnd → off` at the end time, `sweepStart = off` a minute later | | |
| 10 | Clock moved forward an hour during a block (Settings → General → Date & Time) | Block stays on; it ends at the real end time | | |
| 11 | Edit the window during a block | Settings shows the edit; it applies after `→ off` | | |
| 12 | Tap Never mind on the block screen after the end time (if the block is ever still up) | `blockScreen → off` | | |
| 18 | A second block (Study at another place, 15 min from now) | `windowStart` with `active` naming both while they overlap; each ends on its own | | |
| 19 | Upgrade from v0.2.0 (single Sleep block) | Sleep block and Home carried over; `windowStart` names new schedules; no `sleep.window` lines after | | |

| 13 | Door used: block screen → Unlock in Dusk → choose one app → wait 90 s → use it with the app closed | `doorChosen`, `doorStart` (door open), then `doorEnd` 5 min after it opened, on the clock (D31) | | |
| 14 | Door opened, then the phone locked for 10 min | `doorEnd` still 5 min after opening; the app is blocked again when unlocked | | |
| 15 | Door cancelled during the wait | `doorCancelled`; Status still shows the same unlocks left | | |
| 16 | Door regretted: Lock again within 2 min | `doorLocked`; unlocks back to where they were | | |
| 17 | Leave the app during the wait | The app opens anyway at the end of the wait (`doorStart`) | | |
| 20 | Block screen of an app → Unlock in Dusk (D41) | Dusk opens on "Open for 5 minutes?" with that app's icon and name; Start the wait opens that app after 90 s; "Choose a different app" opens Apple's picker | | |
| 21 | In Apple's picker at the door, pick two apps, then a whole category | "Choose one app" with what was picked; Choose again reopens the picker | | |
| 22 | Settings › Screen Time with Dusk denied | Note whether Settings has a switch for Dusk; if not, Permissions' note drops "or in Settings › Screen Time" | | |

## Unknowns (spec §5)
| # | Check | Result |
|---|---|---|
| 1 | During a block, with Phone, Messages and Clock not on the blocklist: receive and place a phone call; an alarm rings; Emergency SOS screen opens (do not complete a call) | |
| 2 | During a block, an app inside a blocked category is blocked; the door can open it through "Choose app" in Apple's picker | |
| 3 | Region enter and exit timing with the app closed; after restart; force-quit; Low Power Mode; airplane mode (scenarios 2–7) | |
| 4 | `windowStart → on` appears for scenario 1 with the app closed (the monitor read the home flag) | |
| 5 | Exact location prompts, in order, and when the Always prompt appeared | |

Also note: which system apps (Phone, Messages, Maps, Clock, Settings, Safari) stay open without being on the list, and whether websites in Safari are blocked.
