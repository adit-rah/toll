# Decisions and findings

MVP spec §13: "Otherwise decide, record it in `docs/decisions.md`, and continue." Newest last. **Open** marks one waiting on the founders.

## Decisions

**D1. Hollow out in place, not a fresh project** (2026-11-17). The repo, Xcode project, bundle ids, App Group, Xcode Cloud and render pipeline stay; everything in spec §2 "Out" is deleted. Family Controls (Distribution) approval is per bundle id, so a new project would mean asking Apple again. Toll's domain logic (gate, waits, sessions, blocks) is deleted, not adapted: the new rules differ enough that a clean `TollCore` is smaller than a bent one.

**D2. Minimum iOS 26.5** (2026-11-17). From 26.5 the block screen opens the app directly (`ShieldActionResponse.openParentalControlsApp`), so there is no notification route, no notification permission, and the permissions screen stays at the spec's two. Excluded: phones that cannot run iOS 26 (XS, XR).

**D3. One stacked branch per build step** (2026-11-17). `claude/sleep-s<N>-<name>`, each from the previous, one pull request each (spec §12). Merge in order.

**D4. Design foundations move to `docs/design.md`** (2026-11-17). Toll's design doc §2 carries over (spec §7). Its motion table named Toll's screens, so the table is rewritten for this product's moments under the same rules; anything not in it has no motion.

**D5. Report extension removed** (2026-11-17). Spec §2 drops insights and charts, and the trial-ended facts come from the transition log. Removing a target is the one edit to `project.pbxproj` the pivot needs; adding files still never touches it.

**D6. `TollData` stays as the app-only services package** (2026-11-17). No third-party code (spec §9): GRDB, Sentry and TelemetryDeck are gone, so the project has no remote package dependencies. It keeps the Keychain and will hold location and StoreKit, which extensions must not link.

**D7. Trial form: stated in full, starts at once** (2026-11-17; founders). Welcome states the whole deal before anything else ("Seven nights free. Then $24.99 once, or it switches off. No subscription."), and the seven nights start when setup finishes, with no store sheet. Guideline 3.1.1's documented route is a $0 non-consumable named "7-day Trial", and an app-run trial is a review risk. If review objects, the trial start moves to that item's `purchaseDate`. Only `TrialClock` changes; every screen and the night counting stay. The trial start is kept in the Keychain so a reinstall does not reset it (P-4).

**D8. Without location, the window alone decides** (2026-11-17; founders). Guideline 5.1.1(ii): "Paid functionality must not be dependent on or require a user to grant access to this data." What the purchase pays for is the app's function, not location. If location is denied, set to Approximate, or held at While Using, `homeCheck` is `windowOnly` and the block runs every night in the window wherever the user is. Always with Precise turns the home check back on. Setup's location row offers "Continue without location" after a denial; Screen Time still has no skip.

**D9. What the purchase sells** (2026-11-17; founders). Guideline 4.10 lists Screen Time APIs among things apps "may not monetize". The product is the combination: blocking tied to the sleep window and to being home, with the door. Review notes (step 10) say so.

**D10. Home uses `CLMonitor` with Always and a `CLServiceSession`** (2026-11-17). Only Always relaunches a terminated app for region events. From iOS 18, Always is effective only while the app holds a `CLServiceSession`, which can only start in the foreground and is recreated on each background launch. `startMonitoring(for:)` is marked for removal; `CLMonitor` replaces it. Region monitoring needs Precise location.

**D11. Shared state is a coordinated JSON file, not App Group defaults** (2026-11-17). The app and three extensions write it; `UserDefaults` caches per process and gives no read-modify-write across processes. `state.json` and `transitions.jsonl` in the App Group, under `NSFileCoordinator`.

**D12. During a block, time is read through a monotonic anchor** (2026-11-17). B-4 asks that a clock change never holds the block into the morning; D-7 says there is no way to end the night. Reading the wall clock alone breaks one or the other. While a block is on, "now" is the wall time at the last reconcile with the block off plus the monotonic time since, within one boot. Setting the clock back cannot hold the block past the real morning, and setting it forward cannot end it early. Outside a block the wall clock is accepted as it is. After a restart there is no anchor and the wall clock decides.

**D13. A block only starts for a night that began after the last night end seen** (2026-11-17). This covers B-4's clock and travel cases: a clock set back after the morning, or a flight west into a window that already ended, does not block again. It also means a window edited in the morning to cover the present takes effect tonight, which matches "Changes apply after tonight's block ends".

**D14. A second schedule, the sweep, starts a minute after the window ends** (2026-11-17). Its start and end each reconcile, so one missed `intervalDidEnd` does not leave the block on (B-4). The block screen's buttons also reconcile, so the first tap on a stale block lifts it.

