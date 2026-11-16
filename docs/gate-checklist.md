# Gate checklist (E10.48)

Run before every TestFlight build on two phones: one on iOS 26.5 or later, one on iOS 18.x. Tick each line on both unless it names one. Anything that fails goes in the fix list at the bottom with the phone, iOS version and build.

Unit tests cover the logic (`TollCore`: routing O-1…O-6, wait ladder, free passes, held, G-9 clock guard, schedules, shield plan, spool; `api/`: everything server-side). This list covers what only a phone can show.

## 0. Before you start
- [ ] Fresh install from TestFlight. Settings → Screen Time is on for the phone.
- [ ] Note the phone's iOS version and whether notifications are on.

## 1. Launch routing (flows §0, §1, §18)
- [ ] New, solo: Welcome → Continue without an account → Permissions → Block these → Home. No You step, no Find your friends; the bar shows 2 segments.
- [ ] New, signed in with Apple: Welcome → Apple sheet → You (name prefilled) → Permissions → Block these → Find your friends → Home; bar shows 4 segments.
- [ ] New, email: Welcome → Email → Code (autofills from Mail; no button needed) → You → … → Home.
- [ ] Apple sheet cancelled → back on Welcome, nothing changed.
- [ ] Terms and Privacy Policy links on Welcome open in-app and come back.
- [ ] Delete the app, reinstall, open: Welcome is skipped (Keychain session) → Permissions → "Block these again" (bar of 2) → Home with friends and history present.
- [ ] Reinstall after sign-out: Welcome → sign in → Permissions → "Block these again" → Home.

## 2. Email and code (flows §2)
- [ ] An address without "@" → "That doesn't look like an email", stays on Email.
- [ ] Wrong code → boxes shake, "Wrong code", boxes clear.
- [ ] Code older than 10 minutes → "Code expired", Resend highlighted.
- [ ] Resend → new code arrives; Resend is disabled for 30 s.
- [ ] Five wrong codes → locked for 10 minutes; the line says until when; back to Email.

## 3. You (flows §3)
- [ ] Tap the photo circle → picker; choose → avatar shows it; cancel → unchanged.
- [ ] Handle check: available shows the mark after the server answers, no spinner under 300 ms; a taken handle shows "taken" and suggestions; "Adit!" shows "letters, numbers, _".
- [ ] Continue with an empty name rings the Name field.

## 4. Permissions (flows §4)
- [ ] Allow → Screen Time sheet (Face ID / passcode) → notification prompt → Block these.
- [ ] Deny Screen Time → row reads Denied, "Toll can't block anything without Screen Time.", button reads Try again; no Skip anywhere.
- [ ] Deny again until the system stops asking → Try again opens the Settings app; grant there → back in Toll the step completes.
- [ ] Deny notifications → setup continues; daily summary is off in Settings; on iOS 18 the shield subtitle reads "Open Toll from your home screen."
- [ ] Both already granted (reinstall) → the step passes straight to Block these.

## 5. Block these (flows §5)
- [ ] The screen arrives empty: Done disabled, "Choose apps" in the card. The picker opens only from that row; Cancel with nothing chosen returns to the same empty state.
- [ ] Pick 3 apps → apps card lists them (system names and icons); Always is preselected.
- [ ] Pick 5 apps → card shows 3 rows and "+2 more"; tapping it shows the full list.
- [ ] Choose more → picker with the current apps selected.
- [ ] Nights / Weekdays tiles select with a fill crossfade and a selection haptic.
- [ ] Custom → sheet with From / Until and days → Done → the Custom tile shows the window. Drag down also returns.
- [ ] More than 40 apps across blocks → Done disabled, "40 apps is the most this phone allows."
- [ ] Add another block → the block shrinks into a compact row above and the card empties; the picker stays closed until Choose apps. A second Add another collapses the rows into one line ("2 blocks · Always, Weekdays"). Fits a 4.7-inch screen without scrolling.
- [ ] A compact row is a record of what was just made and does not open; blocks are edited from Settings → Blocks.
- [ ] Touch and hold an app row → Remove takes it out of the block.
- [ ] Done → the shield is up immediately for an Always block (open a blocked app to check).

