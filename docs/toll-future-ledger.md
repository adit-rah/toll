# Toll — Future Ledger

Everything deferred, undecided, or decided-by-default. One line each. When something here is decided, move it into the spec and note the date.

## A. Decided by default in the 0.1 spec — confirm or change

| # | Decision | Default taken | Where |
|---|---|---|---|
| A1 | What a stranger at your school sees as your name | First name + last initial | spec N-16 |
| A2 | Solo user who later signs in: upload on-device history? | Yes, with one line telling the user | spec §11.4 |
| A3 | Age gate | The legal line under the Welcome buttons ("By continuing you confirm you're 16 or older…"); 16+ store rating | spec §9, §13 |
| A13 | Daily summary default | On once notification permission is granted; off in Settings. Pending friend requests ride in the same sentence; no separate request alert | spec N-13 |
| A4 | Data retention | Raw server events 90 days; rollups kept; device keeps everything | spec §14 |
| A5 | Contacts matching | In only if ≤ 1 engineering day; discoverable toggle default on | spec N-12 |
| A6 | Wait continues while Toll is closed; no lock-screen countdown, no end-of-wait notification | Yes | spec G-4 |
| A7 | Status after week one | Personalised to the user's own median (better / usual / worse) | spec §14 `status.personalise` |
| A8 | Who answers support | A founder, daily during exam periods, via `support@` | spec §13 |
| A9 | Home navigation | Tab bar (Home · Insights · People); Blocks via Settings, empty state and the gate. Reversed the original "no tab bar" in design review, 8 Nov | design §2.7 — decided |
| A18 | Identity | Display name + unique @handle + optional photo at sign-up; email sign-in by 6-digit code, no passwords; tags stored by app ref so retagging re-labels history; block names user-only (8 Nov) | spec §4, §9, N-16 — decided |
| A19 | Friends step | Set up 4, a full step with Skip beneath Done; never a popup (8 Nov) | spec N-17 — decided |
| A20 | Permissions | No skip; denied shows Try again (8 Nov) | spec §9 — decided |
| A16 | Blocks | Schedule-first: a block is apps + when (Always, Nights, Weekdays, Custom); apps are named lazily at their first wait, never at setup (8 Nov) | spec §4, G-3a, G-7a — decided |
| A17 | Permissions step | One Allow button runs both system sheets; the daily-summary toggle moved to Settings, on by default | spec §9 — decided |
| A15 | Onboarding | Welcome (sign in or skip) first, then a state-routed three-step device setup; Keychain session skips Welcome on reinstall (8 Nov) | spec §9 — decided |
| A14 | Home hero placement | Centred, just under the toolbar, in its own zone (chosen over top-left and upper-third in mockup review, 8 Nov) | design §2.1 — decided |
| A10 | Donation link placement | Settings, last group | spec §3 |
| A11 | Tag list | instagram, tiktok, youtube, snapchat, x, reddit, other | spec §14 |
| A12 | Daily summary mechanism | Server push, not local notification | spec §11.3 |
| A21 | Conflicting docs (resolved 9 Nov, build start) | Spec over other docs, newest decision over older: no skip on the Screen Time denied screen (§9, A20 over the stale §10 line); a stranger at school sees display name + handle (N-16 over A1); pinned copy uses "their" ("Adi removed Instagram from their blocklist."); setup bar shows 4 segments for new signed-in accounts, 2 for solo and returning; a second block hit joins the running wait and the session unlocks every app hit during it (flows §9 over G-6's "that block only"); B3 uses the §10 sentence; B4 and B5: nothing is sent | spec §9, §10, N-16, G-5/G-6 |
| A22 | Identity values | Bundle `com.advan.toll` (+ `.ShieldConfig`, `.ShieldAction`, `.Monitor`), App Group `group.com.advan.toll`, host `toll.alders.dev` for links, legal pages and the API (`/v1`). One place each: `ios/Config/Base.xcconfig`, `api/wrangler.jsonc` | spec §11 |
| A23 | iOS compile check | GitHub Actions macOS job builds all four targets unsigned and runs package tests on every push; Xcode Cloud keeps signing and TestFlight | spec §12 |
| A24 | Screen Time glue shared by app and extensions | `TollScreenTime` product inside the `TollCore` package (no fifth package) | spec §11.1 |
| A25 | Worker test runner | `@cloudflare/vitest-plugin` (the renamed `@cloudflare/vitest-pool-workers`); npm `legacy-peer-deps` works around an npm resolver crash on Vitest's optional peers | spec §12 |
| A26 | D1 tables beyond §11.2 | `email_codes` (OTP state), `idempotency_keys`, `school_domains` (one school, many domains); `blocks_meta` has no name column because §11.2's API says the name is never sent | spec §11.2 |
| A27 | Photo resize | The app downsizes to 512 px before upload; the Worker decodes and re-encodes with `@cf-wasm/photon` so stored photos are always ≤ 512 px JPEG with metadata stripped | spec §11.2, N-16 |
| A28 | Shield Dismiss | Recorded as a `block_hit` (`via: dismiss`) so "held" (walked away) is measurable; the gate is entered only for Open Toll | spec §4 Week stats, §11.1 |
| A29 | Session end | Expiry = start + `gate.sessionWindowMinutes`; whichever of threshold, interval end or the next Toll run after expiry comes first re-shields. An app inside a blocked category unlocks through the category's `except` list | spec G-6 |
| A30 | Unused pass | A granted pass waits on the session picker until used; further hits join it; it lapses at the day's reset | spec G-3, G-5 |
| A31 | Schedule activities | One repeating DeviceActivity per scheduled block (overnight windows as one interval; Always needs none); every wake recomputes the shield from `ShieldPlan`, so day sets are enforced in code. Overnight edges are verified on the gate checklist | spec §6, G-7a |
| A32 | Background wakes | Silent pushes and background refresh ingest the spool and sync but never enter the gate; only the user opening Toll within `gate.resumeWindow` does | spec G-3 |
| A33 | Permission revoked with blocks on the phone | Home with "Screen Time is off · Fix", not onboarding (the §9 table over a literal reading of O-4) | spec §9 |
| A34 | Getting check-ins to the server | One silent push per device per day plus background app refresh flush the outbox, so N-9 silence means the phone really stopped checking in | spec N-9, N-13.3 |
| A35 | Remote config in solo mode | Not fetched; solo runs on the cached or default values so it never touches the network | spec §11.2, §13 |
| A36 | Tags on events | Events carry app refs only; the server joins tags at read time (§11.2), so a retag re-labels history | spec §4, §11.2 |
| A37 | Times in friend rows | A friend's pass times are shown in the friend's local time (the time they lived it) | spec §10 |
| A38 | "Remove Instagram? …" confirm | Toll cannot read app names as text (spec §6), so the confirm names the block by its user-only name, else its schedule ("Remove Nights · 11 pm – 7 am? Your friends will see this.") | spec §10 |
| A39 | Setup step transitions | Steps are driven by launch state, so they change with a slide-and-fade (`Motion.movement`) rather than a navigation push; Email → Code inside Welcome is a real push | design §2.5 |
| A40 | Friends' tag-share bar (I-18) | One segmented bar on the sequential ramp by rank (11 Nov; was the chart's categorical styles), so the screen keeps one accent; revisit with the identity work (C19) | insights I-18 |
| A41 | Held and running waits | A hit while a wait is running joins the wait and is never counted as held | backend (E3–E11) |
| A42 | Status history | The person's active days (any event) in the 28 days before today, oldest first | backend (E3–E11) |
| A43 | Daily summary position | N-3 order: each person's week-to-date trend for the week containing their yesterday vs the full week before; "of N friends" counts you | backend (E3–E11) |
| A44 | Summary with no friends | "N passes yesterday." alone, plus "N friend requests waiting." when there are any | backend (E3–E11) |
| A45 | Handle cooldown | The handle chosen at sign-up does not start the cooldown; the first later change is free and starts the 30 days | backend (E3–E11) |
| A46 | School email ownership | One school email belongs to one account at a time; verifying it again moves the membership. The most specific listed domain wins | backend (E3–E11) |
| A47 | School numbers | From the nightly rollup only ("as of 4 a.m."); an active member has at least one active day that week; the school week uses UTC with the 04:00 reset | backend (E3–E11) |
| A48 | School distribution | Each member's weekly pass count is stored; bins are cut at read time and small bins merged | backend (E3–E11) |
| A49 | Same app, same hour (I-14) | Friends only (not you), from `insights.lateStart` to the reset hour, at least 3, excluding untagged and "other" | backend (E3–E11) |
| A50 | Passes per person | Divides by people active that week | backend (E3–E11) |
| A51 | Silence threshold | At least 2 whole days with no event of any kind while blocks are on; with no events ever, counted from the first saved block | backend (E3–E11) |
| A52 | Late block events | An older block event arriving late never brings back a removed block; a removal keeps its apps so the pin can name them | backend (E3–E11) |
| A53 | Silent pushes | Every due device gets one silent background push a day, even with the summary off (A34) | backend (E3–E11) |
| A54 | Push failures | Acked without retry; tokens APNs reports as 410, BadDeviceToken or Unregistered are cleared | backend (E3–E11) |
| A55 | Code attempts | Resending a code does not reset the five-try lock; limits key on IP + email hash for codes, user id for social and ingest | backend (E3–E11) |
| A56 | Re-auth for deletion | Email accounts re-auth with the sign-in code; Apple accounts with a fresh Apple credential for the same subject | backend (E3–E11) |
| A57 | Reports | Kept after either account is deleted | backend (E3–E11) |
| A58 | Backups | Weekly NDJSON exports in R2 expire after 90 days (lifecycle rule in `api/DEPLOY.md`); the privacy draft says so | backend (E3–E11) |
| A59 | Install count | `installs` counts registered devices; solo phones never reach the server | backend (E3–E11) |
| A60 | Safety routes | `/v1/person-blocks/:userId` instead of `/blocks/:userId`, which collides with `PUT /blocks/:blockRef` | backend (E3–E11) |
| A61 | API under `/v1` | Unauthenticated requests to unknown `/v1` paths get 401 (public routes are matched before auth) | backend (E3–E11) |
| A62 | Review sign-in | `REVIEW_EMAIL` gets the fixed `REVIEW_CODE` when both are set; nobody else can | backend (E3–E11) |
| A63 | School list at launch | Spec §15 vendors all of CA/US/GB. Launch seeds 30 schools instead (10 Canadian, the Ivy League, 12 others in the US top 20); the full list stays in `seed/schools-all.sql` | `api/seed/schools-launch.sql` |
| A64 | App picker on arrival (11 Nov, owner review on device) | The picker never opens by itself: Block these, New block and Add another all arrive on the empty apps card and "Choose apps" opens it. Reverses the §9 "picker opens on arrival" | spec §9, flows §5, §14 — decided |
| A65 | Home stack navigation | Every push in the Home stack (Settings, Blocks, New block, edit) is a value on one path with destinations at the root; a view-destination link in the middle sent Back from Blocks into New block | design §2.7 |
| A66 | Home footer | "You opened Toll N times today." is anchored above the tab bar as a bottom safe-area inset, not the last row of the list; `label2`, because `label3` at 13 pt is under 3:1 | design §4.1, G-10 — decided (11 Nov) |
| A67 | Fills | A card, tile or field takes the fill its page is not (`surfaceRaised` on `bg`, `surface` on `bgGrouped`); hosted controls and disabled buttons take the new translucent `fill` token. The New block mock drew `#F2F2F7` tiles on a `#F2F2F7` page | design §2.1, §2.3 |
| A68 | Setup steps and small screens | The bar and bottom actions are pinned and the content between scrolls only when it does not fit; "never scrolls" could not hold on a 4.7-inch screen with a full apps card | design §4.3 |
| A69 | Custom hours | Compact time pickers in two rows instead of two wheels side by side (they clip each other at phone width and overflowed the half-height sheet); the sheet is 380 pt | design §4.6 |
| A70 | Removing an app from a block | Touch and hold the app row → Remove (or untick it in the picker). The rows are not in a List, so the swipe in flows §14 never existed | flows §5, §14 |
| A71 | Finished blocks in setup | The compact rows above the creator are a record and do not open; blocks are edited from Settings → Blocks | design §4.3 |
| A72 | Title when editing a block | The block's own name, else its schedule label (as A38); "New block" only for a new one | flows §14 |
| A73 | Find your friends outside setup | People, Settings and Insights embed only the groups that belong under their heading (school under School), on `fill` | spec N-17 |
| A74 | People friend rows | The existing week line ("14 this week · 18 last week") under the name with the trend trailing; the mock's lone "14 this week" has no §10 string | design §4.4 |
| A75 | Friend detail | "Waited" shows minutes; only "this week" has a last-week value (the API returns no others); block chips are neutral, not accent-tinted | design §4.5 |
| A76 | Invite sheet | Code centred, action on the bottom edge (the mock stacked everything at the top and left the lower 40% blank) | design §4.9 |
| A77 | Avatar photos | Fetched once into an in-memory thumbnail cache at the drawn size, decoded off the main actor; no disk cache beyond URLSession's | design §3.17 |
| A78 | Wait card geometry | Top at 180 pt only when the card fits, else centred, else scrolling; insets 32/20/20 from the artboards; wait and session picker share one frame | design §3.7, §4.10 |
| A79 | Wait ticking | The card's clock is a leaf timeline and the gate is asked only once `Wait.isComplete` reads true (at most one second apart), instead of a coordinated pass over the shared state every second. Same completion test and events | spec G-4 |
| A80 | Hero alignment | The numeral is centred and the glyph hangs beside it, rather than the pair being centred | design §3.2 |
| A81 | Dark wait card | Still `bg` (black) on the dark material, with only a hairline under Reduce Transparency; needs a look on a phone before deciding on a raised tier | design §3.7 — open |
| A82 | "Open <App>" | Starting a session unlocks the app and the card leaves, but iOS has no way to launch an app from its Screen Time token, so the person switches to it themselves | spec G-6 — open |
| A83 | Hand-drawn insight cards | I-2, I-5, I-11 and I-18 are SwiftUI shapes, not Swift Charts (no bar outline or track there); audio graphs and spoken values kept | insights §4 |
| A84 | Insights refresh | Me numbers come from the last eight weeks of events, computed off the main actor; remote insights refetch on pull, week change, account change, or after `sync.flushIntervalSeconds` | insights §3 |
| A85 | Share card | Rendered only when a share target asks for it; canvas is white / `#0F1115` in both preview and export; the square format drops the metric row | design §3.14 |
| A86 | Insight chart motion | The first-appearance bar growth in design §2.5 is not built yet | design §2.5 — open |
| A87 | Uploads never hold the screen | A flush started by the user opening Toll, saving a block or tagging an app runs after the state is returned; background wakes still wait for it. A user-opened flush may therefore be cut off by suspension and goes out on the next trigger (events are idempotent) | spec §11.1, G-4 |
| A88 | Launch and foreground | Foreground waits for launch, and a foreground arriving during one is run after it rather than dropped; `GET /home` at launch is skipped once Find your friends has been shown, since Home fetches its own | spec §9 |
| A89 | Still slow, not fixed | `Dependencies.live()` opens the database and starts Sentry before the first frame; Home refreshes on every tab return (throttling needs a §14 tunable); the periodic `sync.flushIntervalSeconds` trigger is not implemented | spec §11, §14 — open |
| A90 | Cutting a build | Merge to `main`, then publish a GitHub release with a new `v*` tag on `main`; the automation builds it and uploads to TestFlight. No version edit first. A cloud agent session can merge the pull request but cannot push tags, so the person cuts the release. Written into `CLAUDE.md` (Releasing) so nobody has to rediscover it (11 Nov) | spec §12, `ios/README.md` — decided |
| A91 | Flat-time sessions | A session is the chosen minutes of wall-clock time from its start (`expiresAt = startedAt + minutes`), used or not. The usage-threshold event is gone. The monitor is woken by a one-off interval of `max(minutes, 15)` minutes with `warningTime` = interval − minutes; every callback only reconciles, so a session ends only once its persisted expiry has passed. `gate.sessionWindowMinutes` is unused (removed from `TollConfig`; `config.ts` still serves it). Supersedes A29's expiry rule (11 Nov) | spec G-6, §6, §14 — decided |
| A92 | A pass is recorded when used | Granting a pass (free, or at the end of a wait) only sets the pending pass; the `pass` event is written when the session starts, timed at the session start, with the block ref when known. A pass declined or lapsed at the day reset leaves no event: the free pass is still available and the wait ladder does not advance. A hit whose free pass is declined, or used more than `gate.resumeWindow` after the hit, counts as held. No server change (11 Nov) | spec §4, G-3, G-7 — decided |
| A93 | "Not now" on the session picker | A pass that came from a shield is kept until the day reset with the picker off screen; the next shield hit, an Unblock, or an explicit resume brings it back. A pass asked for inside Toll is dropped (11 Nov) | spec G-6, flows §9 — decided |
| A94 | Unblock from inside Toll | Enters the gate exactly like a shield hit, for every app ref in the block (first one named on the card); joins a running wait or a waiting pass; records no `block_hit`. The wait and the pass carry the origin and the block ref (11 Nov) | spec G-3, G-5 — decided |
| A95 | Block again | A session can be ended early from Toll: removed, re-shielded, its activity stopped, `session_ended` recorded. The pass it used still counts (11 Nov) | spec G-6 — decided |
| A96 | Block status | One pure rule for the line beside a block: off outside its window (with the next start), open while a live session covers any of its apps (until the earlier of the session's expiry and the window's end, per G-7a), otherwise on (until the window's end; no end for always). Window edges follow `Schedule.isActive`, including the missing and repeated hours on DST days (11 Nov) | `TollCore` `BlockStatus`, spec G-7a — decided |
| A97 | Session-line and picker copy | Home reads "Instagram is open · 7 min left" (minutes rounded up, no full stop); the picker note is "From now. The block returns after."; new strings for blocks inside Toll ("Unblock", "Block again", "Pass ready", "6:42 left", "Until 7 am", "Starts 11 pm", "1 block on"). Design §4.1's session line quote updated to match (11 Nov) | spec §10, design §4.1 — decided |
| A98 | Upgrade edge, not handled | A pass already pending when the build changes was recorded by the old build at grant and is recorded again when used; a session in flight keeps its old 60-minute expiry. One-off, pre-release only (11 Nov) | spec G-7 — accepted |
| A99 | Block bar on Home | A block in effect is shown in a bar pinned at the bottom of Home, 8 pt above the tab bar and under the Toll-opens caption (one dock, one `safeAreaInset`). It replaces the session line at the top of Home, which is removed. No blocks, or only blocks with no days, means no bar. It is the one floating control of Toll's own, so it is `.regular` glass on iOS 26+ and `surfaceRaised` with a hairline before (11 Nov) | design §1.7, §2.4, §3.18, §4.1 — decided |
| A100 | Which block the bar shows | Priority: an open session, then a pass that is ready, then a block that is on; ties by the block list's order. More than one on or open: the title is the count ("3 blocks on"), one icon from each block, the first block's state line and action. None on or open: the next block to start, quiet, "Starts 11 pm", no action word (11 Nov) | design §3.18 — decided |
| A101 | Block bar enlarges into block cards | Tapping the bar presents a sheet with the system zoom transition from the bar (medium and large detents); a card per block on or open, then blocks outside their window as plain rows. Unblock closes the sheet before entering the gate, because sheets sit above the wait card. A wait or a picker arriving for any reason closes every Home sheet (before, only a wait did). Each card carries its own primary button, so the one-primary rule is read per card on this sheet; "Blocks" is one quiet link at the foot, not one per card (11 Nov) | design §2.5, §3.18 — decided |
| A102 | Block again ends every session on the block | "Block again" ends each live session covering one of the block's apps (a shield pass and a block pass can overlap), not only the newest; otherwise the block would still read as open. It plays the `.light` haptic, added to the list in design §2.5 (11 Nov) | design §2.5, §3.18, spec G-6 — decided |
| A103 | Home's block states and their clock | `HomeModel` holds the stored blocks and publishes one state per block (phase from `BlockStatus`, the line to print, the sessions to end), recomputed when the blocks or the gate change and at the next moment anything changes by itself: it sleeps until the earliest window edge, session expiry or (with a pass set aside) day reset, then calls `expireSessions()` and recomputes. A set-aside pass from an earlier Toll day is not shown as "Pass ready" even before the gate has dropped it; Unblock then falls back to a fresh request (11 Nov) | `TollFeatures` Home, spec G-6 — decided |
| A104 | Session picker button and frame | The button reads "Unblock for 10 min" for every pass (Toll cannot switch to the app; "Open Instagram" promised something that never happened); the card's `openLabel` slot is gone. "Not now" is the same 44 pt quiet button as Cancel on the shared bottom edge; the picker's gaps were tightened (12 / 16 / 4 pt) so the shared frame stays within about 14 pt of the countdown's own height. `Copy.SessionPicker.open` / `openVerb` and `Copy.Home.sessionActive…` are now unused and can go with the next copy change (11 Nov) | spec §10, design §3.7, §3.8, §4.10 — decided |
| A105 | Wait card title for a whole block | A wait or pass asked for with Unblock inside Toll (origin `app`) titles the card with the block's apps on one line; one from a shield names the tapped app as before. Spec G-3 still says "the first is the one named on the card", §8 still describes the session line at the top of Home and §10 still lists "Home, session active": to be brought in line with the next spec edit (11 Nov) | design §3.7; spec G-3, §8, §10 — decided, spec text open |
| A106 | Block bar countdown and VoiceOver | The bar's countdown ticks each second in a leaf view, is marked as updating frequently and is spoken in 30 s steps, but posts no announcements by itself (the wait card does): it is on Home for the whole session and would interrupt for up to 15 minutes (11 Nov) | design §5 — decided |
| A107 | `+` on Home | A `plus` bar item beside the gear pushes New block; disabled at `blocks.max`. Its label is "Add a block" (11 Nov) | design §2.7, §4.1 — decided |
| A108 | Expired tokens, per block | A block needs re-picking when any of its app refs has no token (before: only when every block had lost every token). Home shows "Blocks need re-picking · Fix" when any block does; Fix opens that block when one is affected, Blocks when several are. An affected row reads "Needs re-picking" in place of its schedule. The editor opens with the apps that still have tokens, says "Some apps are missing from this block. Choose them again." until something is chosen, and compares edits against those remaining apps, so an untouched screen has no discard prompt. Done saves the apps on screen: the lost refs leave the block, recorded like any other change (11 Nov) | spec §9, §10; flows §7, §14, §19; design §4.1, §4.6 — decided; whether friends should see a removal that iOS caused is open |
| A109 | Notifications off, in Settings | With the system permission off, "Notifications are off" and an "Open Settings" row replace the summary switch and the time. The button asks the system first, which shows its sheet only if it never has (setup skips the prompt when Screen Time was turned on from the Settings app), and otherwise opens the Settings app. `AppModel.notificationsAllowed` holds the answer read at every foreground, so the rows change as Toll returns (11 Nov) | spec §10; flows §16; design §4.8 — decided |
| A110 | Notification taps | `route` "home" selects Home, "people" People. "gate" tapped with Toll already active runs the gate again (`AppModel.gateTapped`) so its wait can start; it is not `foreground()`, because that counts a Toll open (G-10) and Toll was already open. A tap that brings Toll to the front is handled by the activation as before (11 Nov) | flows §17; spec G-10 — decided |
| A111 | Failures that were silent | People: an Accept or Decline that fails leaves the row and shows "That didn't work. Try again." on the tab's error line ("No connection." when the reload fails too). Home: signed in with no cached `/home` and a failed fetch, the Friends section says "No connection." in place of "No friends yet. Send an invite"; with a cached answer the rows stay and "Updated …" covers their age (11 Nov) | flows §7, §12; design §4.1 — decided |
| A112 | Block count limit line | At `blocks.max` a second caption beneath the Blocks list reads "8 blocks is the most." (number from config). Home's `+` stays disabled without a line of its own (11 Nov) | spec §10; flows §14; design §4.6 — decided |
| A113 | "Fix" for Screen Time once iOS stops asking | If the request comes back not approved, Fix opens the Settings app (as setup's Try again does). Home rereads the device state each time the scene turns active and applies the blocks if Screen Time went from off to on meanwhile (11 Nov) | flows §4, §19; design §4.1 — decided |
| A114 | Account edit saves for itself | The Settings account screen keeps the You step's model for the fields and the live handle check but sends its own PATCH: "taken" beside the handle (`Copy.Errors.handleTaken`), "Handles change once a month." and "2 to 24 characters." beneath, "No connection." when the request never landed. It no longer sends the `onboarding_step` event, the timezone, or a reroute on an edit. `YouModel.save` is unchanged and still has no case for `handle_cooldown`, which setup cannot meet (11 Nov) | flows §16 — decided |
| A115 | Unused copy removed | `Copy.SessionPicker.open` and `openVerb` are gone (A104). `Copy.Home.sessionActive` and `sessionActiveRest` stay: `BlockStatusTests` still asserts the line, so they go with that test (11 Nov) | spec §10 — decided |
| A120 | A session replaced by a new one | Starting a session that covers an app of one still running ends the earlier one at that moment: `session_ended` is recorded for it (timed at the new session's start, before the new `pass`) and its DeviceActivity interval is stopped. Before, it was dropped from the state without a trace (11 Nov) | spec G-6 — decided |
| A121 | Clock guard for sessions | A session stores the monotonic instant it started at and its expiry is guarded like a wait's: within one boot, when monotonic elapsed time disagrees with the wall clock by more than `gate.clockSkewTolerance`, the session ends at the earlier of the two ends. A clock set back no longer lengthens it; a clock set forward still ends it early, as before, where a wait would follow the monotonic clock, because the session's only wake is a wall-clock interval and a session kept open past it would stay open until Toll next ran. Applied wherever the shield is decided (app reconcile, blocks change, monitor). Left on the wall clock: the session's DeviceActivity interval, so after a set-back nothing wakes the monitor at the real end and the shield returns at the next run of Toll or the monitor; the countdown on Home (TollFeatures passes no monotonic reading yet; `remaining`, `isExpired` and `minutesLeft` take one); anything after a reboot. The monitor uses the built-in tolerance, not a remote override. Open: the boot id is read from `kern.boottime`, which may move when the clock is set, in which case a process started after the change falls back to the wall clock; the gate checklist §8 has the device check (11 Nov) | spec G-6, G-9; gate-checklist §8 — decided, device check open |
| A122 | `gate.sessionWindowMinutes` removed | Dead since A91. Gone from `api/src/config.ts` and spec §14; an installed build that still decodes the key falls back to its own default and never reads it (11 Nov) | spec §14 — decided |
| A123 | Seeing screens without a Mac | Debug builds take `-TollDemo <scenario>` launch arguments that open one screen state on seeded data (`TollFeatures/Demo`, never compiled into Release). `render.yml` builds for a simulator on a GitHub macOS runner, starts the Worker locally with the App Review seed, and saves a screenshot, the accessibility tree (AXe, a CLI on the runner only), and the app log per scenario to the branch `renders/<branch>`. A viewing tool, not a test: nothing asserts and nothing fails a build, so spec §12's "no UI or snapshot tests" stands. Family Controls does not run in the simulator, so `ScreenTimeAuthorization.simulated` answers for it in demo launches; shields and the gate on a real shield stay in `docs/gate-checklist.md` (13 Nov) | `docs/renders.md`, spec §12 — decided |

## B. Open — needs a founder decision before the relevant task

| # | Question | Blocks |
|---|---|---|
| B1 | The thesis sentence, in the founders' own words | Store listing, first screen (E10.45) |
| B2 | Store listing, first screen and poster copy | E10.45 |
| B3 | Daily summary exact sentence (spec §10 has a draft) | E7.35 |
| B4 | What Toll does when a user has zero block hits for a whole week: nothing, or one line in the daily summary | E7.35 |
| B5 | Whether a user is told anything when all their friends have gone silent | E4.24 |
| B6 | "Toll opens" count: decided — stays on Home as the footer caption, quietest element on the screen (8 Nov) | — |

## C. Deferred features (not in 0.1), with the principle that governs them

| # | Feature | Note |
|---|---|---|
| C1 | Money (donations beyond a link, sponsors, any revenue) | Version 1; separate document `Toll — Money`. Principles 1, 10. |
| C2 | Ads as a path through the gate | Dropped. Platform risk (4.10, ad-network rules), and the manifesto now says no ads. |
| C3 | Groups (friend groups by code; group modes; rankings inside groups) | Replaced by friends + mutuals + school. Revisit only if friend circles prove too small to meet the §1 kill criteria. |
| C4 | Friend approvals, nudges, instant notifications to friends | Principle 11 (never pull friends onto their phone). |
| C5 | Math or puzzle path | Not needed without ads; the wait is the only path. |
| C6 | "Most improved at your school this week" list, opt-in, real names | The one school feature the evidence leaves open; test after April. |
| C7 | Wait starting from the shield itself (no app open) | Reconsider only if Apple adds an API; `openParentalControlsApp` makes opening Toll cheap. |
| C8 | Lock-screen Live Activity for the wait | Rejected: encourages watching the clock. |
| C9 | Widgets (home/lock screen) | Not in 0.1; a glance widget of today's count is the only candidate. |
| C10 | Categories in the block picker | Only if users hit `blocks.maxTokens`. |
| C22 | User search by @handle | Handles exist from 0.1 for this; search itself waits until there is a reason beyond invite links. |
| C23 | Picker category tokens shown to friends as "Social apps" etc. | Allowed in the picker from day one; naming for categories uses the same chip list plus "Social", "Games" if adopted. |
| C21 | More schedule presets (exam weeks, class timetable import) | After seeing which custom windows people actually set. |
| C11 | Ranking outside your friends; school vs school; friend group vs friend group | Principle 12; school never ranks people. |
| C12 | Percentile wording at school ("better than 60%") | Insights spec §10. Revisit with `schoolMinMembers` met for a full term. |
| C13 | Streak mechanics, confetti, encouragement, mindfulness content, games, physical challenges | Principles 3, 9. Not ever, per the manifesto. |
| C14 | Messaging, comments, reactions, a scrolling feed | Principle 12. |
| C15 | Android | After the April retention read. |
| C16 | Exam-week auto-detection from school calendars | Manual marking only in 0.1. |
| C17 | Using the 26.4 "App and Website Usage" capability to show real minutes | Rejected unless Apple changes the prompt; it turns the permission into a usage disclosure. |
| C18 | Export of share cards as transparent "sticker" overlays | Nice-to-have after the two formats ship. |
| C19 | A second accent / full brand system | After identity is designed (`toll-brand-tbd.md`). |
| C20 | Predictions in insights ("at this rate…") | Not facts. Out. |

## D. Risks to re-check at each milestone

| # | Risk | Check |
|---|---|---|
| D1 | `openParentalControlsApp` does not work under individual authorization | Hardware test in E1.9; fallback is the notification route, already built. |
| D2 | Family Controls entitlement delay | Filed day one; development entitlement for internal builds; TestFlight blocked until approved. |
| D3 | Automated 2.5.1 "missing entitlement" flags in review (seen summer 2026) | Keep review notes explicit; appeal with the approval email. |
| D4 | DeviceActivity threshold unreliability | Persisted expiry + foreground re-check is the design; log every re-shield source for the first month. |
| D5 | D1 single-writer throughput | Not a risk below ~1,000 qps; `batch()` on ingest. |
| D6 | APNs from Workers only works deployed | Preview environment for push testing. |
