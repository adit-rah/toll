# Decisions and findings

MVP spec §13: "Otherwise decide, record it in `docs/decisions.md`, and continue." Newest last. **Open** marks one waiting on the founders.

## Decisions

**D1. Hollow out in place, not a fresh project** (2026-11-17). The repo, Xcode project, bundle ids, App Group, Xcode Cloud and render pipeline stay; everything in spec §2 "Out" is deleted. Family Controls (Distribution) approval is per bundle id, so a new project would mean asking Apple again. Toll's domain logic (gate, waits, sessions, blocks) is deleted, not adapted: the new rules differ enough that a clean `TollCore` is smaller than a bent one.

**D2. Minimum iOS 26.5** (2026-11-17). From 26.5 the block screen opens the app directly (`ShieldActionResponse.openParentalControlsApp`), so there is no notification route, no notification permission, and the permissions screen stays at the spec's two. Excluded: phones that cannot run iOS 26 (XS, XR).

**D3. One stacked branch per build step** (2026-11-17). `claude/sleep-s<N>-<name>`, each from the previous, one pull request each (spec §12). Merge in order.

**D4. Design foundations move to `docs/design.md`** (2026-11-17). Toll's design doc §2 carries over (spec §7). Its motion table named Toll's screens, so the table is rewritten for this product's moments under the same rules; anything not in it has no motion.

**D5. Report extension removed** (2026-11-17). Spec §2 drops insights and charts, and the trial-ended facts come from the transition log. Removing a target is the one edit to `project.pbxproj` the pivot needs; adding files still never touches it.

**D6. `TollData` stays as the app-only services package** (2026-11-17). No third-party code (spec §9): GRDB, Sentry and TelemetryDeck are gone, so the project has no remote package dependencies. It keeps the Keychain and will hold location and StoreKit, which extensions must not link.

**D7. Trial form — Open** (2026-11-17). Guideline 3.1.1 allows a free trial on a non-subscription app only as a $0 non-consumable named "XX-day Trial", disclosing before it starts the duration, what stops, and the price after. A timer the app starts by itself risks rejection ("Apps may not use their own mechanisms to unlock content or functionality"). Proposed: Welcome's "Start" buys a $0 "7-day Trial"; trial start is that transaction's `purchaseDate`, which survives reinstalls and new phones (the Keychain copy becomes a fallback, P-4). The trial counts 7 nights and never ends before 7 × 24 h. Store setup: two non-consumables, "7-day Trial" ($0) and the full unlock ($24.99).

**D8. Location and paid features — Open** (2026-11-17). Guideline 5.1.1(ii): "Paid functionality must not be dependent on or require a user to grant access to this data", and 5.1.1(iv): "Where possible, provide alternative solutions for users who don't grant consent." The purchase pays for a block that only turns on at home. Proposed: if location is denied or set to Approximate, the block runs on the window alone ("home" is assumed), and the permissions screen offers that rather than no skip. Without it, review may reject.

**D9. Screen Time monetisation risk** (2026-11-17). Guideline 4.10 lists Screen Time APIs among things apps "may not monetize". Similar apps sell their own logic on top. Review notes (step 10) will describe the purchase as the app's sleep window, home rule and door, not access to blocking itself.

**D10. Home uses `CLMonitor` with Always and a `CLServiceSession`** (2026-11-17). Only Always relaunches a terminated app for region events. From iOS 18, Always is effective only while the app holds a `CLServiceSession`, which can only start in the foreground and is recreated on each background launch. `startMonitoring(for:)` is marked for removal; `CLMonitor` replaces it. Region monitoring needs Precise location.

**D11. Shared state is a coordinated JSON file, not App Group defaults** (2026-11-17). The app and three extensions write it; `UserDefaults` caches per process and gives no read-modify-write across processes. `state.json` and `transitions.jsonl` in the App Group, under `NSFileCoordinator`.

**D12. During a block, time is read through a monotonic anchor** (2026-11-17). B-4 asks that a clock change never holds the block into the morning; D-7 says there is no way to end the night. Reading the wall clock alone breaks one or the other. While a block is on, "now" is the wall time at the last reconcile with the block off plus the monotonic time since, within one boot. Setting the clock back cannot hold the block past the real morning, and setting it forward cannot end it early. Outside a block the wall clock is accepted as it is. After a restart there is no anchor and the wall clock decides.

**D13. A block only starts for a night that began after the last night end seen** (2026-11-17). This covers B-4's clock and travel cases: a clock set back after the morning, or a flight west into a window that already ended, does not block again. It also means a window edited in the morning to cover the present takes effect tonight, which matches "Changes apply after tonight's block ends".

**D14. A second schedule, the sweep, starts a minute after the window ends** (2026-11-17). Its start and end each reconcile, so one missed `intervalDidEnd` does not leave the block on (B-4). The block screen's buttons also reconcile, so the first tap on a stale block lifts it.

**D15. The log records every wake, not only changes** (2026-11-17). Monitor, region and block-screen wakes are logged even when nothing changed, so late and missing callbacks show in the device protocol. Launch and foreground are logged only when they change the block. The log keeps the last 2,000 lines.

**D16. A trigger screen stands in until setup and Status exist** (2026-11-17). Step 2 must hand over an installable build. Its strings sit in `Copy.Trigger`, apart from the spec's copy, and go with step 5.

**D17. Categories chosen for keep-open cannot be kept open** (2026-11-17). `.all(except:)` takes app and site tokens only. A category picked in the keep-open picker is shown as "not kept open" for now; step 4 decides the setup wording.

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