## 6. Find your friends (flows §6, §13)
- [ ] Paste a valid code → the row shows the friend's name and "request sent". An invalid one → "No one has that code".
- [ ] Find friends from contacts → system prompt → matches with Add. Denied → the row reads "Allowed in Settings".
- [ ] School email at a listed domain → 6-digit code → row shows the school name. A non-school domain → "Not a school email we know".
- [ ] Skip and Done both land on Home; the step never shows again.
- [ ] Open an invite link before installing → install → Welcome → setup → Find your friends opens with the code prefilled and the request sent.
- [ ] Open an invite link while signed in and set up → People, row "Requested".
- [ ] Open an invite link as a solo user → "Sign in to add …" → sign-in options.

## 7. The shield (flows §8; spec G-1, G-2)
- [ ] Tap a blocked app inside its schedule → shield: "<App> is blocked.", "You've unblocked this N times today.", Open Toll, Dismiss.
- [ ] Dismiss → home screen. Toll later counts it as a gate held (Insights → Gates).
- [ ] **iOS 26.5+ only, the week-1 check (E1.9, ledger D1):** Open Toll opens Toll directly under individual authorization. If it does not, stop: file Feedback with a sysdiagnose and tell the founders (the notification route is the fallback, already built).
- [ ] iOS 18: Open Toll → a local notification "Open Toll" within ~10 s → tap it → Toll opens into the gate.
- [ ] iOS 18 with notifications off: subtitle reads "Open Toll from your home screen."; Dismiss, open Toll by hand within 2 minutes → the gate.
- [ ] Opening Toll more than 2 minutes after the hit → Home, no gate.
- [ ] An app in a blocked *category* (not picked by name): shield shows; Open Toll enters the gate; the first wait asks which app it is.
- [ ] A blocked web domain in Safari shows the shield; Open Toll works the same.
- [ ] Outside a Nights block's window the app opens normally and nothing is recorded.

