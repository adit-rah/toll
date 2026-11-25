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
| 33 | After a blocked night with two "Never mind" taps, open the app at 8 am (#103) | Tonight shows "Apps locked last night": a moon → sun bar with the real on and off times, "You chose sleep 2 times", last night's dot filled | | |
| 34 | Pause for 10 minutes during the night, open the app the next morning (#103) | The bar has a gap at the pause; VoiceOver reads "open from … to …" | | |
| 35 | Open the app at 12:01 pm after a blocked night (#103) | The morning card is gone; the hero shows "Apps lock at" and tonight's start | | |
| 36 | Monday morning after a week of nights, then again after Monday's night starts (#103) | Your sleep reads "A new week · N nights last week" over seven empty dots, then "This week" with Monday filled | | |
| 37 | Let the transition log trim (more than 10 nights), then compare Your sleep's count before and after (#103) | The count never drops | | |
| 38 | During a pause (#99, D67), open apps from every active block | Every blocked app, site and category opens, across all blocks at once | | |
| 39 | Start a pause, close Dusk, wait | Shields come back 10:00 after the wait ends, with the app closed (the DeviceActivity warning, 5 min before the 15-min interval ends) | | |
| 40 | Lock again within 2 minutes of a pause opening; then another pause, locked again after 3 minutes | The first: shields back at once and the dots back to the same count. The second: the pause stays spent | | |
| 41 | Cancel during the 60-second wait | Nothing spent; the dots are unchanged | | |
| 42 | Spend all 3, then check Sunday night, Monday 11:59 am and Monday 12:00 pm | None back until noon Monday, then 3, on the shield subtitle, Tonight's dots and the sheet | | |
| 43 | With 0 left, open a blocked app | The block screen has no pause button and reads "No pauses left. They come back Monday." | | |
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
| 59 | During the night with Study also on | The hero is "Apps locked until"; the Study line has no Pause capsule | | |
| 60 | Location While Using, home not set, Study at a place | Tonight shows no location card; Blocks shows Study's row with "Anywhere" | | |
| 61 | Open the Blocks tab, then any block editor | The night card leads (moon – sun); the editor hides the tab bar and Save is fully visible | | |
| 62 | The morning after the 7th night the lock ran (#118) | Tonight's card shows the Big Dipper tile, "7 nights. The Big Dipper is in your sky." and share. Your sleep's sky shows 7 stars with the last in amber, fading in once; reopening doesn't fade again | | |
| 63 | Tap share on a landmark morning | The share sheet shows the sky and "7 nights locked"; saving to Photos works. No network prompt; nothing else is in the image | | |
| 64 | A night away after a lock night; check the next morning and during the following night | No new star and the same count; the amber star turns white once the next night starts | | |
| 65 | VoiceOver on Your sleep | "Your sky. N nights locked. M constellations."; "Share" only on landmark days | | |
| 66 | Reduce Motion on, the morning after a night | The newest star still crossfades 200 ms; nothing else moves | | |
| 67 | AX5 on a landmark morning | The sky stays full width; the landmark shape stacks above its line; nothing is truncated | | |
| 68 | Evening before the night, home set | "Apps lock at", 10:30 pm, "At home · starts in …"; nothing says "phone-free" | | |
| 69 | Weekday-only night, Saturday afternoon | "Apps lock Monday at" | | |
| 70 | During the night, Pause, wait out the 60 s, swipe the sheet down | Hero "Paused until hh:mm · Then locked until 7:00 am" with Lock again; the sheet closes freely; Lock again locks; after 10 min "Apps locked until" returns with the app closed | | |
| 71 | Leave home during the night | "Night ends at 7:00 am · Apps lock when you're home"; no pill | | |
| 72 | In the free week, tap the pill | Purchase sheet; the pill dims on press; VoiceOver reads its hint | | |
| 73 | On a weekday, tap the night, Study and Gym on the strip; tap Edit | Each snippet is right; Edit opens that block's editor and Back reads "Tonight" | | |
| 74 | VoiceOver across the strip | "Now, …", then one element per segment with its snippet and an "Edit …" action | | |
| 75 | AX5: tap the night | The snippet opens as a sheet and scrolls; the state is above any card | | |
| 76 | Morning after a locked night | "Apps locked last night", "You chose sleep N times", "Tonight 10:30 pm" over the strip | | |
| 77 | Your sleep with Study used that week | "N h locked at night" excludes Study's hours; "N nights locked" | | |
| 78 | During the free nights, note "Night N of 14", delete Dusk, reinstall, open it (#115) | Welcome shows the trial still running; after setup the pill shows the same "Night N of 14 free"; Settings shows "Free nights · Night N of 14" | | |
| 79 | On a second iPhone on the same Apple ID with iCloud Keychain on, install Dusk and wait for Keychain to sync | Welcome and Ready continue from the first phone's start ("Free until the morning of …" matches), or "Free nights used" if they ended; the pill matches | | |
| 80 | On the second phone, finish setup before the Keychain item arrives, then reopen later | The night count jumps to match the first phone; the free nights end on the same morning | | |
| 81 | With iCloud Keychain off, set up, then delete and reinstall | Same night count as before; nothing else changes | | |
| 82 | Last free night: look at the pill | "Last free night tonight", 13 segments filled and the 14th outlined, on the amber tint | | |
| 83 | With no night on, set Settings › Before bed to Fixed 30 (#113) | Tonight's lock starts 30 min before bed; the night still ends at wake | | |
| 84 | During a locked night, change Before bed to Fixed 45 | Tonight's lock is unchanged and the row says "From tomorrow night"; tomorrow it locks 45 min before bed | | |
| 85 | Change the gap from 15 to 45, open Dusk, check pending notifications | The heads-up moves 30 min earlier, to 20 min before the new lock | | |
| 86 | New install, finish setup at 3 pm | The lock starts at bed − 15 that night; the heads-up comes 35 min before bed | | |
| 87 | After a week with ≥4 locked nights and ≤1 pause before bed, open Dusk Monday after noon | "This week, apps lock 30 min before bed · Up from 15"; "Keep 15" puts the lock back at bed − 15 that night | | |
| 88 | Install a build from before D76, update, open the day after a night | The night is unchanged; Tonight offers "Lock apps 15 min before bed?"; "Turn on" makes it 15, growing | | |
| 89 | Turn Screen Time off for Dusk midweek, then back on | At Monday noon the gap eases by 15 and doesn't grow for the next 2 Mondays | | |
| 90 | Run a night, foreground the app next morning, share the night records (#121) | Each line has `dusk.locked_min` (about 510 for 10:30 pm – 7:00 am, less 10 per pause) and `dusk.taps` with one time per "Never mind" | | |
| 91 | After 15+ nights, open Your sleep › All time | Nights and hours count every night since setup, not only the last ~10 | | |
| 92 | Home set: during the night, Settings › Only when I'm home › Use anywhere | The sheet closes, the row reads "Off from 7:00 am", and the night stays home-gated until it ends | | |
| 93 | Blocks › your night › Place | The same map opens, with "Use anywhere" under it | | |
| 94 | Open a blocked website | "This site is blocked for the night." | | |
| 95 | With pauses left, open a blocked app | The second button reads "Open Dusk to pause" | | |
| 96 | Restore purchase in Settings with a purchase on the Apple ID | The row reads "Purchase restored." and is gone the next time Settings opens | | |
| 97 | AX5: open a pause and wait 2 minutes | "This pause is used. Locking ends it early." over a pinned "Lock again" | | |
| 98 | AX5: open the purchase sheet | "Keep it" stays pinned; the price and footnote scroll | | |
| 99 | Open Tonight in the gap, after the lock and before bed (#119) | "Before bed" capsule under the pauses; the card once, with the minutes left until bed | | |
| 100 | Same, after bed, during a pause, or with Settings › Before bed's switch off | No capsule, no card | | |
| 101 | Breathe for 3 min with the silent switch on, then lock the phone | The tone is audible, keeps playing while locked, fades and stops at 3 min | | |
| 102 | Play a podcast, then start the tone | The podcast pauses; it may resume after the tone ends | | |
| 103 | A phone call, or unplug headphones, while the tone plays | The tone stops and doesn't come back; the sheet shows "Done" | | |
| 104 | Set the tone to 1 min in Settings, then breathe | It stops after 1 min | | |
| 105 | Open a helper, then foreground the next morning | That night's record has `"helper"`; the morning card, Your sleep and the sky are unchanged; no notification about helpers ever arrives | | |
| 106 | Tonight in the gap with Before bed's card, tap "Not now" | The card fades out over 200 ms in place; the time, dots, Pause, Before bed and the strip don't move | | |
| 107 | Text size xxxLarge (not an accessibility size), a card showing | The card is above the strip, under the bar, or after the state with the screen scrolling; it never covers the state, Pause, Before bed or the strip, and the state sits where it does without the card | | |
| 108 | iPhone SE or another 375-pt-wide phone, free nights with a card | The pill fits in the bar beside the gear (its segments may drop at large text); the card overlaps nothing | | |
| 109 | VoiceOver on Tonight with a card, swipe from the top | Settings, the pill, the state, the card, the strip | | |
| 110 | Reduce Motion on, dismiss a card | The same 200 ms fade | | |
| 111 | Edit Study a minute before it starts and keep the editor open until it starts | The note "Study is on until …" fades in over 200 ms above Delete; the card, Delete and Save don't move; Save reads "Save for after …" | | |
| 112 | The same, at text size AX5 | The note sits in the pinned bar above Delete and Save; the card doesn't move; the editor still scrolls above the bar | | |
| 113 | Tonight › Pause, tap "Pause for 10 min", wait 60 s | The sheet keeps its height through choosing, waiting and open; Pause, Cancel and Lock again sit on one line; only the content crossfades | | |
| 114 | Buy from the purchase sheet (sandbox), then again with Ask to Buy, then a failed purchase | The sheet keeps its height for "Every night is yours", "Waiting for approval" and "The purchase didn't go through"; the content swaps in place | | |
| 115 | Before bed › Breathe, let the tone end with the sheet open | "Stop the tone" becomes "Done" in the same place; nothing above moves | | |
| 116 | Set home from Tonight with a slow GPS fix | "Finding where you are" appears under the privacy line; when it goes, the map, the card and the privacy line don't move | | |
| 117 | Welcome at text size AX5 | The title starts at the top, the promise and offer scroll, and "Start my free nights" and Restore stay pinned at the bottom | | |
| 118 | Set the phone to 25 Nov 2026 (or any date with a known phase) and open Your sleep | The moon matches that night: full or nearly full on 25 Nov 2026 (full moon 24 Nov). A waxing quarter is lit on the right; with home south of the equator, on the left | | |
| 119 | Open Your sleep at 5 pm, 10 pm and 8 am | An amber glow at the horizon, almost none, then cool blue-grey; nothing animates between them | | |
| 120 | Tap near a lit star, then far from any star | A system popover points at that star with its date and "Locked … – …"; the far tap does nothing; at accessibility sizes it opens as a sheet | | |
| 121 | The morning after a night that ran, open Your sleep for the first time | The accent star brightens, then its new line draws from the star it joins; reopening shows it still, with no motion | | |
| 122 | The same with Reduce Motion on | One 200 ms crossfade of the star and its lines | | |
| 123 | On a landmark morning, tap share and Save Image | Photos has a 1080 × 1920 poster: evening sky, hills, moon, named figures, "30 nights locked", the date, "DUSK", and nothing else; no network prompt | | |
| 124 | Your sleep at AX5 | The sky keeps its height; the title is not truncated; the count sits on its own line; the cards below scale | | |
| 125 | VoiceOver on the sky | One element: "Your sky. 30 nights locked. 4 constellations: the Big Dipper, Cassiopeia, the Little Dipper, Orion." | | |
| 126 | Your sleep in light appearance, then scroll | The sky matches dark; only the land and page are pale; status text is white over the sky, and the bar takes the page colour once the sky has gone | | |
| 127 | Your sleep with 30+ nights: tap an empty part of the sky | Every name and line brightens in a 200 ms crossfade; nothing else moves. Tap empty sky again: they fade back | | |
| 128 | Names shown: switch to Tonight and back, then background the app and reopen | The names are faint again each time | | |
| 129 | Names shown: leave the phone untouched for 2 minutes | The names stay bright; nothing dims or pulses | | |
| 130 | Tap a star (e.g. Betelgeuse), then dismiss | Its popover opens and Orion's lines and name brighten; other figures stay faint. On dismiss, Orion fades back in 200 ms | | |
| 131 | Tap a star of an incomplete figure | Its lit lines brighten; no name appears | | |
| 132 | Before the first night (empty sky): tap the sky | Nothing changes | | |
| 133 | VoiceOver: focus the sky, then double-tap | It reads the label, then "Double-tap to show the names."; double-tap brightens them and the hint becomes "Double-tap to fade the names." | | |
| 134 | Show the names in the morning (from 5 am), evening (from 4 pm) and night (from 9 pm) | Every name is readable against the sky in each light, including any low near the hills | | |

## Unknowns (spec §5)
| # | Check | Result |
|---|---|---|
| 1 | During a block, with Phone, Messages and Clock not on the blocklist: receive and place a phone call; an alarm rings; Emergency SOS screen opens (do not complete a call) | |
| 2 | During a block, an app inside a blocked category is blocked; the door can open it through "Choose app" in Apple's picker | |
| 3 | Region enter and exit timing with the app closed; after restart; force-quit; Low Power Mode; airplane mode (scenarios 2–7) | |
| 4 | `windowStart → on` appears for scenario 1 with the app closed (the monitor read the home flag) | |
| 5 | Exact location prompts, in order, and when the Always prompt appeared | |

Also note: which system apps (Phone, Messages, Maps, Clock, Settings, Safari) stay open without being on the list, and whether websites in Safari are blocked.
