# Device protocol

MVP spec §11 and the device checks of §5. Two phones, five nights. Everything is read from the transition log (Settings → Transition log). Write results in the tables below and anything that changes the mechanism in `docs/decisions.md`. **A missed or late transition is a stop-and-ask (spec §13): report it before building on it.**

## Install
1. Merge the pull request. The `release` workflow tags the next version once CI passes, and Xcode Cloud sends it to TestFlight (`docs/releasing.md`).
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
| 20 | Block screen of an app → Unlock in Dusk (D41) | Dusk opens on "Open for 5 minutes?" with that app's icon and name; Start the wait opens that app after 90 s; "Choose a different app" opens Apple's picker | Pass (21 Nov, founder) | |
| 21 | In Apple's picker at the door, pick two apps, then a whole category | "Choose one app" with what was picked; Choose again reopens the picker | Pass (21 Nov, founder) | |
| 22 | Settings › Screen Time with Dusk denied | Note whether Settings has a switch for Dusk; if not, Permissions' note drops "or in Settings › Screen Time" | Pass (21 Nov, founder) | |
| 23 | Unlock in Dusk → Start the wait → Cancel; again, then Lock again within 2 min (#47) | Both close the sheet; it doesn't offer the same app again | Pass (21 Nov, founder) | |
| 24 | Spend the third unlock, let it close, then open a blocked app (#47) | No "Unlock in Dusk" button; the subtitle says no unlocks are left and when one returns. If the old button shows, note when it goes | Pass (21 Nov, founder) | |
| 25 | At the door, pick an app that no block lists (#47) | "That app isn't blocked right now"; no wait starts and nothing is spent | Pass (21 Nov, founder) | |
| 26 | Stay on "Open one app for 5 minutes?" for 3 minutes (#47) | The sheet stays until Not now | Pass (21 Nov, founder) | |
| 27 | After setup, switch Screen Time off for Dusk (Settings › Screen Time, or remove its access), then open Dusk (#45) | Home says "Screen Time off · Not blocking" with a "Turn on" card; Turn on shows the prompt again, or opens Settings if it can't. Note which | Pass (21 Nov, founder) | |
| 28 | Screen Time off for a night, then back on (#60) | Settings › Transition log shows "Screen Time off" on that night's lines; This week shows the night as "off", not as blocked | Pass (21 Nov, founder) | |
| 29 | Location While Using; save a Study block at a place, choose "Only at …" (#63) | No block during its hours away from the place or at it; rows say "Needs Always location"; after switching to Always it runs only at the place | Pass (21 Nov, founder) | |
| 30 | A night away, then a blocked night, with an unlock spent before (#61) | The refill's "N more blocked nights" drops by one only after the blocked night | | |
| 31 | Block screen of an app on a Study block, then on Sleep, with 2 unlocks left (#75) | The picture is a book over ●●○ for Study, a moon over ●●○ for Sleep | | |
| 32 | After two nights, Settings › Transition log › Share night records (#51) | A file with one line per ended night; tonight's isn't there until it ends; opening the app again adds no duplicates | | |
| 33 | After a blocked night with two "Never mind" taps, open the app at 8 am (#103) | Tonight shows Last night: a moon → sun bar with the real on and off times, "You put it down 2 times", last night's dot filled | | |
| 34 | Pause for 10 minutes during the night, open the app the next morning (#103) | The bar has a gap at the pause; VoiceOver reads "open from … to …" | | |
| 35 | Open the app at 12:01 pm after a blocked night (#103) | The morning card is gone; the hero shows tonight's start and "8 h 30 m phone-free tonight" | | |
| 36 | Monday morning after a week of nights, then again after Monday's night starts (#103) | Your sleep reads "A new week · N nights last week" over seven empty dots, then "This week" with Monday filled | | |
| 37 | Let the transition log trim (more than 10 nights), then compare Your sleep's count before and after (#103) | The count never drops | | |
| 38 | During a pause (#99, D67), open apps from every active block | Every blocked app, site and category opens, across all blocks at once | | |
| 39 | Start a pause, close Dusk, wait | Shields come back 10:00 after the wait ends, with the app closed (the DeviceActivity warning, 5 min before the 15-min interval ends) | | |
| 40 | Lock again within 2 minutes of a pause opening; then another pause, locked again after 3 minutes | The first: shields back at once and the dots back to the same count. The second: the pause stays spent | | |
| 41 | Cancel during the 60-second wait | Nothing spent; the dots are unchanged | | |
| 42 | Spend all 3, then check Sunday night, Monday 11:59 am and Monday 12:00 pm | None back until noon Monday, then 3, on the shield subtitle, Tonight's dots and the sheet | | |
| 43 | With 0 left, open a blocked app | The block screen has no "Pause in Dusk" button and reads "No pauses left · back Monday" | | |
| 44 | Fresh install, onboarding with no location ever asked; leave the phone away from where you sleep (#102) | No location prompt in onboarding. The block comes on at the night's start wherever the phone is (Sleep has no place). Tonight reads "Anywhere · starts in …" before it, and the block goes off at the night's end | | |
| 45 | The morning after row 44: Tonight shows "Only when I'm home?"; tap Set home → This is home → Allow → Always; that night, arrive home after the start (#102) | The card appears after the night ends, not before. After the sheet, Settings › Only when I'm home reads On and the card is gone. That night it stays off while away, then comes on at arrival. Repeating with "Not now": the card never returns and the Settings row stays | | |
| 46 | The morning after the first night (home set, or after the home card): Tonight shows "A heads-up before your night?" with a bell and "10:10 pm · 20 min before your night"; tap Turn on → Allow; swipe Dusk away and wait for the evening (#104) | The prompt appears only after Turn on, never in onboarding. The card is gone and Settings › Heads-up is on. At 20 min before the start, with Dusk closed, one silent notification: "Night starts in 20 min" / "10:30 pm – 7:00 am" | | |
| 47 | In the day, change the night's start 30 min later and close Dusk. Then during a night, change it back (held), and don't open Dusk until the next evening | The heads-up follows the new start. After the held edit, the next evening's follows the edited hours | | |
| 48 | Don't open Dusk for three days | A heads-up every evening, 20 min before each night | | |
| 49 | Settings › Heads-up off; wait for the evening. Turn it on again | None that evening; after turning it on, the next one is on time | | |
| 50 | Fresh install: "Not now" on the card. Another install: deny at the prompt | "Not now": the card never returns, nothing arrives. Denied: nothing arrives; Settings › Heads-up reads "Off in iOS Settings" and opens Dusk's iOS Settings page; allow there, return, and the row is on and the heads-up comes that evening | | |
| 51 | The evening of the last free night, then the evening after (not bought); separately, Screen Time off for Dusk, then open Dusk | One on the last free night, none after. With Screen Time off: none | | |
| 52 | Over five nights, check Notification Center | Only heads-ups from Dusk, nothing else | | |
| 53 | Blocks › New block › Gym (#89) | Apple's apps picker opens at once; after Done the editor shows "Gym", 6:00 pm – 7:00 pm, M–F, Place Anywhere; Save saves with one tap | | |
| 54 | New block › Study, pick apps, then Place › Current location › Use this place › Save block | Saved in 4 taps after the apps; the row reads the place and "9 am – 5 pm · Weekdays" | | |
| 55 | Edit Study: rename to "Library", change kind to Work, change Until to 6:00 pm inline, Save | Row and block screen read "Library" with the briefcase; hours 9 am – 6 pm; name and hours kept, not reset by the kind change | | |
| 56 | Type a 30-character name; then clear it to spaces | Typing stops at 24 characters; with only spaces Save is off | | |
| 57 | With 8 time windows used, change a block's hours to new times inline | The "Up to 8 time windows" note appears and Save stays off until the hours are put back | | |
| 58 | During Study's hours (night not on), open Tonight | The hero shows tonight's start or the morning card; one grey line "Study on until 5:00 pm" with lock and book, and Pause beside it; Pause lifts every block | | |
| 59 | During the night with Study also on | The hero is "Blocked until"; the Study line has no Pause capsule | | |
| 60 | Location While Using, home not set, Study at a place | Tonight shows no location card; Blocks shows Study's row with "Anywhere" | | |
| 61 | Open the Blocks tab, then any block editor | The night card leads (moon – sun); the editor hides the tab bar and Save is fully visible | | |
| 62 | The morning after the 7th night the lock ran (#118) | Tonight's card shows the Big Dipper tile, "7 nights. The Big Dipper is in your sky." and share. Your sleep's sky shows 7 stars with the last in amber, fading in once; reopening doesn't fade again | | |
| 63 | Tap share on a landmark morning | The share sheet shows the sky and "7 nights locked"; saving to Photos works. No network prompt; nothing else is in the image | | |
| 64 | A night away after a lock night; check the next morning and during the following night | No new star and the same count; the amber star turns white once the next night starts | | |
| 65 | VoiceOver on Your sleep | "Your sky. N nights locked. M constellations."; "Share" only on landmark days | | |
| 66 | Reduce Motion on, the morning after a night | The newest star still crossfades 200 ms; nothing else moves | | |
| 67 | AX5 on a landmark morning | The sky stays full width; the landmark shape stacks above its line; nothing is truncated | | |

## Unknowns (spec §5)
| # | Check | Result |
|---|---|---|
| 1 | During a block, with Phone, Messages and Clock not on the blocklist: receive and place a phone call; an alarm rings; Emergency SOS screen opens (do not complete a call) | |
| 2 | During a block, an app inside a blocked category is blocked; the door can open it through "Choose app" in Apple's picker | |
| 3 | Region enter and exit timing with the app closed; after restart; force-quit; Low Power Mode; airplane mode (scenarios 2–7) | |
| 4 | `windowStart → on` appears for scenario 1 with the app closed (the monitor read the home flag) | |
| 5 | Exact location prompts, in order, and when the Always prompt appeared | |

Also note: which system apps (Phone, Messages, Maps, Clock, Settings, Safari) stay open without being on the list, and whether websites in Safari are blocked.
