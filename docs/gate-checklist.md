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
- [ ] First two opens of the day: free pass → session picker at once ("How long?"), no wait card.
- [ ] Third open: wait card "<App>", countdown from 3:00, "Wait 1 of today · next wait 5 min", Cancel. A light haptic as it starts.
- [ ] First wait for an untagged app asks "Which app is this?" with the seven chips; choosing one collapses the section; the countdown never pauses. Ignoring it still lets the pass through.
- [ ] Leave Toll (home button) for a minute, come back → the countdown has continued.
- [ ] Force-quit Toll during a wait, reopen → remaining time is correct.
- [ ] Airplane mode for the whole wait → the wait completes and the pass is recorded; it syncs later.
- [ ] Set the clock back an hour during a wait → the wait does not get longer than real time, and setting it forward an hour does not end it.
- [ ] While a wait runs, open a second blocked app → its shield → Open Toll → the same card, the same countdown (not reset, not extended).
- [ ] Cancel → back to Home; next open starts a new wait of the next length.
- [ ] Countdown reaches 0 with Toll open → the card becomes the picker (crossfade, light haptic). Coming back after it ended → the picker directly.
- [ ] Choose 5 min → "Open <App>" → the app opens unshielded. Home shows "<App> is open · ends after 5 min of use."
- [ ] Use the app ~5 minutes → it re-shields (threshold). Note how late it was.
- [ ] Choose 15 min, don't use the app, wait 60 minutes → it re-shields (window end).
- [ ] With threshold delivery disrupted (reboot mid-session), open Toll after the window → the app re-shields on foreground.
- [ ] Both apps hit during one wait both unlock for the session.
- [ ] The wait shows nowhere else: no lock-screen countdown, no notification at the end.
- [ ] Home footer: "You opened Toll N times today." increments on each open.

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
- [ ] 8 blocks → Add a block disabled.
- [ ] A Nights block shields at 23:00 and lifts at 07:00 (leave the phone overnight; check both edges). **Verifies one overnight DeviceActivity schedule per block (ledger A31).**

## 10. Device state on Home (flows §7, §19)
- [ ] Turn Toll off in Settings → Screen Time → reopen Toll → "Screen Time is off · Fix" at the top; Fix → sheet → approved → the line collapses.
- [ ] After two days with Toll's permission off, a friend sees "Toll has been off on <Name>'s phone since <day>." pinned; one check-in clears it.
- [ ] Delete every block → "Nothing blocked yet · Add apps" → New block.

## 11. Friends and Home (flows §7, §11, §12)
- [ ] Friends ordered by improvement on their own last week; ties by name.
- [ ] Friend rows: "Opened Instagram at 11:40 p.m. after a 5-minute wait", "(free pass)", "0 passes today", silent with a dashed glyph.
- [ ] Long-press a row → Remove, Block, Report. Block → "Block <Name>? You won't see each other anywhere." → gone from Home, People, mutuals, school.
- [ ] Report → reasons + text → Send → "Also block this person?"
- [ ] Pull to refresh syncs; rows move without bouncing.
- [ ] VoiceOver reads a row as one sentence ("Adi, about usual, 3 passes today, down 23 percent on last week").
- [ ] Largest accessibility text size: rows stack, nothing clips; the hero stops growing at AX2.

## 12. Notifications (flows §17)
- [ ] Daily summary at 10:00 local: "N passes yesterday. Kth of M friends." Tap → Home. With a pending request the sentence ends "1 friend request waiting." and the tap opens People.
- [ ] Nothing else ever appears on the lock screen.

## 13. Account (flows §16, §20)
- [ ] Settings → Delete account → confirm → re-authenticate → Welcome; Screen Time shields are gone; reinstalling shows no history.
- [ ] Solo user signs in from People → new account → You → history uploads (Insights unchanged) → Find your friends.

## Fix list

| Phone / iOS / build | Line | What happened |
|---|---|---|
| | | |