## 8. The gate (flows §9, §10; spec G-3…G-10)
- [ ] First two opens of the day: free pass → Home's sheet opens by itself on the session picker ("How long?", "From now. The block returns after."), header "Free unlock", no countdown.
- [ ] Free pass → picker → "Not now": the sheet closes, Home's count does not move, friends see nothing, and the bar reads "Unlock ready" / "<App> · Choose how long". Tap the bar → the picker is back, still a free unlock. Or tap the same app again → shield → Open Toll → the picker is back. Unblock → now "1 unlock today".
- [ ] "Not now", then leave the pass until after 4 am → it is gone: the next open is a fresh free pass, not a third one.
- [ ] Insights → Gates: a free pass declined with "Not now" and never used counts as walked away.
- [ ] Third open: the sheet opens by itself on "<App>" / "Blocked · Always", countdown from 3:00, "Wait 1 of today · next wait 5 min", "The wait keeps running if you close this. You choose how long when it ends.", "Cancel the wait". A light haptic as it starts. From Insights or People, Toll switches to Home first.
- [ ] First wait for an untagged app asks "Which app is this?" with the seven chips; choosing one fills it and the others fade; the countdown never pauses. Ignoring it still lets the pass through.
- [ ] Swipe the wait sheet down → the bar reads "<App> unlocks in 2:41", counting, with the wait line beneath. Tap the bar → the same sheet, the same countdown.
- [ ] Leave Toll (home button) for a minute, come back → the countdown has continued.
- [ ] Force-quit Toll during a wait, reopen → the sheet opens on the wait with the correct time left.
- [ ] Airplane mode for the whole wait → the wait completes and the pass is recorded; it syncs later.
- [ ] Set the clock back an hour during a wait → the wait does not get longer than real time, and setting it forward an hour does not end it.
- [ ] While a wait runs, open a second blocked app → its shield → Open Toll → the same sheet, the same countdown (not reset, not extended).
- [ ] Cancel the wait → the sheet closes; next open starts a new wait of the next length.
- [ ] Countdown reaches 0 with the sheet open → the body crossfades into the picker, the header line reads "Waited 3 min", light haptic. With the sheet closed → the bar reads "Unlock ready" and the sheet does not open by itself; tap the bar → the picker. Coming back to Toll after it ended → the sheet opens on the picker.
- [ ] Choose 5 min → the button reads "Unblock for 5 min" and follows the chip → tap it: the sheet closes and Toll stays on Home (it does not switch apps); the bar reads "<App> is open" / "5-min unblock · 4:59 left" and counts down by the second. The app opens unshielded from the home screen. The unlock appears in the day's count now, not before.
- [ ] **5 min, the short-session workaround (spec G-6, §6):** start a 5 min session, stay in the app with Toll in the background → it re-shields at 5:00 by the wall clock. This is the end warning of a 15-minute interval; note how late it was. If it re-shields only at 15:00, the warning did not arrive or arrived before the expiry: file it in the fix list with the Console line `reconcile source=warning:session.…`.
- [ ] **10 min:** the same → re-shields at 10:00 (warning 5 minutes before a 15-minute interval).
- [ ] **15 min:** re-shields at 15:00 (interval end, no warning involved).
- [ ] A 5 min session where the app is never opened → still re-shields at 5:00: time is flat, use does not matter.
- [ ] Console, category `activity`: starting a 5 or 10 min session logs no "session activity failed" (that would be `intervalTooShort`).
- [ ] No early re-shield: during a 10 min session, lock the phone for 3 minutes and come back → the app is still open; the shield does not return before 10:00.
- [ ] With the monitor disrupted (reboot mid-session), open Toll after the session's time → the app re-shields on foreground and the bar is back to "… blocked".
- [ ] **Clock set back mid-session, Toll open (spec G-9):** start a 5 min session, note the real time, then in Settings turn off Set Automatically and set the clock back an hour. No reboot. Open Toll after 5 real minutes → the app is shielded again and the bar is back to "… blocked". Before that the bar's countdown may read about an hour; that is known and only the shield matters. Console, category `shield`: a `reconcile source=foreground` line with `ended=1`.
- [ ] **The same with Toll force-quit before the clock change:** open Toll after 5 real minutes → still re-shields. If it does not, the boot id Toll reads changed with the clock (`SystemClock.bootID` reads `kern.boottime`): file it in the fix list, because the same would let a clock change shorten a wait after a relaunch.
- [ ] **The same without opening Toll at all:** stay in the unblocked app and record when the shield returns. The monitor is woken by a wall-clock interval, so it may come only at the next schedule edge or when the set-back clock reaches the expiry; note which, with the Console `reconcile source=…` line.
- [ ] Set the clock forward an hour during a 10 min session → it ends when Toll or the monitor next runs (unchanged: the earlier of the two clocks ends a session).
- [ ] Set the clock back during a session, then reboot → only the wall clock is left: the session ends when the clock reaches the expiry (known: this lengthens it; record what happens).
- [ ] **A second unblock over a running session:** start a 15 min session from a shield hit on one app, then hit the same app's shield again later and take a 5 min session → the first session is gone (one countdown, 5 min), everything re-shields at 5:00, and nothing happens at 15:00.
- [ ] A session started 5 minutes before a Nights block ends → the app simply stays open after the window; nothing odd at the session's expiry.
- [ ] Both apps hit during one wait both unlock for the session.
- [ ] **Lock now:** during a session, tap the bar → "<App> is open" / "Opened 7:12 pm · locks at 7:22 pm", the line filling with the time gone, "6:42 left" · "10 min" → Lock now: a light haptic, the sheet closes, the app is shielded at once, the bar reads "… blocked", and the unlock still counts.
- [ ] Update over a build from before 11 Nov with a wait running → the wait continues and completes normally (old state decodes).
- [ ] The wait shows nowhere else: no lock-screen countdown, no notification at the end.
- [ ] Home footer: "You opened Toll N times today." at the end of the list increments on each open.

