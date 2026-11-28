# Sleep pivot — MVP spec

Date: 2026-11-17 · Companion: `sleep-pivot-brief.md` (why and for whom). This document is what gets built. `[Name]` stands for the product name, not yet chosen. Numbers marked *(config)* are starting values in one config file and are expected to change.

**Kickoff line for the builder:** "Read `docs/sleep-pivot-brief.md`, then build `docs/sleep-pivot-mvp.md` in the existing Toll repo, in the order of §12. Read the existing code first. Stop and ask at the points listed in §13."

## 1. The product

When the user is at home inside their sleep window, everything on the phone is blocked except what they chose to keep open. One scarce door lets one app through for a few minutes. Seven nights are free; after that a single purchase keeps it running. Everything lives on the device.

## 2. Scope

**In:** setup; the nightly block; the door; trial and one-time purchase; a status screen; settings; a transition log (kept until the founders remove it).

**Out:** accounts, backend, any networking beyond StoreKit; friends, school, invites, profiles; insights, charts, share cards; notifications other than the block-screen route on older iOS; multiple places or schedules; a way to end the whole night; widgets; Android. Delete the corresponding Toll code; do not flag it off.

## 3. Terms

| Term | Meaning |
|---|---|
| **Sleep window** | Start and end time, local, repeating nightly. May cross midnight. |
| **Home** | One circular region around a point the user confirms. Radius 150 m *(config)*. |
| **Block** | The shield on everything except the user's keep-open list. On only when home AND inside the window AND entitled (trial or purchased). |
| **Keep-open list** | Apps and sites the user exempts from the block. |
| **Door** | The one way through: one chosen app, a few minutes, after a wait. |
| **Unlock** | One use of the door. A small supply. |
| **Night** | One sleep window, counted when it ends. |

## 4. Rules

**Block**
- B-1. Block is on if and only if: home, inside the window, and entitled.
- B-2. Arriving home inside the window turns it on. Leaving home turns it off. The window ending turns it off.
- B-3. Edits to the window, home or the keep-open list made while the block is on take effect when it next turns off. Outside a block they apply at once.
- B-4. If state is uncertain after the window's end time (missed callback, restart, clock change), the block is lifted. It must never be stuck on in the morning.
- B-5. On every app launch, foreground and extension wake, reconcile: compute what the block should be from the clock, the last known home state and entitlement, and apply it.
- B-6. Every transition is appended to the log with time, cause and resulting state.

**Door**
- D-1. From the block screen the user opens `[Name]`, picks one blocked app, and waits 90 s *(config)*. Leaving the app does not cancel the wait; the end time is stored.
- D-2. When the wait ends the chosen app is unblocked for 5 minutes of use *(config)*, then blocked again. If the timing callback is missed, re-block on the next reconcile after the stored expiry.
- D-3. Opening the door spends one unlock at the moment the app is unblocked, not when the wait starts. Cancelling during the wait costs nothing.
- D-4. Regret: if the user taps "Lock again" within 2 minutes *(config)* of the app being unblocked, the unlock is returned. The app says this on the door-open screen. It is not mentioned anywhere else.
- D-5. Supply: 3 unlocks *(config)*, shown wherever the door is offered. At 0 the door is not offered and the screen says when one returns.
- D-6. Refill: one unlock returns after 7 consecutive nights *(config)* in which none was spent, up to the maximum. There is no other way to get one.
- D-7. One door at a time. There is no way to end the block for the night.

**Trial and purchase**
- P-1. The first screen and the store listing state the terms: 14 nights free, then $9.99 once, no subscription (amended by D78 and D34; the words are in `Copy`).
- P-2. The trial covers the first 14 nights *(config)* after setup, whether or not the user was home (amended by D78).
- P-3. After the trial, without a purchase, the block does not turn on. The status screen shows the week's summary and the purchase.
- P-4. One non-consumable purchase. Restore is available in Settings and on the purchase screen. Trial start is stored where a reinstall does not reset it.
- P-5. No price, feature or reminder varies by user. No prompts to buy before the trial ends, other than a quiet "night 5 of 7" line on the status screen.

## 5. Platform facts and unknowns

Known from the Toll work: tokens are opaque (the app cannot tell which app is which); DeviceActivity intervals must be at least 15 minutes and callbacks can be late or missing; the monitor extension has a small memory ceiling and no network; more than 50 individually shielded tokens fails; on iOS 26.5+ the block screen can open the app directly, below that it needs a notification the user taps.

Consequences for this product:
- **The block uses "everything except" shielding** (all categories, with the keep-open list as exceptions), not a list of chosen apps.
- **The app cannot preselect the keep-open list,** because it cannot identify Maps or Music. Setup opens the system picker with a line suggesting what to keep (messages, maps, music, ride-hailing, the clock). Whatever the user picks is the list.
- **The door's 5 minutes** is a usage threshold inside a 15-minute interval, with a stored expiry as the fallback.

**To verify on a device before relying on it** (report findings in `docs/decisions.md`):
1. Phone calls, alarms and Emergency SOS work during an "everything except" block without being on the keep-open list.
2. Whether Messages is blocked by default and needs to be on the list.
3. Region enter and exit wake the closed app within two minutes; behaviour after restart, force-quit, Low Power Mode, airplane mode.
4. The monitor extension can read a shared home flag at window start.
5. Which location authorization is required, and the exact prompts the user sees.
6. Apple's current rule for a free trial on a non-subscription purchase, and for background location in this category.

## 6. Mechanism (suggested, to be confirmed by §5)