**D15. The log records every wake, not only changes** (2026-11-17). Monitor, region and block-screen wakes are logged even when nothing changed, so late and missing callbacks show in the device protocol. Launch and foreground are logged only when they change the block. The log keeps the last 2,000 lines.

**D16. A trigger screen stands in until setup and Status exist** (2026-11-17). Step 2 must hand over an installable build. Its strings sit in `Copy.Trigger`, apart from the spec's copy. Removed in step 8 (D25).

**D17. Categories chosen for keep-open cannot be kept open** (2026-11-17; superseded by D27). `.all(except:)` takes app and site tokens only. A category picked in the keep-open picker is shown as "not kept open" for now; step 4 decides the setup wording.

**D18. Spec §6 as built** (2026-11-17, step 3). Same shape as the suggestion, with these changes: the sweep schedule after the window (D14); `CLMonitor` with an Always `CLServiceSession` in place of `startMonitoring(for:)` (D10); the window-only mode (D8); a monotonic clock anchor during a block (D12). Door activities follow in step 6. Device results may still change any of this.

**D19. Status's state line is the screen title; the gear opens the trigger screen until Settings** (2026-11-17, step 5). The state is the one question Status answers, so it takes the title position every screen shares. "You're away" shows only inside the window; away in the day says when tonight starts. A block whose end has passed is never shown as blocked. Status rereads the shared state every 20 s while open, because extensions change it.

**D20. The door's stored expiry is the end of its 15-minute interval** (2026-11-17, step 6). DeviceActivity intervals are at least 15 minutes, so the door's 5 minutes are a usage threshold inside one (spec §5). Its interval starts when the wait ends, so the interval start opens the door and the threshold closes it. If both callbacks are missed, the next reconcile after the interval end closes it (D-2). Someone who opens the app and does not use it gets up to 15 minutes, never more. The app's own timer opens the door at the end of the wait as well, in case the monitor is late.

**D21. Unlocks are spent at opening and refilled by night ends** (2026-11-17, step 6). The state keeps the number spent, the run of clean nights, the last night end counted and the last spend. A night counts when it ends, whether or not the user was home, like the trial (P-2). A spend inside it resets the run, and seven in a row return one, up to the maximum. Returning an unlock with "Lock again" (D-4) also restores the previous spend time, so that night stays clean.

**D22. The door sheet opens when "Open" was tapped on the block screen in the last two minutes** (2026-11-17, step 6). The block-screen extension records the tap and the app shows the sheet over Status. The system picker cannot be limited to one app, so anything but exactly one app is asked again ("Choose one app."). While a door is waiting or open the sheet stays up; leaving the app changes nothing (D-1).

**D23. Entitlement is worked out in every reconcile** (2026-11-17, step 7). The state holds the trial start (copied from the Keychain) and whether the purchase is owned (copied from StoreKit). Each reconcile, in the app or an extension, decides `entitled` from them, so the trial ends at the seventh night's end even with the app closed. The trial counts night ends after setup; a setup inside a window makes that night the first. The purchase is the non-consumable `com.advan.toll.full`; StoreKit's `Transaction.updates` covers Ask to Buy, refunds and other phones.

**D24. The trial-ended facts come from the log, and the block screen is counted by its taps** (2026-11-17, step 7). The system draws the block screen without telling the app, and its configuration extension may not write. So "times the block screen came up" counts taps on its buttons, the closest thing the app can see. Nights blocked at home are the distinct nights with a block turned on. Unlocks used is a running count kept with the supply, with returned unlocks taken off.

**D25. Settings replaces the trigger screen** (2026-11-17, step 8). The trigger screen (D16) is gone; the log moved to Settings. The sleep window, home and keep-open rows edit the draft: a held edit if one is waiting, else what is in force. The rows' line, "Changes apply after tonight's block ends", is always shown, as spec §7 has it. The privacy policy URL and the support address come from `Base.xcconfig` (`TOLL_PRIVACY_URL`, `TOLL_SUPPORT_EMAIL`); while empty, their rows are hidden. The founders fill them before review.

**D26. Store text and policy are drafts for the founders** (2026-11-17, step 10). `docs/app-store.md` holds the listing, the review notes, framed per D9 and D8, and the purchase's name. `docs/privacy.md` is the policy page to publish. Both say `[Name]` where the product name goes. The policy needs a support address, and its published URL goes into `TOLL_PRIVACY_URL`.

