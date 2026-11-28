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

**D47. The door's dead ends** (2026-11-20, #47). Starting, cancelling or locking the door answers the ask, so the sheet closes instead of offering the same app again. The two-minute window after "Unlock in Dusk" only opens the sheet; once open it stays until answered, dismissed or the block ends. At 0 unlocks the door isn't offered (D-5): the block screen drops "Unlock in Dusk" and Home drops "Open one app". The block screen's subtitle carries the supply ("2 of 3 unlocks left.", or none left and when one returns). The door refuses an app no active block names, unless a block that's on blocks a whole category (FamilyControls can't say which apps a category holds); nothing is spent. Door-FromShield gains "Not now" under "Choose a different app" (the board's 464 pt sheet grows by one 44 pt row). "Open it from your Home Screen." sits under "Locks again at …". Still for the founders: whether a daytime unlock should reset the nightly refill.

**D48. Screen Time off is said, and the pill stays with the location card** (2026-11-20, #45). With Screen Time off for Dusk after setup, nothing can block, so Home stops claiming it: the hero reads "Screen Time off · Not blocking · Turn it on to block tonight.", the strip is dashed, "Open one app" goes, and a note card in the location card's place says "Screen Time is off for Dusk. Nothing can be blocked." with "Turn on". Turn on asks again and opens Settings if iOS doesn't show the prompt; Settings' Screen Time row does the same when off. The trial pill no longer gives way to a card: both show, the card 12 pt under the pill, so people without Always still see "Last free night tonight" (D33). The card's link reads "Change in Settings", the setup words (D37). Still for the founders: whether nights with Screen Time off count toward the free seven.

**D49. The free week is its seven nights, and it stands still** (2026-11-20, #48). The purchase sheet's "Your free week" and, after the trial, Home's card (retitled "Your free week") count the trial's seven Sleep nights only, with This week's rules (D46), so the facts on day 20 are the facts on day 8. Before, both showed the rolling week, which ran down to "0 of 7" within a week of the pause. "Unlocks used" is the unlocks kept in those nights: a door that opened while Sleep was on, less one locked again within the regret time (D-4), read from the log; it replaces "1 of 3", which was the supply. `TrialSummary`, unused, is gone. During the trial, Ask to Buy's pending sheet says the free nights continue; Settings' free nights read "Night 5 of 7", the pill's words. Still for the founders: whether away nights should count toward the seven.

**D50. Setup promises only what this phone has left** (2026-11-20, #46). Ready says "if you're home" and "At home" only with Always and Precise, the engine's rule (D37); with While Using it shows the Ready · Anywhere board, as Home will. Welcome and Ready read the trial start kept in the Keychain (P-4): a phone whose free week ran out sees "Free week used · It ended Nov 12 on this phone. $9.99 once, no subscription.", a button reading "Set up Dusk", and on Ready "The free week ended Nov 12. Blocks start after the $9.99 purchase."; a trial still running counts from its real start. Restore on Welcome no longer moves on silently: nothing found shows "No purchase found"; found, the card reads "Purchased" and Ready drops the price. "Not now" on the Always screen goes straight to the apps, since its label says the consequence; the location-off screen stays for Never and Approximate. The Permissions row says "Approximate" for approximate location. Still for design: whether Screen Time should come before the map, so the map owns the location prompt alone.

**D51. Blocks say how they really run** (2026-11-20, #49). While location isn't usable (D37), a block with a place runs on its hours wherever the user is, so its rows on Home and Blocks say "Anywhere" in place of the place's name, and the editor says under Place: "Location is set to While Using, so Study runs 9 am – 5 pm wherever you are." with "Change in Settings". A delete or edit held until the block ends (B-3) shows on its rows: "Deleted at 5:00 pm", "Changes apply at 5:00 pm". The delete sheet for a block that's on says "Study is on until 5:00 pm. It's deleted then; until then its apps stay blocked." with "Delete at 5:00 pm", and Save on any block that's on reads "Save for after 5:00 pm". Sleep's two rules read "Weeknights" and "Fri and Sat nights". "New block" names whichever limit is reached. Still for design: a name field; for the founders: whether a place-bound block other than Sleep should wait for Always instead of running everywhere, and an on/off switch per block.

**D52. The sleep model: Python in `datascience/`, a pure Swift package for the phone** (2026-11-20; founders' model spec "Dusk internal: sleep model spec"). Built as the spec lays out: a reference model, a simulator, a replay harness and an exporter in Python (`datascience/README.md`), and `ios/Packages/SleepModel`, which decodes the exported artifact, updates one person's 4 numbers a night, chooses the block start for people who opted in, and states the one insight. The weights are exported, committed and reviewed as a diff; nothing runs Python at build time. Where this differs from the spec, and why:
- **The artifact check runs in CI, not as an Xcode build phase yet.** The app doesn't link the package, and build phases live in `project.pbxproj`, which we don't edit by hand. `ios/scripts/check-model-artifact.sh` (schema and checksum, sed and shasum only) runs in `model.yml` and `ios.yml`; it becomes the build phase when the app links the package.
- **The logged chance is exact.** The spec draws one w and picks the earliest start, then estimates that start's chance from 1,000 draws. We estimate each start's chance from the 1,000 draws, mix in the 10% floor (p' = (1 − K·floor)·p + floor), and pick with one more uniform. The start is chosen with exactly the logged chance, which off-policy evaluation needs.
- **The artifact has three fields the spec doesn't:** `forgetting` (D53), `context.late_home_within_min` (60: "got home late" means home less than an hour before planned bedtime; no arrival on While Using location means not late), and `insight.zero_test_interval` (D53). The version is `sleep-model.v0`; the spec's `v3` was a placeholder.
- **The SleepModel package has its own tests**, beyond spec §11's list. They replay the Python fixtures, as the model spec's parity harness requires. On Linux they match bit for bit; CI also runs them on macOS against Apple's maths library, to 1e-9.
- **The insight's sentence isn't in the package.** It returns the numbers; the words go in `Copy.swift` when a screen shows them (CLAUDE.md: strings live there).

Still owed by the app (the spec's "App side owes the data side"): one night record per night, including `action_prob` and `model_version`; the records in the transition-log export; Apple Health access (internal doc decision 2, the founders'); linking the package, with the build phase; and keeping the records so a new base can rebuild each person's state (`SleepModel(artifact:nights:)` does the rebuild).

**D53. The model's pass criteria: what passed, and one that needs the founders** (2026-11-20). Run with 2,000 simulated people per scenario and 10,000 for safety (`datascience/reports/criteria.json`; tuning in `datascience/reports/tuning.md`).
- **Tuned v0:** σ 30, prior sd 20 on all four numbers, forgetting 0.99, floor 0.10, clip ±90 min. Every pass mark the spec can be held to holds with these values.
- **A stricter test for zero than for the range shown.** As specced, an insight shows once the 90% range is clear of zero. Checked every night, that told 22% of people in the null scenario about an effect that wasn't there; the mark is 5%. The 90% range is still what's shown, but the insight now waits until a 98% range is clear of zero (`zero_test_interval`): 2.8% in tuning, 3.7% in the full run.
- **"Median person gets an insight by night 28" can't be met** by any setting tried. About 30 minutes of night-to-night noise and roughly 20 usable nights by night 28 resolve only effects larger than about 15 minutes, and more exploration costs sleep without learning faster. CI reports this check as waived instead of failing on it. Proposed replacement, for the founders: "at least half of people whose true effect is 15 minutes or more get an insight by night 56, and no more than 5% under the null". The simulator already reports it by effect size (`figures/insights-by-effect.png`). It holds today at 56%, and CI reports it next to the spec's.
- **The plan itself is rarely chosen.** With the start's effect modelled as a straight line, a draw always favours one end (30 minutes earlier or later), so the plan wins only through the floor or a person's limits: about 22% of nights, even where the start does nothing. That costs no sleep in the simulator (null: 0.0 min), but people will see their start move most nights. If the founders want the plan to be the default until the model is sure, that is a policy change (e.g. a larger floor on 0 only), and it should be tuned here first.

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

**D54. Every night counts toward the free week; nights away or with Screen Time off are logged as what they were** (2026-11-20, #60). The founders' call: the trial isn't extended for nights that couldn't block, and the app doesn't game it either way. The app now records Screen Time access in the shared state (`screenTimeAllowed`, sent with `.permission` when what it reads changes), and every log line carries it (`Transition.screenTime`), the monitor's too once the app has seen the change. A line with Screen Time off doesn't count as Sleep running, whatever `active` says, since nothing was shielded. This week and the free week name such a night "off" (spoken "Screen Time off, nothing blocked"); it is one of the seven but not a blocked night and not a miss, so it's out of "N of M". The transition log shows "Screen Time off" on those lines. Numbered after D52–D53, which PR #59 (the sleep model) took.

**D55. The unlock economy, first pass** (2026-11-21, #61; founders, in chat). One pool of unlocks for every block, as before: a spend in a day block resets the refill run like a spend at night. Only nights Sleep actually ran count toward the refill, with Screen Time allowed: a night away, paused or with Screen Time off neither counts nor resets the run (amends D-6). The app records "Sleep ran since the last night end" (`UnlockSupply.sleepRan`), set after the night ends are counted so tonight can't credit last night; ends found together after the app slept through several credit at most the first. Unlocks carry over at purchase. The copy says "blocked nights" ("One returns after 4 more blocked nights without using any."). Still open in #61: the numbers (3, 7 nights, 5 minutes, 90 s), to be tuned with data science once the per-night record (#51) exists.

**D56. Without Always, a block tied to a place asks: run anywhere, or wait** (2026-11-21, #63; founders, in chat). Saving a block other than Sleep with a place while location isn't Always shows "Without Always location · Dusk can't tell when you're at Robarts Library. Study can run 9 am – 5 pm wherever you are, or wait until location is set to Always." with "Only at Robarts Library" and "Run anyway". The choice is `Block.onlyAtPlace`. Waiting, the block doesn't run; its rows say "Needs Always location" and "Waiting", and the editor says it waits. Once Always is granted it runs at its place either way. Sleep ignores the flag and keeps D37, so the paid core never depends on location (guideline 5.1.1).

**D57. One visual vocabulary** (2026-11-21, #72, from the wordless audit #70). One SF Symbol per concept and one concept per symbol, named in `TollSymbol` (design §2.6); every feature call site uses it. State has a glyph before its eyebrow on Home (`StateLine`) and beside its word on block rows (`StatusValue`); when nothing will block, a 64 pt glyph tile replaces "Not blocking". Unlocks show as dots under the blocked hero. "Open one app" is a button; "See all" and "New" carry a chevron and a plus; links to iOS Settings carry `arrow.up.forward.app` (`SettingsLink`). Notes carry a severity: Screen Time off is "broken" (warn triangle on `warnSoft`), While Using is "degraded" (`location.slash`). Permission states always carry a glyph. A new motion row: a pip empties or fills with a 200 ms crossfade. No new copy. The flow tickets (#74–#79) build on this.

**D58. The door reads without words** (2026-11-21, #75). The block screen's picture is the block's own symbol (a book for Study; the moon only for Sleep) over the unlocks as dots, drawn in one `UIGraphicsImageRenderer` pass from what `ShieldText` now carries (`kind`, `unlocksLeft`, `unlocksMax`); its title still says until when. Asking for the door draws the dot it would spend as a dashed ring. The wait has the `timer` glyph and a bar that fills over the 90 s; open has `lock.open` before its title and the same bar draining, with a tick where the regret time ends; the regret note uses `arrow.uturn.backward` (keep the unlock) and "Lock again" carries a lock. No unlocks left adds the refill as night ticks. No new copy.

**D59. The free week and the purchase read without words** (2026-11-21, #77). The free week is seven segments wherever it's shown: on Home's pill (the nights already ended filled, so night 2 and night 6 differ), at the top of the purchase sheet, and empty on Welcome's offer card. Buying or restoring no longer just closes the sheet: a done state appears with `checkmark.seal`, the founders' title "Every night is yours" (21 Nov, in chat), the seven segments full and "Done". Ask to Buy's pending sheet uses `person.badge.clock`. New scenario `purchase-done`.

**D60. The day strip fits any hours** (2026-11-21, founder's report). Home's strip drew a fixed 6 pm → 10 am, and returned nothing when the night didn't fit it: a Sleep block of 1:19 pm – 7:49 am, seen at 9:44 am, had no strip at all. The strip now shows the night that's on or the next one, on the boards' 6 pm → 10 am when that night fits and now is in it or the afternoon before; otherwise on a span fitted to the night and now (an hour either side, four equal whole-hour steps, at most a day). The hour labels come from the snapshot. The boards' night is unchanged.

**D61. "Open one app" is quiet** (2026-11-21, founder, in chat). The amber full-width button under the blocked hero drew more attention than the state. The door is the escape hatch: findable, not inviting. It is now a small grey capsule (`lock.open` + "Open one app", `surfaceRaised`, 32 pt, 44 pt hit area) beside the unlock dots, under the hero's line. It is still a button shape, so it passes the wordless test (design §5), but it no longer competes with the time. Amends D57's "Open one app is a button".

**D62. One record per night** (2026-11-21, #51). The app writes one line per ended Sleep night to `nights.jsonl` in the App Group, once per night, on foreground, so nights outlive the transition log's trimming. The line is the sleep model's contract 1 record exactly (`SleepModel.NightRecord`, `datascience/dusk_model/night.py`): planned and actual block times, home arrival, away all night, weekend, block-screen taps, unlocks used and returned; `policy` "fixed", offset 0, probability 1 while no model chooses the start; Health's sleep fields empty until #86. Dusk's own signals ride along under `dusk` (both readers ignore unknown keys): whether Sleep ran, "Never mind" taps and door asks apart, the last reach for a blocked app (the stand-in for sleep onset without Health, #87), paused, Screen Time off. Built from the log by `NightFacts` (TollCore, tested, and decoded as `SleepModel.NightRecord` in a test). The transition log screen can share the file, for replays. Nothing leaves the phone unless the user shares it.

**D63. Three tabs: Tonight, Your sleep, Blocks** (2026-11-21, founder, in chat). Separation of concerns, so Home doesn't overwhelm: **Tonight** is a glance (the pill, any card, the state, the unlocks and the door, the day strip; Settings stays its gear); **Your sleep** holds This week and the insights, and is where the sleep-improvement work lands (#88); **Blocks** holds every block, Sleep included, with New. The week card and the block list leave Home. Tab icons follow the symbol table (moon, chart.bar, rectangle.stack) with their names, so the bar passes the wordless test. One `DuskTabs` container drives the live app and the demo renders; scenarios name their tab and the screens pushed on it.

**D64. The tab screens use their room** (2026-11-21, founder, in chat). With the week and the blocks moved off Tonight (D63), its content sat at the top of an empty screen. Tonight is now a composition: what needs attention at the top (the bar, the free-night pill, a warning card), the state just above the middle (twice the room below as above), and the day strip at the bottom above the tab bar, like a horizon. At accessibility sizes the spacers collapse and the screen scrolls. Blocks keeps its limits pinned to the bottom, above the tab bar, with the spare room above them (the founder preferred it to moving them under the list).

**D65. Dusk is a sleep app; the lock is how it works** (2026-11-23, founder, in chat). Amends spec §1, §2, §7 and §8. Dusk sells better sleep, not app blocking. Sleep hours are the product; other blocks stay, quiet and low-friction (#89), and are no longer something setup or Home leads with.
- **The daily reason to open it is a fact about your own night.** Every morning: when the phone went down, sleep from Apple Health where there is any, and how that compares with you. One optional one-tap rating of how you slept. Once a week the card is a one-screen trend. Each touch takes under five seconds, and skipping one costs nothing: no streaks and nothing to keep up.
- **Feel good from true numbers.** Show headroom and progress against your own nights, never a shortfall. Potential comes from the person's own best nights ("you've done it before"), personal bests rather than streaks, and a bad night is neutral and forward-looking. No red and no "missed". This replaces spec §7's "no encouragement": the numbers stay facts, and a sentence may point at what they mean for you.
- **The model is behind the scenes.** The sleep model ships inside the app, so nothing about a night leaves the phone (D52). People never operate it. They see what it learned as a plain insight, and when it moves tonight's start, a short reason. Personal timing is offered once, in plain words, after the first week, needs Apple Health until the phone-only signal is validated (#87), and can be turned off at any time. Everyone else keeps the time they chose. The fixed ±30 minutes the start can move is too much: data science dampens it (smaller and rarer moves) before the app uses it.
- **Which insights, measured how.** Insights come from a ledger that says, for each one, why it matters (studies), how Dusk can measure it (Health, Dusk's own signals, Screen Time, a morning tap) and how reliably it can be measured and predicted. Only insights that are well measured and actionable ship. The ledger lives with the rest of the product research in the founders' private strategy repo.
- **Onboarding is not setup.** Onboarding is the shortest path to a first locked night. Everything else is setup, offered later, in context, when it becomes useful: home, what stays open, Health, personal timing and other blocks.
- **Understandable without words, then in plain words.** Every screen must still make sense with its text removed or in a language the user can't read (the wordless test, D57–D59). Where there are words, they say what is happening in terms anyone already uses. There are no Dusk-only terms or phrases that need learning ("door", "unlocks" as a currency, a block called "Sleep"). The user-facing name for the night's hours is chosen from the ledger's language research.
- **Calm.** Quiet colour, slow motion (design §2.5), few elements, and nothing urgent unless something is actually broken.
- **Strategy is private, the app is open.** The thesis, evidence and insights ledgers, product research and their tickets live in the founders' private strategy repo. This repo stays public so anyone can check that nothing leaves the phone.

**D66. Personal timing moves once a week and settles** (2026-11-23, founder, in chat; amends D52–D53, follows D65). For people who opt in, the model no longer picks −30, 0 or +30 minutes each night. Thompson sampling with the 0.10 floor picks a start for the week and holds it all week. When the insight shows, the start settles on the side it supports, and the insight is the reason the person sees. When the 90% range sits inside ±15 minutes, the start settles back at the person's own time. Once settled, about one week in 14 tries again. In the simulator (`datascience/reports/dampening.md`), the start changes 0.5 times a week instead of 2.7, the sleep benefit is about the same (5.6 against 5.9 min a night sooner where people differ, and better than v0 from week 5), false insights stay at 3.5%, and 52% of people with a real effect of 15 minutes or more get the insight by night 56 (v0: 58%). Smaller moves were rejected: at ±15 minutes nobody learns anything by night 56. The costs: about 5% of people with a real effect are settled back at their own time, and a held week is more exposed to weeks that differ (exams, travel), which the pilot checks; the fallback is holding for 3 nights. The model spec's learning mark becomes "half of people with an effect of 15 minutes or more get an insight by night 56". The policy goes into the reference model, a new artifact and the Swift package before the app uses personal timing.

**D67. The escape is a pause: the whole block, 10 minutes, 3 a week** (2026-11-23, founder, in chat; replaces the door's one-app unlock (spec §7 Door, D-1 to D-6) and the refill run (D55)). Dusk's distinctness is in how it's tuned for sleep (D65, D66), not in the escape, so the escape should be the simplest thing that holds. From the block screen or Tonight, "Pause" starts a 60-second wait, which costs nothing to cancel. Then every block's shield lifts for 10 minutes and comes back on its own. There are 3 pauses a week, shared by every block (D55's one pool). They come back to 3 at the start of Monday's night (nights are keyed noon to noon, so a Sunday night doesn't refill midway), and unused ones don't carry over. "Lock again" within the first 2 minutes returns the pause (D-4's regret rule, kept). No app picker, no "unlocks returning after N nights": it reads as a pause symbol, a countdown and three dots. Code keeps the spec's names (`Door`, `Unlock`); the user sees "Pause". It reuses the door's timer: a 15-minute DeviceActivity interval from the end of the wait, warning at 10 minutes (D31). Night records log pauses where they logged unlocks (D62), so the model knows a night had an open stretch. Trade-off, accepted: a pause opens everything, not one app. The cap and the wait limit it, and an escape that's too tight pushes people to switch Screen Time off, which ends every night's lock.

**D68. Onboarding is the shortest path to a first locked night; the night is called Night; Blocks stays, quieter; one heads-up before the night** (2026-11-23, founder, in chat; follows D65).
- **Onboarding:** the free-week offer → when you get up (the night shown as moon 10:30 pm – 7:00 am sun) → allow Screen Time → pick the apps → ready. No map and no location prompt. Until home is set, the night's block runs on its hours wherever the phone is, as it already does with While Using location (D37, D50), and Tonight says so plainly. "Only when I'm home" is offered after the first night, as a card on Tonight and in Settings, and leads to the map and the location prompts. This amends spec §7 Setup and B-1's "home AND inside the window" for people who haven't set home.
- **Naming:** the hours are "Night" ("Tonight", "Your nights"), shown as moon start – end sun wherever there's room. Never "sleep window", "bedtime" or "sleep hours" as the name. The block itself is no longer shown as "Sleep" to people; it's their night. `Block.sleep` and `SleepWindow` stay as code names.
- **Blocks:** the tab stays (D63) but is quieter. Onboarding and Tonight never mention other blocks, and adding one stays one tap away (#89).
- **Heads-up:** one local notification 20 minutes before each night ("Night starts in 20 min", *(config)*). Permission is asked after the first night, never in onboarding, and Settings can switch it off. No other notifications. This amends spec §2's "no notifications".

**D69. The morning card: last night's facts on Tonight and Your sleep** (2026-11-23, #103; follows D65, D68).
- **Tonight, from the end of the night until noon:** last night replaces the "starts at" hero.
  - The planned night is a moon → sun bar, filled where the block shielded. A pause (D67) or leaving home is a gap.
  - The times shown are when the block first came on and last went off.
  - "You put it down N times" counts "Never mind" taps while the night's block was on (D46), and shows only above zero.
  - The last seven nights are dots. A night that ran is filled. A night away, after the trial or with Screen Time off is a hollow dot with its glyph. A night that was due and didn't run is a plain hollow dot, never a dash or "missed". The dots replace This week's bars and dashes (D46); the counting rules stay (#44, D54).
  - A night that was due and didn't run shows no morning card: Tonight looks ahead.
- **Evening:** "8 h 30 m phone-free tonight" goes under tonight's start.
- **Your sleep:**
  - "N nights" counts every night the block ran, from the night log (D62) and the transition log together, so it never goes down.
  - This week runs Monday night to Sunday night, keyed noon to noon (D67's week).
  - "A new week" shows from the end of Sunday's night until Monday's night starts, with "N nights last week" over seven empty dots.
  - "N nights this week · Your most in a week" shows only when this week beats every earlier week.
  - The "since week 1" change and the duplicate "nights blocked since" figure are gone: one number per card, and a comparison only when it's better.
- **Symbols:** `sun.max` (the night's end), `iphone.slash` (the phone put down), `arrow.up.to.line` (a personal best).

**D70. The pause, as built** (2026-11-23, #99; details of D67).
- **The week:** weeks are keyed by Monday's night (noon to noon), so the pauses come back at noon on Monday and the app says "every Monday at noon". A supply saved before D67 starts the current week full. A clock set back to an earlier week refills nothing. A clock set forward only borrows next week's pauses.
- **Where it starts:** the block screen's second button reads "Pause in Dusk" and opens the app at the pause sheet (iOS can't start the wait from the block screen). Tonight has a quiet "Pause" capsule beside the dots (D61). With none left, the capsule is hidden.
- **What it lifts:** while a pause is open, the engine sends the shield off for every block at once; they lock again when it ends. The door no longer carries an app (`Door.app`, `ShieldPlan.doorApp` and the app picker are gone).
- **The countdown:** it keeps D58's bar. A ring would break design §2.5 ("never rings that fill").
- **Night records** keep their JSON keys (`unlocks_used`, `unlocks_returned`), so the data-science reader is unchanged; they now count pauses.
- **Open:** the trial-ended state is also called "Paused" (`pause.circle`), which clashes with the escape's "Pause" (D57: one concept per symbol). It gets renamed in the plain-language pass (D65).

**D71. Onboarding to a first night, as built** (2026-11-23, #102, #76; details of D68).
- **The steps:** Welcome → when you get up → Screen Time → the apps → Ready, with 3 counted steps.
  - **When you get up** draws the night as moon start – end sun on Tonight's strip, without a "now" marker. Turning the wheel slides the night along a fixed axis, with no motion (§2.5 has no row for it).
  - **Screen Time:** the answer is a badge on its tile: a tick, or the warning triangle.
  - **Ready:** a tick before its eyebrow, the night picture, "Anywhere" with a globe, the apps with their count, the 3 pauses as dots, and the free week as segments.
- **Until home is set:** onboarding saves the night's block with no place, so it runs on its hours wherever the phone is (D37's path). Tonight's line reads "Anywhere · starts in …". The location card shows only when a block has a place.
- **The home card:** from the first night that ends after setup, while home isn't set, nothing is blocking and the free week runs, Tonight's top status area offers one quiet card: "Only when I'm home?" with a house, "Set home ›" and "Not now".
  - Warnings take the slot first, so there is one card at a time (`TonightCard` in the snapshot).
  - "Not now" hides it for good (`dismissedCards`); Settings keeps "Only when I'm home".
  - Both open a sheet: the map → location (Always asked once) → Always or location-off.
  - Home is saved once, at the end, by `setHome`, which waits during a night (B-3). With location denied, the map offers Open Settings and Not now.
- **Existing users** with home set see no change.

**D72. The heads-up, as built** (2026-11-23, #104; details of D68).
- **What:** one local notification, "Night starts in 20 min" *(config)*, with the night's hours as its body. Banners only: no sound, no badge (D65). Nothing else is ever notified.
- **When:** for each of the coming 7 nights *(config)*, 20 minutes before the start, so each night still gets one while Dusk stays closed. The extensions can't schedule (they never import TollData), so the app schedules the week ahead. The rule is `HeadsUp` in TollCore.
  - It never sends one late.
  - A held edit (B-3) sets the hours of every night after the current one.
  - None before setup, while the night's block is off, while Screen Time is off, for a night after the free week unless bought (P-2, judged night by night), while the Settings switch is off, or while iOS hasn't allowed it.
- **Rescheduled:** after every change the app makes, on every launch and foreground, and when the app sees a change the monitor wrote.
- **Asking:** never in onboarding. From the morning after the first night, Tonight's card slot offers "A heads-up before your night?" with a bell and the time it would arrive, plus "Turn on" and "Not now".
  - Order: warnings, then home, then the heads-up, one card at a time.
  - It shows only while iOS hasn't been asked. "Not now" hides it for good.
- **Settings:** a "Heads-up" switch, on by default once allowed. After iOS has said no, the row reads "Off in iOS Settings" and opens them.
- **Symbol:** `bell`.
- **Open:**
  - A heads-up already scheduled still arrives if Screen Time is switched off or the purchase is refunded while Dusk stays closed. The next open clears it.
  - Personal timing (#98) must feed the moved start into `HeadsUp` when it lands.

**D73. Other blocks are secondary and low-friction, as built** (2026-11-23, #89 with #62 and #78; details of D68).
- **Blocks tab:**
  - The night leads as its own card: its state, moon start – end sun over Tonight's strip, and its apps and place. It is never a block called "Sleep"; its editor is "Your nights", with no name, kind or Delete.
  - Other blocks are compact rows with their kind's tile and their state as a glyph and a word. "New block" is the card's last row, one tap from the tab.
  - The limits stay pinned at the bottom (D64): apps and sites as a bar, time windows as segments.
- **Adding:**
  - "New block" shows the four kinds. Picking one opens Apple's apps picker at once.
  - The kind brings a name and default hours *(config)*: Study, Work and Other 9 am – 5 pm on weekdays (sharing one time window, D40), Gym 6 – 7 pm on weekdays.
  - The place is optional, last, and Anywhere until chosen. Save is the next tap after the apps.
- **Editing:**
  - Hours change in place on the editor, not in a sheet. A ninth window is refused there.
  - Blocks other than the night have a name (at most 24 characters, not blank) and a kind that can be changed. Name and hours follow a new kind only while they're still the old kind's defaults.
  - Editors hide the tab bar.
- **Tonight:**
  - The hero is only ever the night.
  - A day block that's on is one quiet line under it ("Study on until 5:00 pm", with a lock and its kind). While the night isn't on, that line carries the Pause capsule, since a pause lifts every block (D67).
  - The location card shows only when the night has a place and talks only about the night. A day block at a place shows "Anywhere" on Blocks and in its editor. This amends D71 and follows D68's "Tonight never mentions other blocks".
- **Wordless:** the kind's tile (the moon for the night) says which block; a lock against a clock says whether it's on; the bar and segments say how full the limits are; a dashed tile marks the row Save waits for.

**D74. Plain words on every screen** (2026-11-24; the pass D65 and D68 called for; every change, with its reason, is in `docs/copy-pass.md`).
- **The rule:** everyday words ("blocked", "open", "night", "pause") are fine. Dusk-only terms that need learning are not, and a test enforces it: `CopyTermsTests` fails on "door", "unlock", "sleep window", "sleep hours", "time window", "bedtime", "streak", "missed", "!", praise words and "most adults".
- **One word, one concept:** the free week ending is **Off**, with a power symbol, not "Paused". "Pause" is only the escape (D67, D70). "Block" is never used for a street size.
- **About the person:** "phone-free" and "you put it down", never "it stopped you". The week-against-week bars are gone because they compared whether or not it was better. The purchase sheet says "N nights phone-free", not "5 of 7".
- **The night:** "runs on its hours" is now "starts and ends at its set times". The night's block is stored as "Night", and the block screen says "This app is blocked for the night".
- **No norms:** "Most adults need 7 to 9 hours" is gone.
- **Welcome:** "Your nights, phone-free." replaces "Buy back your sleep.", an idiom that reads as paying for sleep and doesn't translate. The App Store subtitle is the founders' call (`docs/app-store.md`).
- **Limits:** "Time windows" are now "Sets of hours".


**D75. Tonight says what its times mean; the strip is the whole day** (2026-11-24, founder, in chat; with the UX audit's Tonight findings, #120; amends D33, D60, D69's evening line and D74's "phone-free").
- **Eyebrows say what the big time is:** "Apps lock at" (a later day is named: "Apps lock Monday at"), "Apps locked until", "Paused until" with "Then locked until 7:00 am", "Night ends at" with "Apps lock when you're home" while away, "Dusk is off", "Screen Time is off", "Your night". Never "Tonight" alone.
- **Quantities say what they count:** "8 h 30 m phone-free tonight" is gone. "N nights with apps locked" on the purchase sheet; "N nights locked" and "N h locked at night" on Your sleep, and the hours count only the night's block. "Never mind" taps are "You chose sleep" (founder).
- **Only what's tappable looks tappable:** the free-week pill opens the purchase sheet, with a chevron, a pressed state and a hint. There's no pill while away, while locked or with no night. Off's glyph has no tile.
- **The strip is the whole day,** wake to wake. The night is the tall amber bar with its moon; other blocks are shorter grey bars with their glyph. Solid while on, outlined before, faint once over, dashed when nothing will block. Every segment is a button of at least 44 pt (close ones share one); a tap opens a system popover with name, state, hours, apps, place and "Edit ›". Under the morning card the strip says "Tonight 10:30 pm". Setup and Blocks keep the night-only picture. The day starts at wake, so D76's gap will fit before the moon.
- **The pause stays on Tonight:** the pause sheet can be swiped away; the hero shows the paused state with "Lock again", and Pause reopens the sheet. The dots say "2 of 3 left this week".
- **No dead end:** "Nothing scheduled" offers "Set your night". At accessibility sizes the state comes before any card.

**D76. Apps lock before bed, and the gap grows with you** (2026-11-24, founder, in chat; amends spec §7 Setup, D66 and D68).
- **Terms:**
  - **Bed** is the night's start as set today (wake minus 8 h 30 m, editable).
  - **The lock** starts a gap before bed. Wake never moves.
  - On screen: "Apps lock at 10:15 pm · 15 min before bed". `CopyTermsTests` bans "bedtime" (D74), so it's "before bed".
- **The gap:** starts at 15 minutes and grows toward 60 *(config)*. The app never grows it past 60; a person may choose up to 90 by hand.
- **Weekly rule,** judged at Monday noon, with the pauses' week (D70) and personal timing's held week (D66):
  - **Smooth week** (the lock ran at least 4 nights, at most 1 pause started inside the gap, Screen Time never off): +15.
  - **Hard week** (2 or more pauses started inside the gap): −15.
  - **Screen Time switched off:** −15, and no growth for 2 weeks.
  - **Anything else:** hold.
  - After an ease, two smooth weeks in a row are needed to grow again. A pause used outside the gap never counts against anyone (D67). "Never mind" taps don't gate.
- **What people see:**
  - **Tonight:** shows the lock time and the gap.
  - **Monday:** a card says this week's gap and last week's ("Up from 15"), with one tap to keep the old one. An ease shows only the new number (D65).
  - **Settings › Before bed:** "Grows with you" (now and next), or a fixed gap from 0 to 90.
  - **The heads-up** (D72) comes 20 minutes before the lock.
- **With personal timing (D66):** the gap sets the plan. For people who opt in, personal timing still tries −30, 0 or +30 around it, held for a week.
  - If earlier helps, the gap keeps growing.
  - If the effect is small and the start settles, growth stops.
  - If later helps, the gap eases a step.
  - This stands only if the simulator shows D66's marks still hold. If not, personal timing waits until the gap settles.
- **Rollout:**
  - New installs start at 15 minutes.
  - People already using Dusk keep their night as it is (gap 0), and see one card: "Lock apps 15 min before bed?".
- **Data:** night records gain the gap and the bed time; `planned_bedtime` means bed. This is a contract change (D62), so both readers update.

**D77. The gap and personal timing share the start; learning counts people still using Dusk** (2026-11-24, founder, in chat; follows D76, #114).
- The simulator (`datascience/reports/gap.md`) found:
  - With the growing gap as the plan and personal timing testing around it, coverage, false insights and safety hold. The learning mark sits on its line: 50% of people with effects of 15 minutes or more get an insight by night 56, and 52.6% among people still using Screen Time.
  - D76's fallback, personal timing waiting for the gap to settle, is worse on every mark.
- **D76's plan stands.** The learning mark counts people still using Dusk, since leaving is the gap's cost and isn't a failure to learn.
- Coverage falls below 85% only when nearly everyone grows the gap to 60 smoothly; the pilot watches for that.
- **Follow-up:** run past 8 weeks, D66's policy alone shows false insights above 5% by week 12. Its own ticket.

**D78. The free trial is 14 nights, and its start follows the Apple ID** (2026-11-24, founder, in chat; amends D7, P-1, P-4).
- Fourteen nights free, then $9.99 once.
- The trial start stays in the Keychain, which survives deleting the app. It's also written as an iCloud Keychain item, so a new or erased phone on the same Apple ID continues the same trial; the earliest start wins.
- Nothing but the date, no Dusk server. If iCloud Keychain is off, it's unchanged.
- Built in #115.

**D79. Your sky, and landmarks** (2026-11-24, founder, in chat; amends spec §2 "share cards").
- On Your sleep, each night the lock ran lights one star, in a fixed order that completes real constellations (the Big Dipper first). Only lit stars and the lines between them are drawn. It only adds: away, off and unbought nights leave it as it was, and every night is one equal star.
- The newest star appears with a single 200 ms crossfade, a new design §2.5 row. Nothing twinkles or loops.
- Quiet landmark mornings at 7, 30, 100 and 365 nights.
- At a landmark, and only then, the sky and the number can be shared as an image made on the phone through the system share sheet. No data leaves except what the person sends.
- Delight, not a lever: no counts of what's left, no "next landmark" hint.

**D80. Before bed: three small helpers in the gap** (2026-11-24, founder, in chat; follows D76).
- During the gap before bed, and only then, Tonight has a quiet "Before bed" capsule, introduced once by a card in Tonight's slot (after warnings, home and the heads-up). It offers:
  - **write tomorrow's list, on paper:** one sheet, no typing field;
  - **breathe for 3 minutes with a soft tone, screen off:** made in the app, keeps playing when locked, then fades;
  - **a word game to play in bed with your eyes closed:** one text sheet.
- Each ends with "Put the phone down".
- Never notified, never counted, never a task, and nothing on the morning card or the sky. Settings can switch it off.
- A private flag in the night record notes that a helper was used. It's never shown to the person; it's there for the pilot (a D62 contract change).
- No meditation library and no sleep sounds.

**D81. Your sky, as built** (2026-11-24, #118; details of D79).
- **The count:** one star per night the lock ran, D69's count, now one rule (`NightsRan`) for Your sleep and the morning card. The card reads "N nights locked" (founder).
- **The stars:**
  - 150 from the Yale Bright Star Catalogue (5th revised edition, public domain), embedded as Swift data, so nothing is fetched.
  - 23 simplified stick figures. Each keeps its real shape; sizes are evened out so small figures read, and their places relative to each other are arranged, not real.
  - Lighting order: Big Dipper (7), Cassiopeia, Little Dipper, Orion (30) … Pegasus (100) … Draco (150).
- **Past 150:** nights light the stars again, each pass a little brighter, so every night still adds.
- **The card:** a dark sky in both appearances, running to the card's edges above the moon and number. It frames the lit stars and widens as it fills.
- **The newest star:** accent, from the morning until the next night starts. It crossfades in 200 ms once, the first time Your sleep shows it (design §2.5).
- **Landmarks** at 7, 30, 100 and 365 *(config)*. The morning card shows the completed shape, "30 nights. Orion is in your sky." and share. The shared image (`ImageRenderer`, `ShareLink`) is the sky, the moon and "N nights locked", and nothing else.
- **VoiceOver:** "Your sky. 23 nights locked. 3 constellations."

**D82. The 14 free nights, as built** (2026-11-24, #115; details of D78).
- **Two rows of seven:** the free nights are drawn as segments, one row per week, on Welcome, Ready, the pill and the purchase sheet. Tonight's segment is an accent outline, so the drawing matches "Night 5 of 14" without words, and the purchase sheet's segments tell VoiceOver the same. After the trial, Your sleep shows the frozen free nights as two rows of seven dots.
- **"Free nights", not "free week":** "14 nights free", "Start my free nights", "Free nights used", "Your free nights ended …", "Your free nights", Settings' "Free nights". The trial counts nights, and a night that skips days takes longer than two weeks. Code names (`FreeWeek`) are unchanged for now.
- **The trial start is kept twice:** in the phone's Keychain and as an iCloud Keychain item (`kSecAttrSynchronizable`, after first unlock). At setup, launch and foreground the earliest wins and is copied to whichever is missing or later, so a phone that started before this change gets its iCloud copy, and a new phone that finished setup before the copy arrived takes the earlier date. With iCloud Keychain off, nothing changes. The privacy label stays "Data Not Collected".
- The free nights are looked for `7 × (nights + 1)` days ahead, so a night that runs once a week still reaches its 14th.

**D83. The gap before bed, as built** (2026-11-24, #113; details of D76 and D77).
- **The hours:** the night stores bed → wake. Every rule about when it's on, the DeviceActivity schedule and the heads-up use bed minus the gap; a lock before midnight starts on the day before. Blocks and the night picture keep bed. Personal timing (#98) moves bed; the lock stays bed minus the gap.
- **The week:** judged at the first reconcile on or after Monday noon (the pauses' week, D70), with `datascience/sim/gap_rule.py`'s rule. Facts are kept as they happen: nights the lock ran, pauses asked for before bed, Screen Time seen off. Weeks nothing woke through hold; at most 8 are judged.
- **Changes:** from Settings › Before bed, Monday's "Keep" or the offer, a change applies at once unless the night is on; then it applies when the night ends (B-3). A fixed gap is never judged.
- **Installs:** new ones start at 15, growing. Existing ones start at 0, fixed, with one Tonight card: "Lock apps 15 min before bed?".
- **Records:** `planned_bedtime` is bed; `bed` and `gap_min` are added. Older records read as gap 0.
- **Words and pictures:** the hero adds "15 min before bed" under "Apps lock at"; the heads-up is "Apps lock in 20 min"; Ready's title is "Apps lock at 10:15 pm tonight."; Monday's card is "This week, apps lock 30 min before bed · Up from 15" with "Keep 15". The strip draws the gap as a lower step before the moon, at least 8 pt wide, so it reads without colour. The glyph is `moon.haze`.
- **Open (#127):** if Dusk isn't opened between Monday noon and Monday's lock, that night's schedule and heads-up still use last week's gap.

**D84. The audit outside Tonight** (2026-11-24, #121; findings in `docs/ux-audit-2026-11.md`).
- **Your sleep counts every night:** 7 days, 30 days and All time read the night records (D62) merged with the transition log's nights not yet recorded, a record winning. Night records gain `dusk.locked_min` (the night's block shielding, pauses left out) and `dusk.taps` (each "Never mind"); the model's readers ignore them, so the D62 contract holds. Older records fall back to block end − block start. The chart spans the night's own hours and has a spoken summary; it is hidden when a range has no taps.
- **One home picker:** the map, reached from Tonight, Settings and the night editor's Place row. Once home is set it offers "Use anywhere" (`Command.useAnywhere`), held during the night like any edit (B-3); Settings' row shows the held change as "On/Off from 7:00 am".
- **Sheets pin their actions** under scrolling content at every size (design §2.1): the pause sheet's "Lock again", the purchase sheet's "Keep it". After the 2-minute window the pause sheet says "This pause is used. Locking ends it early."
- **The block screen** offers "Open Dusk to pause", titles every block "Blocked until …", says "This site" for a website, and with none left reads "No pauses left. They come back Monday."
- **Settings:** "Last night · Mon 10:30 pm – 7:00 am" is the night's own; restore says "Purchase restored."; the Blocks row is gone (Blocks is a tab); links that leave the app have the leave glyph; a version line sits at the bottom.
- **One sentence for the pause everywhere:** "A pause opens blocked apps for 10 minutes."
- **The purchase sheet** hides stats at 0 and drops "pauses used".

**D85. Before bed's helpers, as built** (2026-11-24, #119; details of D80).
- **Where:** a grey "Before bed" capsule (`moon.haze`) under the pauses on Tonight, only while the night is locked and not paused, before bed, with the helpers on. One card introduces it: "Something for the next N minutes?", where N is the minutes left until bed, with "Show me" and "Not now". Answering the card or opening the capsule puts it away. In the gap it comes after any warning; other offers never show while apps are locked.
- **Settings:** no second row. Settings › Before bed's sheet holds the helpers' switch (on by default) and the tone's length (3 min, 1–10) under the gap. They apply at once; B-3 doesn't apply to them.
- **The sheet:** "Pick one. Each ends with the phone down." Write tomorrow's list (pencil), Breathe for 3 minutes (`wind`), Try this in bed (`eye.half.closed`). Each page has "Done" and "Something else". Pages swap without motion and keep one height.
- **The tone:** a sine made on the phone with AVAudioEngine, 196 to 262 Hz, 4.5 s up and 5.5 s down, in over 3 s and fading over the last 15 s. It plays like a timer: through the silent switch and with the screen locked (the background audio mode, `ios/Config/App-Info.plist`; review note in `docs/app-store.md`), pausing other audio until it ends. A call, an alarm or headphones coming out end it. No visual pacer.
- **Records:** `helper` names the last helper opened that night ("list", "breathe", "words") or is null; older records read as none. Nothing shows or counts it.

**D86. Tonight's cards float; a card never moves the state** (2026-11-24, founder feedback).
- **The layout** (below accessibility sizes): Tonight is laid out as if there were no card. The bar is at the top. The state sits a little above centre, with a third of the free room above it and two thirds below. The strip is at the bottom.
- **The pill:** the free-night pill sits centred in the bar, beside the gear. It drops its segments before it would crowd the gear, so it appearing or ending moves nothing.
- **The card:** a card or note (Screen Time off, location, Tonight's card) shows one at a time, in that order. It goes where it fits without touching the state, its pauses, the Before bed capsule or the strip:
  1. 20 pt above the strip;
  2. else 4 pt under the bar;
  3. else 20 pt under the state block. The strip then moves down and the screen scrolls, while the state stays put.
- **Not a popup:** no scrim, dimming, blur or extra shadow, and nothing is modal. A card arrives and leaves with a 200 ms fade in place (design §2.5).
- **At accessibility sizes nothing changes:** one scrolling column with the state, then the pill and card, then the strip.
- **VoiceOver** reads the bar, the state, the card, then the strip.
- **Replaces** D48's "the card 12 pt under the pill" below accessibility sizes. D48 still holds at accessibility sizes.
- **Not changed:** the block editor's note for a running block still pushes the editor down when it appears (#133).

**D87. Steady screens: a state change never moves what's above or beside it** (2026-11-25, founder feedback, #133). D86's rule for Tonight holds on every screen. It was checked by comparing frames in `ui.json` for each pair of states.
- **The block editor:** the note for a block that's on ("Study is on until 5:00 pm.") sits at the top of the pinned bar, above Delete and Save. When a block comes on mid-edit, the bar grows upward while the card, Delete and Save stay put. The note fades 200 ms in place (design §2.5, "A card or note arrives or leaves").
- **Sheets keep one height through a flow.** The pause sheet's choosing, waiting and open states share the tallest height (470); "none left" keeps 390. The purchase sheet's outcomes reached from the offer keep the offer's 674, so a short outcome sits in a tall, quiet sheet. "Nothing to restore", opened from Settings, keeps 374.
- **A button keeps its line when a quiet link comes or goes.** The pause sheet keeps the link's room, empty, under Cancel and Lock again. On Before bed's breathe page, the tone's line under Stop is the height of a link.
- **A passing line goes below what stays:** the map's "Finding where you are" sits under the privacy line.
- **Welcome scrolls at accessibility sizes,** with its button pinned (design §2.1).
- **Not changed** (#135): after buying, the outcome's button sits on the standard line, 46 pt below "Keep it"; the map's button lifts 28 pt when location is denied and "Not now" appears. Standard list rows expanding in Settings, and the system sheet's own motion, are out of scope.

**D88. Your sky, seen through** (2026-11-25, founder, in chat; details of D79 and D81; replaces D81's "The card" and "The newest star").
- **Full bleed:** Your sleep opens onto the sky, edge to edge under the status bar, filling 45% of the screen at every text size. "Your sleep" and last night's moon sit on it; "N nights locked" sits on the land just under it. The land is a fixed, abstract hill in the page's `bg`, with a fainter ridge behind. The sky is the same night in both appearances; only the land follows light or dark. Its bar is see-through over the sky and takes the page's colour once the sky has scrolled away.
- **Light:** one of three fixed palettes, chosen by the phone's hour when the screen opens: evening from 4 pm, night from 9 pm, morning from 5 am (`TollConfig.sky`). Evening has a low amber glow behind the hills, night almost none, morning a cool blue-grey. Nothing moves between them. The colours are `SkyColor` tokens (design).
- **Atmosphere:** a fixed, seeded dust and a soft Milky Way. They are not catalogue stars; unlit stars are still never drawn, so the sky never shows what's left.
- **True details:**
  - Stars are sized by magnitude and tinted subtly (38%) by their real B–V colour, from BSC5, added for all 150.
  - Last night's moon phase comes from the mean synodic month, worked out on the phone, and is lit on the correct side for the night's place (north by default).
  - A completed figure's name sits in small capitals beside it, and is left off where it would cover another name or a star (#137 for contrast).
- **Every star is a night:** a tap within 22 pt of a lit star opens a system popover with that night's date and "Locked 10:15 pm – 7:00 am"; past 150 stars, it shows the latest night for that star. VoiceOver keeps the sky as one element and names the completed constellations: "Your sky. 30 nights locked. 4 constellations: the Big Dipper, Cassiopeia, the Little Dipper, Orion."
- **Empty sky:** dust, Milky Way, moon and land, with "Your first star comes with your first locked night."
- **The newest star** brightens over 450 ms, then its lines draw from the star they join over 450 ms, once. With Reduce Motion it is a 200 ms crossfade (design §2.5).
- **One renderer** (`SkyScene`) draws:
  - Your sleep;
  - the landmark tile;
  - the 1080 × 1920 share poster: evening sky over dark land, moon, named figures, "N nights locked", the date and a small wordmark. It is still shared only on landmarks.

**D89. Your sky's names, faint until asked** (2026-11-25, founder, in chat; #137 item 1; details of D88).
- **Faint by default.** Names and figure lines stay faint (`line`, the dark `label3`), so the sky reads as a sky. Faint names are decorative chart labels and are the one exception to the 4.5:1 text rule. VoiceOver says every name, and a tap shows them legibly.
- **A tap on the open sky** (not within 22 pt of a lit star) brightens every name to `nameBright` and every line to `lineBright`; another tap fades them. The change is a 200 ms crossfade (design §2.5).
  - `nameBright` is the dark `label`, at least 4.5:1 in every light. The worst measured is 5.2:1 at a placed name, and 4.5:1 just above the land in the morning.
  - `lineBright` is the dark `label2`.
- **Tapping a star:** while that star's night is open, its figure's lines and name brighten the same way and the rest stay as they are. An incomplete figure has no name, so only its lit lines brighten. A line belongs to the figure that draws it.
- **Nothing is kept.** The sky is faint again whenever Your sleep disappears or the app goes to the background. No timer, pulse or glow dims anything on its own.
- **The empty sky** has nothing to brighten, so a tap does nothing.
- **VoiceOver:** the sky stays one element. Its hint is "Double-tap to show the names." ("Double-tap to fade the names." once they're shown); double-tap does what a tap on the open sky does.
- **Names never sit on the land.**
- **The rule** is `SkyFocus` in TollCore, tested.

**D90. Every flow is charted in `docs/flows/`** (2026-11-25, founder, in chat).
- **One Mermaid chart per flow, as built.** Each screen names its render scenario, each state check appears in the code's order, and iOS's own UI is drawn apart, so a UX audit can pair a chart with its renders.
- **`docs/flows/data.md`** lists every store Dusk keeps on the phone, with its format, version, writers and readers, and what a format change does to it.
- **A PR that changes a flow updates its chart.** The README's table says which source folders each chart covers. There is no CI check.
- **Found while charting:**
  - An unreadable state file resets the person to Welcome, and the next wake overwrites it (`data.md`, risk 1). This and the other storage risks are fixed in #140, before any new stored field or enum case.
  - Flow doubts are in #141.

**D91. Last night's card is for review, not the hero** (2026-11-25, founder, in chat; amends D69, D75 and D86).
- **Tonight's hero shows the coming night all day** ("Apps lock at …"), so Tonight keeps one look.
- **When last night is kept:** from its end until the next lock starts, when the night ran, was away, or had Screen Time off.
- **Each morning until noon,** last night floats as Tonight's card in D86's band:
  - It comes after the Screen Time and location notes and before the offers.
  - It shows even while another block is on.
  - A quiet "OK" puts it away for that night only.
- **All day,** last night sits at the strip's start as a faint amber stub with its moon. A tap opens the same card in the strip's popover, a sheet at accessibility sizes.
- **The card says what each part is:**
  - "Last night";
  - "Apps locked from 10:15 pm to 7:00 am", over a moon → sun bar;
  - "Apps open from … to …" where the bar breaks;
  - "You chose sleep over a locked app N times";
  - "Last 7 nights" (or "Your first 7 nights") over the dots, which are the seven nights up to last night;
  - on landmark mornings, the landmark and Share inside it.
- **Removed:** D75's "Tonight 10:30 pm" over the strip (the hero says it), and D69's "replaces the starts-at hero".

**D92. Data on the phone changes safely** (2026-11-25, #140, after D90; reviewed independently before merge). Dusk never loses a person to a format.
- **Reading is lossy.** A missing key takes its default, an unknown enum value takes its safe fallback, and an element that can't be read is dropped alone.
- **A bad file is never written over:**
  - A file that can't be opened (before first unlock) is never written, and nothing runs.
  - One that can't be parsed is kept aside (`state.unreadable-*`). The night comes back from the latest night record, and Tonight shows one note, "Dusk couldn't read its settings and kept your night. Choose your apps again.", until the apps are chosen.
  - One read in part, or at another schema, is kept before the first write over it.
- **`state.json` carries `schema`, `minReader` and `writtenBy`:**
  - The schema is raised on every change of shape or meaning.
  - A file without `minReader` is read as schema 2, whatever its label, because builds before this one rewrote files without changing the label.
  - A build below `minReader` applies no command, follows the file for the shield, logs nothing, and Tonight says "This version of Dusk can't save changes. Update it in TestFlight."
  - Migrations are steps on the JSON as written. Each has a fixture made by its own build's encoder, kept forever. Changes expand, then contract.
- **The night log is append-only,** with `record` and `rev`:
  - A correction is a new line, and every reader takes the highest `rev`.
  - `model_version` is the artifact this build carries (`BundledModel.version`).
  - Nights are recorded before the log is trimmed: by the monitor at each sweep, and by the app on opening. A night that can't be written keeps the log untrimmed.
- **`model.json` is a cache,** rebuilt from the night log whenever the artifact changes. Swift and Python share a rebuild fixture.
- **The Keychain trial start's format is frozen:**
  - Only "not found" means there's no start; any other answer is unknown, and nothing is written that pass.
  - An unreadable value counts as a start no later than when it was written, and is never written over.
- **One-time flows** exist only for what a person must decide. They live in a registry in TollCore, show at a calm moment and at most one a day, and take safe defaults after the third "Not now". None are registered yet.
- **Trade-off, accepted:** a build below a file's `minReader` can't save edits or pauses until it's updated. That only happens on TestFlight.

**D93. Last night folds to one row each morning** (2026-11-25, founder, in chat; amends D91).
- **Folded by default.** Each morning until noon, last night sits in D86's band as one quiet row on the card surface: one line of body text, with 12 pt above and below. The row holds:
  - the moon and "Last night";
  - the night's outcome as a glyph and words:
    - `lock` "Locked 8 h 45 m": the minutes apps were locked, leaving out breaks;
    - `figure.walk` "Away, nothing locked";
    - `hourglass` "Screen Time was off";
    - on a landmark morning, the landmark's line in place of the length;
  - `chevron.down`.
- **One button.** The whole row opens the full D91 card, which grows up from the row with its bottom edge kept 20 pt above the strip. The open header ("Last night", "OK", `chevron.up`) folds it again.
- **When the open card doesn't fit** above the strip, it sits under the state and the screen scrolls. It never goes under the bar, and the state never moves.
- **Never kept.** It is folded each time Tonight appears and when the app goes to the background.
- **"OK" is only in the open card.** The folded row is quiet enough to stay until noon.
- **The strip's popover** still opens the full card.
- **VoiceOver:**
  - One button: "Last night, apps locked 8 hours 45 minutes", plus the landmark's line on a landmark morning.
  - Its value is "Collapsed" or "Expanded".
  - Its hint is "Double-tap to show last night.".
- **Motion** (design §2.5): it grows over 300 ms and its content fades in after the first 100 ms. With Reduce Motion, a 200 ms crossfade.
- **The rule** is `Morning.status` and `statusSpoken` in TollCore, tested.

**D94. Tonight's band is one designed system** (2026-11-25, founder feedback; amends D86, D91 and D93).
- **Kinds, each with its time:**
  - **Problems** show at any time until fixed. They are: Screen Time off, a build that can't save, a night without its apps, and location short of Always.
  - **Night cards:** Before bed's card shows only in the gap. Monday's card shows from Monday noon until Tuesday noon, while nothing is locked.
  - **A one-time flow, then setup offers** (home, then the heads-up, then the gap offer). These show only at calm times:
    - nothing is locked;
    - free nights are left, or Dusk is bought;
    - it is not during the night, and not within `band.nightMinutes` (60) of the lock.

    Offers also need a night to have ended since setup.
  - **Last night's row** shows from wake until noon, until OK, and never in the hour before the lock.
- **One card, by kind:** a problem first, then a night card, then a flow, then a setup offer. Last night's folded row may sit under the card, nearest the strip. There are never more than two items.
- **The hour before the lock belongs to the night.**
  - Before the gap: at most Monday's card.
  - In the gap: Before bed's card, or nothing.
  - Offers and flows wait for tomorrow.
- **Opening:** last night opens upward. While it is open, a card above it fades out in place over 200 ms, and comes back when it folds. Nothing is pushed into the state or covered.
- **The chevrons follow the motion:** the folded row shows `chevron.up` and the open header `chevron.down`.
- **Amends D91:** last night's row no longer waits behind the location, lost-apps or can't-save notes; it sits under them. With Screen Time off, last night still isn't shown.
- **Amends D86:** "one at a time" becomes one card plus last night's row.
- **The heads-up offer is a setup offer.** It asks once, and in the last hour it would describe tomorrow's heads-up.
- **The rule** is `TonightBand` in TollCore, tested. It is charted in `docs/flows/tonight.md`.

**D95. Easy on the eyes, text still strong** (2026-11-25, founder feedback; eye-comfort audit, with research in the founders' private ledger).
- **Dark stays the default (D36).** If someone chooses Light or Match iPhone, that choice stands; the app never forces dark over Light.
- **Light mode is warm paper.** The page is `#EDEAE4` and cards are `#E6E3DC`, both near 80% luminance, and nothing is pure white.
  - Cards are never brighter than the page. A step of tone and a one-pixel `separator` hairline (`tollSurface`) set them apart.
  - Sheets use the card colour.
  - Near-white fell from 39–89% of light screens to 0–3%; what's left is Apple's glass tab bar.
- **Dark mode is a warm near-black** (`#131210`), with the same contrast as before.
- **Text stays strong.** Body text is 13:1 or more on every surface, and never under 7:1. Secondary text is 5.4:1 or more, in both appearances. Increase Contrast goes further.
- **`label3` is for marks, never words.** Disabled titles, footnotes and headers use `label2`. The sky's faint names (D89) are the exception.
- **No large white areas:**
  - Apple's segmented control takes `chosen` instead of white.
  - The launch screen is the dark page.
  - The app asks for the reading white point (`UIWhitePointAdaptivityStyleReading`).
  - The shield and the system accent follow the palette.
- **The warm palette is a choice of look,** with no claim about sleep.

**D96. Motion is critically damped springs, scoped to what changes** (2026-11-25, founder: "smooth, premium-grade" motion).
- **Curves.** Every animation is a no-bounce spring (`.smooth`) at design §2.5's durations (200, 300, 450 ms). It starts at once and never overshoots, and a tap mid-way retargets it instead of restarting it.
- **Scoping.** Each animation is scoped with `value:` (or `animation(_:body:)`) to the view whose value changes. Tonight's state never animates with the band (D86).
- **Last night's card is one surface** whose height animates, with its content clipped to it. The header rides the top edge. What differs between the row and the open card only fades: in after the first 100 ms, out at once. Nothing lands before its container and nothing reflows. A card above it fades in place and never moves.
- **Amends D93/D94:** the chevron is one glyph turned half a turn on the card's curve, not a swap from `chevron.up` to `chevron.down`. With Reduce Motion it crossfades.
- **Sheet pages** (the door's states, Before bed, Purchase's outcome) swap in place inside a container that stays: the old out at once, the new in after 100 ms, 300 ms in all (`Motion.pageSwap`). A `Group` hands its transition to each new page, and that page can't animate its own arrival, so pages popped.
- **Renders can film an interaction** (`motion` lines, `motion.mp4`, `ios/scripts/motion-strip.sh`; `docs/renders.md`). The simulator shows continuity, not frame rate, haptics or a tap mid-animation; those are device rows 177–186.
- **Left open:** Setup's progress bar slides with each push (for the onboarding rewrite, #144); the pause bar steps once a second; below AX sizes, an open card that doesn't fit above the strip moves the band under the state (row 179).

**D97. Onboarding fitted to the person's sleep, as built** (2026-11-25, #144, founder; amends D68, D71, D76 and D83; follows D92).
- **The night is three parts.** The night's block stores the person's sleep, bed (falling asleep) to wake. The lock is the buffer before sleep, sleep, and the buffer after waking: it starts at bed minus the buffer before and ends at wake plus the buffer after. Every rule about when the night is on, the DeviceActivity schedule, the heads-up and the night records use the lock; the night picture, the strip's snippet and Health compare with sleep.
- **Two buffers, one rule.** Before sleep is D76's gap; after waking is new. Each has a start, a target and a mode (grows or fixed); a start of 0 is none. D76's weekly rule judges both sides at Monday noon, +15 a smooth week, −15 a hard one, never past that side's target. A pause counts against the buffer it was asked in; one asked while asleep counts against nobody. When both sides changed the same Monday, the card names both in one line; "Keep last week's" puts back every side that grew.
- **Defaults (founder):** before sleep starts at 30 and grows to 60 for everyone; a person may start lower, and choose up to 90 by hand. After waking is on, starts at 15 and grows to 30, and can be set to 0; its words claim no more than a calmer start to the morning.
- **No per-person buffer targets at onboarding.** Health can't give the time to fall asleep (no reliable in-bed → asleep), and how much nights vary needs about six weeks. "Recommended to start" means the baseline; the sleep times are fitted, the buffers aren't. #145 personalises them later from Dusk's own nights.
- **Onboarding** (amends D68 and D71): Welcome ("Start my 14 free nights", then quieter "Buy it now · $9.99", then Restore; bought or cancelled, setup goes on) → Fit Dusk to your sleep (Use Apple Health / Set my hours myself) → Your sleep (found or asked, the same screen) → The time around your sleep → Screen Time → the apps → Ready. Five counted steps. Health is asked for where it's used, reversing D68's "Health later".
- **Health** reads `sleepAnalysis` only, never writes, keeps nothing off the phone. One source per night (a watch first, else the one with the most sleep). Usual times are the circular median of the last 28 days, with at least 7 nights, rounded to 5 minutes. Fri and Sat nights are set apart only with 3 or more of them and when either median differs by 45 minutes or more. A refusal reads as no nights; so does an iPhone without a watch (iOS 18 writes no sleep alone), so most people without a watch are asked, and the screen says plainly that Health had too few nights.
- **Data** (D92): schema 4, minReader 4: `gap.target`, `after`, `health`. Step 3 → 4 keeps every person's night as it was (sleep is their stored hours, before is their gap with D76's 60 as its target, after is none) and marks one-time flow #1 as owed. Night records are format 3: `after_min`; `bed`/`planned_bedtime` and `planned_wake` are planned sleep; Health's sleep arrives a day later as a `rev` correction, for people who chose Health.
- **One-time flow #1, "Fit Dusk to your sleep"** (`fit-sleep`, version 1): for people set up before this build. Tonight's band's one-time flow kind (D94), at calm times only; once shown it stays offered all that day until answered or "Not now", and never shows in the band's hour before the lock; its sheet runs onboarding's steps 2–4 from their own night, with the same defaults, keeping their gap if it's already 30 or more. "Not now" keeps their night; the third leaves it so for good.
- **Settings › Sleep** replaces Settings › Before bed: the hours, each buffer growing (tonight, grows to) or fixed, and the helpers. Save applies them in one change; hours and minutes wait for the night's end (B-3), targets and helpers apply at once.
- **Words and pictures:** "before bed" reads "before sleep" (Tonight's line, Monday's card, the offer, the helpers' capsule and sheet). The strip, last night's card, Ready, Settings and Your sleep draw before, sleep and after as three parts by height and place, never colour alone. New glyphs: `sun.haze` (after waking), `lock.open` (apps open again), `heart.text.square` (Apple Health).
- **Trade-off, accepted:** a TestFlight build from before this one can't save over a schema 4 file (D92's read-only), so a downgrade keeps the night but freezes edits until updated.
- **Setup's progress** sits in one fixed bar over each flow's navigation stack (onboarding, flow #1's sheet, set-home), so pages slide under it; a pushed step fills once the push has landed (D96, design §2.5's "Setup step push").
- **Open:** HealthKit must be enabled on the App ID before this merges, or Xcode Cloud can't sign the release (#86).

**D98. Nothing asks for a permission before its screen** (2026-11-27, founder's TestFlight report: "the app instantly asked for permissions rather than waiting for the specific scene"). Every launch opened the place watch, with a `CLServiceSession` asking for Always and the `CLMonitor` (D10), before any screen. On a fresh install iOS takes that session as a request, so the location prompt appeared over Welcome. The watch now opens only once Dusk has Always, at launch or the moment it is given, and the monitor is synced only while it is open. Below Always, region events can't reach a closed app and blocks run on their hours (D37), so nothing is lost. Screen Time, notifications and Health were already asked only from their own screens. Device row 202.

**D99. Model v1: personal timing holds a week, and the zero test holds for as long as Dusk is used** (2026-11-27, #98, #117; details of D66).
- **The week.** `sleep-model.v1` (schema 2) holds a start Monday to Sunday by night date, drawn by Thompson sampling with the 0.10 floor. Each week it settles on the insight's side, or at the plan once the 90% range is inside ±15; settled people explore in 7% of weeks. Settling is checked afresh each week, and only at week boundaries. A held start that stops being allowed is redrawn that night.
- **Logging.** Every night of a hold logs the chance of its draw, plus `policy` "held", `hold_start` and `settled`; the latest record gives the hold back after a rebuild (D92).
- **False insights stay under 5% for a year.** Past 30 usable nights, a new insight needs a zero test whose miss chance shrinks as 0.02·(30/n)²; an insight already showing keeps the 98% test. Null people shown a false insight within a year: 3.8% (3.1–5.0% over six runs), against 9.8% with the fixed test. The D66 learning mark stays at 52%. The cost is later insights for real effects (43% against 62% of "differ" people within a year).
- **Not fixed:** when a person's usual time wanders or drifts, false insights reach about 12% in a year, because the model treats each night's noise as independent. The model's intercept needs to wander too (#154).
- **Not on the phone yet.** SleepModel's API gains `Hold`, `chooseStart` and `PersonState.shown` (source-compatible), but the app doesn't choose starts with it, and records still say "fixed" (#155). Old `model.json` caches rebuild because the artifact changed.
- **Assumed, for the founders:** spending starts at 30 usable nights (40 keeps slightly more learning, 53.8% against 52.2%, but lets 4.5–5.9% false insights through in a year).

**D100. Monday's change applies with Dusk closed** (2026-11-27, #127; closes D83's open point).
- **A noon wake.** The monitor wakes every day from 12:01 to 12:16 (`t.1201-1216`, `WeekTurn`). Every saved reconcile asks for it while either buffer grows (D97), and stops it when both are fixed. Its start and end both reconcile, so the end is a second chance after a restart before the first unlock.
- **On Monday** the wake judges the week (D76, D97), so the DeviceActivity schedule moves to the new lock that afternoon: earlier after a growth, later after an ease. When a buffer changed and iOS allows notifications, the monitor replaces that night's heads-ups (`HeadsUpNotifications` in TollScreenTime, UserNotifications only, waiting at most 2 s for iOS). Other days' wakes change nothing but log `weekTurn`.
- **Chosen over scheduling both outcomes ahead:** one activity (18 of the 20 at most), nothing to withdraw, and the same judgement every reconcile already runs. Daily rather than weekly, because a repeating hour-and-minute schedule is the form already checked on device.
- **Trade-off, accepted:** `weekTurn` is a new transition cause, so a build from before it drops those noon lines, which almost never carry a night's change.
- **Settings › How it works** says the rule, and every number in it comes from `TollConfig` (#52).
- **Assumed, for the founders:** the App Store subtitle is "Your nights, phone-free", matching Welcome (the alternative is "Buy back your sleep"). The review notes' Apple guideline numbers are to be checked before submitting.
- **Amends D98:** a demo launch never opens the place watch; its simulated Always opened the real one, and iOS prompted over the renders.

**D101. Buffer targets fitted from the person's own weeks** (2026-11-27, #145, #61; follows D76, D97).
- **The rule** (`BufferSuggestion`, TollCore, with a Python reference and 323 parity cases in `datascience/economy/`). Each side reads its last 12 weeks from the night records, judged as Monday judges them (Screen Time off counts as hard). With fewer than 4 judged weeks the target is the baseline (60 before sleep, 30 after waking), so onboarding always offers the baseline. Otherwise the target is one step below the lowest level the person found hard at least as often as smooth (above their comfortable level), never below that level and never above the baseline.
- **Past 60, only on Health's sign.** Before sleep can go one step past the person's level only after 3 smooth weeks there with no pause in the buffer, and when Health shows sleep starting 20 minutes or more after planned sleep (median of 14 or more lock nights). Bounds: 30–90 before, 15–30 after. Personal timing must not try −30 while the buffer is above 60 (#155).
- **Where it shows.** Only one-time flow #1 offers it, with "Fitted to your nights so far." Monday's growth rule and Settings › Sleep are unchanged.
- **Records.** Night records gain `dusk.pauses_before`, `dusk.pauses_after`, `dusk.waits` and `dusk.waits_cancelled`, without a format raise; older records don't count.
- **In the simulator** (`datascience/reports/buffers.md`), every D66 mark matches D97's baseline. Dropout falls from 17.1% to 16.1% at 8 weeks and from 22.1% to 19.7% at 12. The D66 learning mark is 47.1%, below 50% because of D97's start of 30 (49.8% with a start of 15), not the fit.
- **#61, the pause numbers: no change until real records exist** (`datascience/reports/pauses.md`). Pause length barely matters, and a cap of one a night is worse. Whether more pauses would help depends on whether more on offer creates more wants, which is unmeasured. About 75 people for 12 weeks pins the share of weeks that run out to ±5 points. Telling whether running out leads to Screen Time going off needs a randomised 3-against-4 test.
- **Assumed, for the founders:** fitted targets only through the flow (refitting every Monday is safe in the simulator); the raise past 60 is kept, gated on Health; the buffer after waking never exceeds 30.

**D102. Polish after D84–D101** (2026-11-27, #124, #129, #135, #137, #141, #151, #66).
- **Steady bars (#135, amends D87's "Not changed").** `LinkRoom` moves to TollUI and is the rule wherever a bottom bar can gain or lose a quiet link: the room stays, empty. Purchase's terms leave the bar for the scrolling content, so Keep it, Done, OK and Try again share one line, with one 14 pt overhang on every page. The home map always ends with a link's room. Welcome keeps "Buy it now"'s room once bought.
- **Pause bar (#151).** It steps with its countdown once a second and has no motion of its own; a continuous fill would move the whole time the sheet is open (§2.5's "Never"). The same with Reduce Motion. "Keep it" has no spinner, because a spinner loops.
- **Segments are the free nights only (#129).** "No pauses left" draws the pauses' week as night dots, Monday's first, nights to come dashed (the sheet grows from 390 to 430 pt). Blocks' sets of hours is a `CapacityBar`.
- **Words (#129).**
  - Choosing a pause says "This uses 1 of 2 left this week".
  - The regret line names a time ("Lock again before 11:43 pm and you keep the pause").
  - Ready says "3 pauses a week, 10 min each" and "…or Dusk stops locking".
  - Purchase's done page adds "Dusk keeps locking your apps every night."
  - `usedLabel` is removed.
- **Tonight (#124, #129).** A break in last night's bar that was a pause carries the `pause` glyph; a time away carries none. A held "Only when I'm home" change is said on the hero ("You're home · Anywhere from the next night").
- **Ready (#66):** on a fresh start, tonight's free segment is ringed.
- **Buffers (#141):** saving an unchanged buffer during the night holds nothing, and choosing the one in force takes a held change back.
- **Your sky (#137):** the landmark tile carries last night's moon, clear of the shape; the poster's wordmark goes through `tollType`, so wordless draws it as a bar.
- **Intended, recorded in the charts (#141).** Screen Time off's note stays after the free nights. Offers and the pill wait while any block is on. "Open Settings" on Choose Always saves home at once. Ask to Buy approvals and refunds reach the extensions at the next app run (only the app asks StoreKit, spec §9). `door-none` answers a stale ask.
- **Assumed, for the founders:**
  - Purchase's terms move into the content (rather than an empty band under Done).
  - The landmark tile carries the moon.
  - "No pauses left" draws the week (rather than dropping it).
- **Left:** #160, #161, #162.

**D103. Blocks, round two** (2026-11-27, #78, #110, #129, #141; details of D73).
- **A block's line is facts, each led by its glyph** (`FactLine`): house, pin or globe for where; an hourglass while waiting for Always; the clock for hours, with the days riding on it; the grid for apps; the calendar when weekends differ. VoiceOver's text is unchanged.
- **Held changes (B-3).** A held change is amber with its clock ("Changes apply at 5:00 pm"); a held delete is `warn` with the trash.
- **App icons.** The editor's Apps row shows up to three of the apps' own icons. New ones arrive as from the picker (D73's motion); those already there don't move.
- **Folding.** Past `blocks.foldAbove` (3) other blocks, they fold into one row: "N other blocks" with the kinds' glyphs, or the one on now with its lock. It opens on a tap, and by itself while one is on; a tap isn't kept. The chevron turns half a turn (§2.5).
- **Lengths.** The hours show their length; the night's says its sleep and the minutes locked before and after it.
- **Full sets of hours.** New block says what frees one ("Give two blocks the same hours to free one").
- **Demos** use the fixture's app counts with stand-in tiles.
- **Assumed, for the founders:** the fold threshold of 3, and no apps-count fact on other blocks' rows.

**D104. Your sleep leads with the person's improvement** (2026-11-27, #85, #86, #87, #88; founder: "sleep is the hero").
- **The measures** (`SleepTrends`, TollCore): Asleep by, Time asleep, How steady (of falling asleep), and Reaching for your phone (every tap on a locked app after the lock).
- **Without Health's sleep** on at least 3 of the last 7 nights, Dusk's own stand-ins show instead, named as what they are: Phone down by (the last reach for a locked app), Nights locked, How steady (of the last reach), and Reaching. Under them: "From Dusk's own nights, not measured sleep. A watch adds real sleep times." The stand-in is unvalidated, so it is never called sleep.
- **The trend rule.** The first 7 nights with a value are compared with the last 7; at least 5 recent nights are needed, all after the first 7. A change is said only past a floor (15 min; 0.5 reaches a night; 2 nights locked) and 2.2 Welch standard errors of the person's own nights. How steady is the average distance from the middle night, first 14 against last 14 (at least 10 recent), floor 10 min. A measure shows from 3 values (7 for How steady); before that nothing is said. In simulation, with no real change and heavy-tailed nights, it claims a change about 4% of the time (1–3% for How steady) and catches a real 30-minute shift about 45% of the time. The thresholds are to be validated against real exports (#165).
- **Words and shapes.** Facts against the person's own first nights, both ways (founder, 27 Nov: "state it as a fact"): "25 min earlier than your first 7 nights", "40 min later than your first 7 nights". The glyphs are up-right (with `ok`), down-right and equal, never colour alone. Each chart shows 14 nights, the first level dashed and the last week solid.
- **Layout** (founder: "under the sky"). "Night by night" sits under the sky (D88) and before the week.
- **Last night's card** leads with Health's sleep when the night's record has the correction ("Asleep 11:20 pm – 6:55 am · 7 h 35 m"; folded, "Asleep 7 h 35 m"), and with the lock otherwise.
- **The ask (#86).** For someone who skipped Health, the open card offers "See how you slept" once, the morning after the first night that ran. It's worked out from the nights, with nothing stored. Your sleep keeps "Add your sleep from Apple Health" while Health isn't chosen. Health counts as chosen whatever iOS answers, since a refusal reads as no nights.
- **Not shown yet:** the sleep model's insight beside the measures, which waits for personal timing (#155).
- **Assumed, for the founders:** without Health, Time asleep becomes Nights locked; the first nights are the first 7 since setup, not Health's history from before Dusk.

**D105. The most important thing on a screen is the first thing seen** (2026-11-28, founder: "what are the most important things on a given screen, are those things highlighted, or is something else dragging the attention away"). A design principle (design.md §1, principle 9) and a check every screen change runs before review (§1.1).
- **Where it came from.** The wordless pass (#70) put Tonight's state glyph on its own above the eyebrow. It made the states tell apart without words, but the founder felt something was off. The glyph floated detached, it added a tier so the eye landed on the icon before the time, and it pushed the time down.
- **The rule it settled for state glyphs:** with a time on screen, the glyph stays small and inline beside the eyebrow (as since D75), growing with Dynamic Type. Without a time (off, Screen Time off, no blocks), the glyph stands alone and large in the time's place. This covers evening, locked, away and the pause open.
- **What it asks of reviews:** name the screen's one or two most important things, check the render shows them first, and demote whatever pulls the eye away, even something useful.

**D106. Every screen passes the wordless test** (2026-11-28, #70, #74, #76, #79, #124; the founder picked per screen, which set D105's glyph rule).
- **Tonight.** With a time on screen, main's small glyph stays before the eyebrow and the big time keeps its place (founder; checked equal y on every timed state). With no time, the glyph stands alone and large: the 64 pt mark replaces the time when nothing will block (off, Screen Time off), and a 26 pt moon sits over "Your night" when there is none. The read-only note gets its own glyph (`exclamationmark.arrow.triangle.2.circlepath`) and the recovered note the apps grid, instead of borrowing location.slash.
- **Onboarding.** Welcome draws a moon with a lock above its words (dropped on phones too small for it). Times found in Health carry Health's glyph. Ready's tick is a mark over its eyebrow and its pauses are dots. Set home with location denied says so in a degraded note.
- **Settings.** "Is everything working?" leads each row with the tile of what it checks; "Turn on" carries the leaves-the-app glyph.
- **Dynamic Type.** Glyphs beside words grow with the text (`tollGlyph`); a large mark grows up to 2× (1.5× at 64 pt). Glyphs inside fixed geometry (the strip, night dots) and the gear keep their size. The hero's line wraps.
- **No copy changed.**
- **Left:** Settings' App and Help cards are still words only; the around sheet's minutes read only as digits; Ready's pinned bar covers much of its content at AX5 (#168).

**D107. Personal timing on the phone, built and off until offered** (2026-11-28, #155; details of D66, D99, D101).
- **Off for everyone until the offer exists** (D65: offered once after the first week, needs Health, can be turned off; #171). `timing` in `state.json` holds the switch, the start in force by night, and the generator.
- **The week's start.** For a person with timing and Health on, the app draws the start with `SleepModel.chooseStart` on opening. It draws for the next night that hasn't started, 90 minutes or more before its lock, with the person's model brought up to date by last night and Health's correction. Every process locks with it. It is put in force or let go only between nights (B-3).
- **Within the buffers.** The start moves only the lock, from bed minus the buffer before sleep. It never starts after bed, never more than 90 minutes before sleep, and never earlier while the buffer before sleep is above 60 (D101). Wake and the buffer after waking never move.
- **A week holds one start,** Monday to Sunday by the night's date. It is let go when Sunday's night ends, with the noon wake (D100) as a second chance. A buffer change the start no longer fits, or switching timing off, gives the next night back to the person's own time. A week the app isn't opened in runs at the person's own time and is recorded "fixed".
- **Records** (no format raise): every night of a hold writes `policy` "held", `hold_start`, `settled`, and the hold's offset and chance, whether or not the lock ran. `gap_min` stays the buffer's setting; the lock started at bed − `gap_min` + `action_offset_min`. The buffer suggestion (D101) reads a held night's buffer as `gap_min − action_offset_min`.
- **Data** (D92): schema 5 adds `timing`, and step 4 → 5 writes it off. minReader is 5 only while timing holds anything, so a downgrade still saves for everyone else. A lost state file brings back timing, Health and the start from the latest held record.
- **The app only.** The monitor would need the model and a person's state brought up to date from the whole night log, against its size budget. `TollConfig.timing.offsets` must equal the artifact's actions; a test checks it, so a new artifact with other actions allows no new start until the config follows.

**D108. Your sleep's change lines are judged weekly, robustly, and spent over time** (2026-11-28, #165; amends D104's trend rule).
- **Why.** Re-judged every day, D104's rule told about half of people with no real change of an "earlier" or "later" at some point within 12 weeks. That was measured on simulated heavy-tailed nights and on a real Health export (n=1, private). Real nights are noisier and wander more than the simulator assumed (#154).
- **Weekly.** The line is judged on the week that ended before the latest Monday noon (D99 and D100's week), and held until the next. Values and charts still move nightly. Nothing is stored. A week with fewer than 5 nights shows no line until the next Monday.
- **Robust.** 20% trimmed means. The person's noise is pooled within weeks, winsorized, over every judged week, so one wild night can't make or hide a change.
- **Spent over time.** The k-th look needs a miss chance of 0.02/k² (Student's t, Yuen's degrees of freedom), plus D104's floors. A change said the week before, the same way, is kept at the first look's test.
- **Result.**
  - With no change in level, 2.9–4.3% of people are ever told of one within 26 weeks across the public stress profiles (`datascience/reports/trends.md`).
  - Replayed on the private export, in shuffled order: at most about 5% within 12 weeks, against D104's 46%.
  - A line changes about once or twice in 12 weeks.
  - Power for a real 30-minute shift is 5–66% by 12 weeks, depending on the noise.
- **The baseline stays the first nights,** because the line names them (D104). A level that wanders is described truly, not counted as false.
- **Reference:** `datascience/trends/`, with 417 parity fixtures.
- **Left:** #173 (How steady after an early shift, a change in noise alone, Health's late correction) and #174 (the last-reach stand-in, which needs Dusk's own nights beside Health).

**D109. Apple's screen time after bed, in its own row** (2026-11-28, #65; amends D5, follows D46 and D104; the founder confirmed `com.advan.toll.Report` has Family Controls (Distribution) and App Groups).
- **A fifth target (amends D5).** `Report/` (`TollReport`, `com.advan.toll.Report`) is a DeviceActivityReport extension. It is the one more `project.pbxproj` edit the pivot needed. It imports only TollCore and never TollData, and adds no DeviceActivity monitored activity.
- **What it shows:** last night, bed to wake. That is the night's stored hours without the buffers, starting at setup for a night set up part-way (`AfterBed.lastNight`). It counts this iPhone only, every segment added up.
- **The number is Apple's.** iOS draws it inside Dusk, and Dusk can't read it, so it is never compared with Dusk's numbers, stored, or used in a rule. It fills the place D46 held for Apple's tile, as its own row rather than a third column.
- **Where it sits.** At the foot of last night's open card, after the last 7 nights. On Your sleep, after "Night by night" and before the week. Only with Screen Time on and a night that has ended.
- **How it looks.** A raised tile with 12 pt corners (Apple's look), Screen Time's hourglass growing with the text, "Screen time after bed" and "Last night, from Screen Time", with the number at the end (or under the words at accessibility sizes). Body weight for the words and the number, so it never outshouts the card's headline or the measures (D105).
- **Assumed, for the founders:** last night only, not the week; the row hides without Screen Time rather than offering to turn it on.