- A repeating DeviceActivity schedule for the sleep window. On start: if entitled and the shared home flag is true, apply the shield. On end: clear it.
- Region monitoring for home. On enter: set the flag; if inside the window and entitled, apply the shield. On exit: clear the flag and the shield.
- A separate short DeviceActivity activity per door use, with a usage threshold; on threshold or interval end, re-apply the shield for that app.
- State in the App Group: window, home flag and timestamp, entitlement, door state with expiries, unlock supply and refill counter, trial start.
- `reconcile()` in shared code, called from the app and every extension entry point.

## 7. Screens

Plain words, facts only, no encouragement. Titles sit at one position on every screen. Light and dark. Visual foundations and motion rules carry over from `toll-design.md` §2.

**Setup (shown once)**
1. **Welcome.** `[Name]`. "14 nights free. Then $9.99 once. No subscription." Button: "Start my 14 free nights" (D78, D34, D97).
2. **Wake time.** "When do you get up?" A time picker. Beneath: "Your nights: 10:30 pm to 7:00 am" (wake time minus 8 h 30 min *(config)*), editable. Button: "Continue".
3. **Home.** "Where do you sleep?" A map centred on the current location with the region drawn. Button: "This is home". Precedes the location prompt with one line: "`[Name]` only checks whether you are home. It never records where you go."
4. **Permissions.** "`[Name]` needs two things": Screen Time, Location. One button, "Allow", runs the system prompts. If denied: the row says so, one line explains, the button becomes "Try again". There is no skip.
5. **Keep open.** "What should still work at night?" One line: "Most people keep messages, maps, music and the clock." Button: "Choose" opens the system picker. On return the chosen items are listed. Button: "Done".
6. **Ready.** "Tonight at 10:30 pm, if you're home." Button: "OK".

**Status (the only main screen)**
- Top: state in one line. "Blocked until 7:00 am" / "Starts at 10:30 pm, if you're home" / "You're away. Nothing is blocked."
- Beneath: "Unlocks left: 2 of 3". If below the maximum: "One returns after 4 more nights without using any."
- During the trial: "Night 5 of 14 free." (D78)
- A gear for Settings. Nothing else.

**Block screen (system-rendered)**
- Title: "Blocked until 7:00 am." Subtitle: "You're home and it's your sleep time." Buttons: "Open `[Name]`" · "OK".

**Door (sheet over Status, opened from the block screen)**
- Choosing: "Open one app for 5 minutes?" "Unlocks left: 2 of 3." Button: "Choose app" → system picker limited to one. Quiet: "Not now".
- Waiting: the app's icon, a countdown, "Opens in 1:30." Quiet: "Cancel". One line: "Cancelling costs nothing."
- Open: "Open for 5 minutes of use." Button: "Lock again". For the first 2 minutes, one line: "Lock again in the next 2 minutes and you keep the unlock."
- None left: "No unlocks left. One returns after 7 nights without using any."

**Trial ended (replaces Status until purchase)**
- "Seven nights." Then facts from the log: nights blocked at home, times the block screen came up, unlocks used.
- Button: "Keep it — $24.99 once". Quiet: "Restore purchase". One line: "Without it, nothing is blocked."

**Settings**
- Sleep window · Home · Keep open · Restore purchase · Privacy policy · Support address · Transition log (until removed) · Version.
- One line under the first three: "Changes apply after tonight's block ends."

## 8. Copy rules

Only words a first-time user already knows: blocked, open, unlock, home, away, night. Every line is a fact, a number or a question. Never an adjective about the user. Times in the user's 12- or 24-hour format. All strings in one file.

## 9. Data

On device only. App Group defaults for state; a small append-only log file; Keychain for trial start. No analytics SDK, no crash SDK, no third-party code. The privacy label is "Data Not Collected". Location is used to compute one boolean and is never stored as coordinates beyond the home point.

## 10. Configuration

| Key | Default |
|---|---|
| `window.leadHours` | 8.5 (window start = wake time minus this) |
| `home.radiusMeters` | 150 |
| `door.waitSeconds` | 90 |
| `door.minutes` | 5 |
| `door.regretSeconds` | 120 |
| `unlocks.max` | 3 |
| `unlocks.refillNights` | 7 |
| `trial.nights` | 7 |
| `price` | $24.99 (set in App Store Connect) |

## 11. Tests

Unit tests for what can be wrong silently: window maths across midnight, daylight-saving changes and time-zone travel; the block state function (home × window × entitled) and reconcile after every kind of missed event; door spend, regret return and refill counting; trial night counting across reinstall. No UI tests.

Device protocol, two phones, five nights, read from the transition log: home at window start; arrive after start; leave and return mid-window; restart mid-window; force-quit; Low Power Mode; airplane mode overnight; location downgraded; door used, door cancelled, door regretted. **Pass:** every expected transition within two minutes, no missed block-on, and no block on after the window ends.

## 12. Build order

1. Strip: remove everything in §2 "Out". The app builds and launches to an empty screen.
2. Trigger: window, home, block, reconcile, transition log. **Hand over an installable build this day;** device testing starts and runs alongside the rest.
3. Verify the six unknowns in §5 and write the findings down. Adjust §6 if needed.
4. Setup screens.
5. Status screen and block-screen copy.
6. The door, with supply, regret and refill.
7. Trial, purchase, restore, trial-ended screen.
8. Settings.
9. Accessibility pass: Dynamic Type, VoiceOver labels, both appearances.
10. Privacy policy page, store listing text, review notes (personal self-control tool; location used only for home or away; one-time purchase after the stated free nights, D78).

One pull request per step. Files small. Comments say why, never what.

## 13. Stop and ask

- Any missed or late transition in the device protocol.
- Any §5 unknown that comes back differently from what §6 assumes, especially calls and alarms during a block.
- Apple's rules ruling out the trial-then-purchase form or the location use.
- Anything on the removal list that turns out to be needed.

Otherwise decide, record it in `docs/decisions.md`, and continue.