**D27. A blocklist, not "everything except"** (2026-11-18; founders). The thesis: buy back your sleep by blocking the few apps that eat it, when you are home at the time you sleep. Most apps are harmless, so the user picks what to block, and everything else stays open. This replaces spec §3's keep-open list, §5's "everything except" shielding and setup screen 5.
- **The block:** the shield names the chosen apps and sites and shields the chosen categories with `.specific`.
- **The 50-item limit:** spec §5 says iOS refuses more than 50 individual apps and sites, so setup and Settings refuse a longer list and suggest a whole category. A list cannot be emptied either.
- **The door:** it lists the blocked apps by their system names to tap. An app inside a blocked category is not on that list, so "Another app" opens the system picker for it. Its exception is `.specific(categories, except: [app])`.
- **Unknowns:** spec §5's unknowns 1 and 2 (calls, alarms, Messages) matter less now. They are blocked only if the user picks them.
- **Copy:** setup 5 reads "Which apps should be blocked at night?" / "Pick the few you lose time to. Everything else stays open."

**D28. An upgrade from Toll clears what Toll left** (2026-11-18). TestFlight testers upgrade in place, and nothing in this app would otherwise touch Toll's state. Every launch clears the following; each step does nothing once done.
- Toll's shield store (`blocks`), whose always-on blocks would otherwise stay up for good.
- Its DeviceActivity schedules (`block.*`, `session.*`, `checkin`). The monitor also stops any schedule that is not one of ours when it fires, instead of reading it as the window.
- Its App Group files (`gate-state.json`, `spool.jsonl`, `tokens.json`).
- Its `toll.sqlite` database.
- Its Keychain session token and device id.

**D29. Multiple blocks** (2026-11-19; founders, from the design canvas). Sleep plus blocks like Study, each with its own apps, place, weekly hours and days; unlocks are shared; at most 40 apps and sites across all blocks. This supersedes spec §2's "multiple places or schedules" and "insights" exclusions. The model and rules are in `docs/architecture.md`.

**D30. Layered inside the app** (2026-11-19; founders). There is no server, but the app is split like one: a pure domain, an application layer that turns commands into state and effects, ports, adapters for Apple's frameworks, and screens that read snapshots. See `docs/architecture.md`. Package names keep the Toll prefix until the name is final.

**D31. The door is 5 minutes on the clock** (2026-11-19). iOS never reports live usage, so "5 minutes of use" (D-2) could not be shown or counted down. The door's DeviceActivity interval (15 minutes, the minimum) warns at the door's minutes, which wakes the monitor on time with the app closed. That gives a real countdown, and the stored expiry stays as the fallback. Supersedes D20.

**D32. Block screen buttons follow Opal** (2026-11-19; founders). Primary "Never mind" closes; secondary "Unlock in Dusk" opens the app at the door.

**D33. Selling during the trial** (2026-11-19; founders let engineering set the direction). Never at night. During the day a quiet "Night 5 of 7 free" pill; on the last day, "Last free night tonight" opens the purchase sheet when tapped. After the trial Home stays useful and shows one card to turn it back on. P-5 is relaxed to allow exactly that.

**D34. Price $9.99 once** (2026-11-19; founders). Conversion comes first. Supersedes the spec's $24.99.

**D35. Working name Dusk** (2026-11-19; founders). Shown name, copy and docs say Dusk; bundle ids stay, to keep the Family Controls approvals.

**D36. Dark first, switchable** (2026-11-19; founders). Default dark; Settings → Appearance: Dark · Light · Match iPhone.

**D37. Without location, every block runs on its hours alone** (2026-11-19). D8 extended to all blocks: the paid function must not depend on location (5.1.1), so a block with a place behaves as if the user were there. Home says so as a fact, with "Fix in Settings".

**D38. "Try it" is dropped** (2026-11-19; founders).

**D39. Whole categories don't count toward the 40** (2026-11-20; design reply). Apple limits a shield to 50 apps and 50 sites; categories are a separate list with no such limit. The 40 counts apps plus sites across all blocks; a category shows as "Whole category".

**D40. A time window is one start-and-end pair** (2026-11-20; design reply). Days don't change the count, and blocks with the same hours share one window, because each distinct pair is one DeviceActivity window and one sweep (20 monitored at most). At 8, "New block" is off and the Hours sheet refuses a change that would make a ninth.

**D41. The door knows the app from the block screen** (2026-11-20; design reply, Door · from the block screen). "Unlock in Dusk" records which app the block screen was showing (the shield action may write to the App Group; the shield configuration may not); a site goes to the picker, since the door opens apps only. The door then opens with that app chosen: "Open for 5 minutes?", "Start the wait", "Choose a different app". Apple's picker can't be limited to one app, so picking two, or a whole category, asks again.

**D42. The privacy line** (2026-11-20; design reply, founders to confirm). Place search and the map go through Apple Maps, so "Nothing leaves your phone" is not strictly true. Settings and the purchase sheet say "No servers. We never see your data"; Onboarding-Home says "Location only tells blocks whether you're there. We never see it."