## 8a. Home v2: facts, bar and sheet (design §3.3, §3.18, §4.1)
- [ ] Under "N unlocks today": SCREEN TIME, THIS WEEK, BLOCKED. Screen time matches Settings → Screen Time for the blocked apps today (since 4 am) within a minute or two; it is drawn by `TollReport` and is blank on the simulator. Block a new app → the number includes it on the next visit to Home. With no blocked apps it reads "—".
- [ ] THIS WEEK shows "▼ 17" when behind last week, "▲" when ahead, no arrow when level. BLOCKED counts every shield hit today, Dismiss included.
- [ ] Console has no messages from `TollReport` about writes or network; Settings → Privacy shows no new data use. A TestFlight build has `TollReport.appex` in `Toll.app/Extensions` (not `PlugIns`).
- [ ] With an Always block: a bar sits 12 pt above the tab bar: icons, "Instagram, TikTok, YouTube blocked", "Always", a chevron, no buttons. It is there with no friends and with a long list; rows scroll under it. Light mode has a soft shadow, dark mode none.
- [ ] With a Nights block outside its window as well: the line reads "Always · 2 more from 11 pm". With only the Nights block, outside its window: clock tile, "Nothing blocked right now", "Nights starts at 11 pm · 2 apps". At 23:00 with Home open the bar changes by itself; at 07:00 it changes back.
- [ ] Tap the bar → a half-height sheet with a grabber: "Blocked right now", "3 apps · 2 more from 11 pm", a card of blocks ("Always · on now", "Nights · from 11 pm"), "Tap a block to change its apps or hours.", "Add a block". A row → the sheet closes and that block's editor is pushed. Add a block → New block → Done → the bar includes it without leaving Home. At 8 blocks "Add a block" is disabled. Swipe down and tap outside both dismiss.
- [ ] No blocks → "Nothing blocked yet" / "Choose apps to block" → the sheet's "Add a block" opens New block.
- [ ] **Countdown reaching zero:** start a 5 min session and keep Home open → the bar counts 0:02, 0:01, then turns back to "… blocked" within a second, without touching anything, and the app is shielded again. With the sheet open it changes to the blocks sheet in place.
- [ ] A session running when Toll is opened cold → the bar shows the right time left on the first frame.
- [ ] A wait or a picker arriving while a friend's sheet or Invite is open (leave Toll with it up, hit a shield, Open Toll) → that sheet closes and the wait sheet opens.
- [ ] VoiceOver: the bar is one button with the hint "Shows details", its lines read as one sentence; during a wait or a session the time is read in 30 s steps and nothing interrupts by itself. The three facts read "Screen time on blocked apps today, …", "This week, 11 unlocks, 17 last week", "Blocked, 11 times today".
- [ ] Largest accessibility text size: the facts stack, the bar's lines wrap and it grows, nothing clips; the sheet scrolls and its button stays at the bottom.

## 8b. Background launches (ledger A131)
- [ ] With Toll closed and the phone on a very slow network (Settings → Developer → Network Link Conditioner, "Very Bad Network"), trigger a silent push (the daily one, or a test push) and a background refresh (Xcode: Debug → Simulate Background Fetch). No crash report for Toll appears in Settings → Privacy & Security → Analytics Data; Console shows "answered at the background budget" or "answered early", and the outbox is sent the next time Toll opens.

## 9. Blocks (flows §14)
- [ ] Settings → Blocks lists each block with icons, names and schedule; caption "Removing a block is shown to your friends."
- [ ] Navigation holds: Blocks → Add a block → pick apps → Done lands on Blocks; Back from Blocks lands on Settings; Back again lands on Home. The same after editing a row, and after Discard.
- [ ] Add a block arrives on the empty card; nothing opens until Choose apps.
- [ ] Open a block and leave it untouched → the system Back button shows (no discard prompt); Done records no change.
- [ ] Home's "Nothing blocked yet · Add apps" → New block → Done → Home, and the line is gone without leaving the app.
- [ ] Swipe → Remove → "Remove <App>? Your friends will see this." → Remove: the shield drops; a friend's Home pins "<Name> removed <App> from their blocklist."
- [ ] Change Always → Nights: a friend sees "<Name>'s <App> block is now nights only." pinned.
- [ ] Tap an app's tag in New block → chips → choose → friends' lines re-label past passes too.
- [ ] Back without Done → "Discard changes?"
- [ ] 8 blocks → Add a block disabled, and "8 blocks is the most." shows beneath the list; remove one → the caption goes.
- [ ] A Nights block shields at 23:00 and lifts at 07:00 (leave the phone overnight; check both edges). **Verifies one overnight DeviceActivity schedule per block (ledger A31).**