**D43. Built to the boards** (2026-11-20; founders). Screens match the canvas's spacing, sizes and positions. SF Pro replaces the boards' Inter at the same sizes, weights and line heights, without their letter spacing; Apple's controls keep Apple's shape; small phones and large text scroll with the main button pinned. Where a board can't be built as drawn, engineering says so to the design team before building something else.

**D44. Times read "10:30 pm"** (2026-11-20). The phone's 12- or 24-hour setting decides the format; English sets "am" and "pm" lowercase as the canvas does, and Home's block rows drop ":00" when both ends are whole hours ("9 am – 5 pm").

**D45. Up to 8 blocks** (2026-11-20). The canvas draws seven blocks on Blocks · 8 time windows; the time windows are the limit that bites (D40), so the block count only stops runaway lists. Was 6 (D29).

**D46. Home's This week counts Sleep nights and "Never mind" taps, and its third number is the unlocks** (2026-11-20, #44). The chart is "by night", so only lines with Sleep among the blocks on count; a day block's taps and wakes belong to Insights. The block screen's two buttons now log apart: "Never mind" is `blockScreen`, the one tap that counts as being stopped (amends D24); "Unlock in Dusk" is `doorAsked`. A night away from home or after the trial is named ("away", "off") and left out of "N of M"; a night Sleep was due at home and didn't run is a dash and counts. The latest night with data is amber: last night until tonight's block comes on. The ▲▼ change is gone from Home (trends need more weeks, so they belong in Insights). The third column, held empty for Apple's "screen time after bedtime" tile, shows "2 of 3 · unlocks left", with "One returns after N more nights without using any." under the card while one is spent (spec §7); Apple's tile gets its own row once its report extension exists. Home reads the whole log (2000 lines) instead of the newest 200.

**D48. Screen Time off is said, and the pill stays with the location card** (2026-11-20, #45). With Screen Time off for Dusk after setup, nothing can block, so Home stops claiming it: the hero reads "Screen Time off · Not blocking · Turn it on to block tonight.", the strip is dashed, "Open one app" goes, and a note card in the location card's place says "Screen Time is off for Dusk. Nothing can be blocked." with "Turn on". Turn on asks again and opens Settings if iOS doesn't show the prompt; Settings' Screen Time row does the same when off. The trial pill no longer gives way to a card: both show, the card 12 pt under the pill, so people without Always still see "Last free night tonight" (D33). The card's link reads "Change in Settings", the setup words (D37). Still for the founders: whether nights with Screen Time off count toward the free seven.

**D49. The free week is its seven nights, and it stands still** (2026-11-20, #48). The purchase sheet's "Your free week" and, after the trial, Home's card (retitled "Your free week") count the trial's seven Sleep nights only, with This week's rules (D46), so the facts on day 20 are the facts on day 8. Before, both showed the rolling week, which ran down to "0 of 7" within a week of the pause. "Unlocks used" is the unlocks kept in those nights: a door that opened while Sleep was on, less one locked again within the regret time (D-4), read from the log; it replaces "1 of 3", which was the supply. `TrialSummary`, unused, is gone. During the trial, Ask to Buy's pending sheet says the free nights continue; Settings' free nights read "Night 5 of 7", the pill's words. Still for the founders: whether away nights should count toward the seven.

## Findings for spec §5 (desk research, 2026-11-17; device checks pending)

| # | Unknown | What Apple's docs and staff say | Device check |
|---|---|---|---|
| 1 | Calls, alarms, SOS during an "everything except" block | `.all(except:)` leaves Phone, Messages, FaceTime, Maps, Clock, Settings, Find My and Health unshielded "by design" (Apple DTS, forum 793613). Alarms are system; SOS is not an app. | Pending |
| 2 | Messages blocked by default? | Reported not shieldable by `.all()`, so it stays open without being on the list. | Pending |
| 3 | Region wake within 2 min | Docs: "within 3 to 5 minutes on average", and relaunches are throttled to one per 3–5 min. Force-quit still relaunches (Apple engineer, forum 818908), with one unanswered report that iOS 26.4.2 broke it. After a reboot, nothing until first unlock. Needs network. | Pending — the spec's 2-minute pass mark is likely to fail on exit/entry latency |
| 4 | Monitor reads shared home flag at window start | — | Pending |
| 5 | Location authorization and prompts | Always required (D10). Prompt 1: "Allow While Using App" (provisional Always). Prompt 2 arrives later, when an event needs Always, usually with the app closed: "Keep Only While Using" / "Change to Always Allow". "Allow Once" blocks later Always requests. Precise required. | Pending |
| 6 | Apple's rules | Trial: D7. Location: D8. Screen Time: D9. Background location is allowed for its purpose (2.5.4, 5.1.5) with purpose strings that say what it is for. | — |

Radius: Apple says regions below 100–500 m are unreliable. `home.radiusMeters` stays 150 until device results; 200–300 m is the likely change.