## 10. Device state on Home (flows §7, §19)
- [ ] Turn Toll off in Settings → Screen Time → reopen Toll → the bar reads "Screen Time is off" / "Nothing is blocked until it's back on" with an orange shield. Tap → "Since today", the card, "Turn on Screen Time" → system sheet → approved → the bar is back to "… blocked".
- [ ] Turn on Screen Time → Don't Allow on the sheet (or no sheet at all) → the Settings app opens; turn Screen Time on there → back in Toll the bar changes and blocked apps are shielded again without another tap. The next day with it still off, the sheet reads "Since yesterday", then the weekday.
- [ ] One block with an expired app (iOS 26.5 `tokensDidExpire`, or a registry entry removed in a debug build) → the bar reads "Blocks need re-picking" / "Some apps are missing" although the block's other apps still work; the sheet lists that block; its row opens the editor with its remaining apps, the line "Some apps are missing from this block. Choose them again." and the system Back button (no discard prompt). Choose more → the line goes → Done → the bar changes back.
- [ ] Two blocks affected → the sheet lists both; Blocks marks each "Needs re-picking" beneath its names (VoiceOver reads it); the others show their schedule.
- [ ] After two days with Toll's permission off, a friend sees "Toll has been off on <Name>'s phone since <day>." pinned; one check-in clears it.
- [ ] Delete every block → the bar reads "Nothing blocked yet" → its sheet's "Add a block" → New block.

## 11. Friends and Home (flows §7, §11, §12)
- [ ] Friends ordered by improvement on their own last week; ties by name.
- [ ] Friend rows: "Opened Instagram at 11:40 p.m. after a 5-minute wait", "(free pass)", "0 passes today", silent with a dashed glyph.
- [ ] Long-press a row → Remove, Block, Report. Block → "Block <Name>? You won't see each other anywhere." → gone from Home, People, mutuals, school.
- [ ] Report → reasons + text → Send → "Also block this person?"
- [ ] Pull to refresh syncs; rows move without bouncing.
- [ ] Sign in on a fresh install in airplane mode (or with the API unreachable) → Home's Friends section reads "No connection.", not "No friends yet."; pull to refresh online → friends, or the empty line. With friends already cached, airplane mode keeps the rows.
- [ ] People → Accept or Decline in airplane mode → the row stays and a line at the top says "No connection." or "That didn't work. Try again."; online again, pull to refresh clears it.
- [ ] VoiceOver reads a row as one sentence ("Adi, about usual, 3 passes today, down 23 percent on last week").
- [ ] Largest accessibility text size: rows stack, nothing clips; the hero stops growing at AX2.

## 12. Notifications (flows §17)
- [ ] Daily summary at 10:00 local: "N passes yesterday. Kth of M friends." Tap → Home. With a pending request the sentence ends "1 friend request waiting." and the tap opens People.
- [ ] Nothing else ever appears on the lock screen.
- [ ] Below iOS 26.5: with Toll in front, pull down Notification Center and tap a waiting "Open Toll" notification from a shield → the wait sheet opens; the Toll-opens count on Home rises by at most one.
- [ ] Notifications off for Toll in the Settings app → Toll's Settings shows "Notifications are off" and "Open Settings" in place of the summary switch and time; Open Settings → the Settings app → allow → back in Toll the switch and time are there without leaving the screen.

## 13. Account (flows §16, §20)
- [ ] Settings → Delete account → confirm → re-authenticate → Welcome; Screen Time shields are gone; reinstalling shows no history.
- [ ] Solo user signs in from People → new account → You → history uploads (Insights unchanged) → Find your friends.
- [ ] Settings → Account → change the handle to one in use → Save → "taken" beside the field, still on the screen. Change it twice within a month → "Handles change once a month." beneath the fields. Change only the name → Save returns to Settings with the new name.

## Fix list

| Phone / iOS / build | Line | What happened |
|---|---|---|
| | | |
