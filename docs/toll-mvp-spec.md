# Toll — MVP Build Spec (v0.1)

Date: 2026-11-08 · Authority: this document supersedes the "Build spec" tab and the "Working notes" tab of the Product Thesis. Where they disagree, this wins. The Manifesto still describes intent.

Companion docs: `toll-insights-spec.md` (insights and sharing), `toll-design.md` (visual and interaction design), `toll-user-flows.md` (every node and every choice, as diagrams), `toll-future-ledger.md` (deferred decisions), `toll-brand-tbd.md` (identity, not yet designed), `toll-builder-prompt.md` (how to hand this to a builder).

## 0. How to read this

- Written for senior engineers building with agentic tools. Requirements are numbered (`G-3`, `N-7`) so tasks, tests and PRs can cite them.
- "MUST" is a requirement. "SHOULD" is the default unless there is a stated reason. "Config" means a tunable value; all live in §14 and nowhere else in code.
- Numbers in §14 are starting values, not truth. They are tuned after launch by one rule: does the change make the gate work better at stopping the user. Never for any other reason.
- Keep this document short. If a section needs more than a screen, it belongs in a companion doc.

## 1. Product in one page

**What.** A free iPhone app that blocks the apps you choose. Getting past a block costs a wait, spent inside Toll. Your friends can see what you did. No subscription, no paid tier, no ads, nothing ever asked of your friends.

**Why.** People know they overuse their phone. What they lack is something in the way at the moment they reach, and people they chose who can see them reach. Nobody fails at this alone and nobody fails for long when friends can see.

**Who.** A young adult who has realized they overspend time on their phone and has friends to bring along. Students before exams are where we find them first. Nobody is excluded.

**Priorities, in order.** 1) Social: accountability and fun with friends. 2) Simple and fast: setup in minutes; day to day it asks nothing outside the gate. 3) Quality over schedule.

**What proves us wrong.** Fewer than a third of users have a friend on Toll; or users with friends do not look at least weekly; or either founder stops running Toll on their own phone. Everything else is tuned, not fatal.

**Build order.** The gate, and it never dead-ends → the network (friends, mutuals, school) → onboarding in minutes → insights and sharing → everything else.

## 2. Principles

Every feature and every line of copy traces to at least one of these or is not built.

1. We never ask the user for money.
2. The gate costs time, on purpose, and we say so up front.
3. Guilt is self-imposed. The app only states facts: a fact, a number, or a question. No adjectives about the user.
4. Honesty is the relationship. The user can always see what the app did, including how often they opened Toll.
5. Bad news is shown.
6. Low friction in, high friction out. One tap to block; removing a block is seen by your friends.
7. Social is opt-in by connecting; then everything is on. Opting out means disconnecting. A block hides one person, both ways.
8. We would rather the user quit their phone than keep using Toll.
9. No babysitting, no performed toughness, no personality fluff. The action carries the weight.
10. We never tune anything for revenue. Every setting serves the gate.
11. Toll never pulls anyone onto their phone for Toll's sake. It inconveniences only the person at the gate, only at the gate.
12. Toll is a glance, not a feed. Everything a user cares about is reachable in seconds. Nothing to scroll for its own sake, no likes, no comments, nothing to come back for.

## 3. Scope

**In 0.1**

- The gate: shield on blocked apps; wait-only path; one session unlock; passes recorded.
- Blocks: a block is apps and web domains (system picker) plus a schedule (Always, Nights, Weekdays, Custom). Apps are named lazily: the first wait for each app asks once.
- Accounts: Sign in with Apple, or email with a 6-digit code (no passwords), or no account (solo). Solo = gate + personal history + Me insights, nothing social.
- Identity: display name, unique `@handle`, optional photo. Set once at sign-up, editable in Settings. Handles make user search possible later without a backfill.
- The network: mutual friends, mutuals (friends of friends), verified school. Visibility rules in §7.
- Home screen: you at the top, friends below, the wait overlaid when one is running.
- Insights and share cards (specified in `toll-insights-spec.md`).
- One optional daily notification (own count and position among friends).
- Invite link; contacts matching if it costs under a day (N-12).
- Report and block a person; delete account; privacy policy; review test account.
- Donation link, in Settings, below the fold. Never on Home, never at the gate.

**Not in 0.1** (ledgered in `toll-future-ledger.md`)

Ads of any kind. Payments. Groups. Anything that asks a friend to act: approvals, nudges, instant notifications. A math or puzzle path. A scrolling feed, reactions, comments, messaging. Sponsors. Physical challenges. Ranking anyone outside your own friends; school vs school. Categories in the block picker. Mindfulness content, games, streak mechanics, confetti, encouragement. Live Activities or lock-screen countdowns. Android. Any tuning for revenue.

## 4. Domain model

| Term | Definition |
|---|---|
| **Account** | Server identity. Optional. Created by Sign in with Apple or an email code. Has a display name (2–24 chars), a **handle** (unique, 3–20 chars, `[a-z0-9_]`, shown as `@handle`, changeable once per `identity.handleCooldownDays`), and an optional photo. A device may run with no account (solo). |
| **Device** | One iPhone. One account may have several devices; the gate is per device. |
| **Block** | A set of opaque app and web-domain tokens plus a **schedule**. Tokens are device-local and never leave the device. A device may have several blocks; the same token may appear in only one. |
| **Schedule** | When a block's shield is on: `always`, `nights` (23:00–07:00), `weekdays` (09:00–17:00 Mon–Fri), or `custom` (a time window and a day set). Presets are config (§14). Outside its schedule a block's apps are open and no events are recorded for them. |
| **App ref** | A random device-local id for one token, created when the token is first picked. Events carry the app ref, never the token. The device keeps `appRef → tag`; the server keeps `(user, appRef) → tag`. Retagging updates the mapping, so every past and future event re-labels at once. Nothing a user does at the gate is permanent. |
| **Tag** | The friends-facing name for an app ref, from a fixed list (display form in parentheses): `instagram` (Instagram), `tiktok` (TikTok), `youtube` (YouTube), `snapchat` (Snapchat), `x` (X), `reddit` (Reddit), `other` (a blocked app). Asked once, at that app's first wait (G-3a); changeable any time from the block editor. Fixed list means no typos, no casing, no moderation. |
| **Block name** | Optional free text the user gives a block for their own organisation ("Workday"). Defaults to the schedule label. Never shown to anyone else. |
| **Gate event** | A fact recorded by the device. Types: `block_hit`, `wait_started`, `wait_completed`, `wait_abandoned`, `pass` (free or waited), `session_ended`, `block_added` (with schedule), `block_changed` (old and new schedule), `block_removed`, `checkin`. Each carries a client UUID, device-local timestamp, and the tag. |
| **Pass** | One permission to open a blocked app for one session. Free (daily allowance) or waited. |
| **Wait** | The timed cost. Starts when Toll opens from the block screen with no free pass left. Runs whether or not Toll stays open. Fixed end; nothing shortens it. |
| **Session** | The unlocked period after a pass. Measured in use of that app, not wall-clock; end is approximate. |
| **Day** | Resets at a configurable local hour (default 04:00) so 1 a.m. is not the cheapest hour. |
| **Week** | Monday 04:00 local to the next Monday 04:00 local. |
| **Friend** | Mutual connection; both agreed. Sees your week; you see theirs. |
| **Mutual** | A friend of a friend who is not your friend. Sees level and trend only, never tags. |
| **School** | A verified academic email domain. Everyone at the school sees the school's number and their own trend against it. Nobody is ranked. |
| **Status** | Per person, per day: the day's pass count plus a three-level glyph. Level thresholds in §14. |
| **Week stats** | Per person: passes this week, passes last week, trend (improvement vs own last week), clean days (days with zero passes), gates held (block hits that led to neither a wait start nor a free pass within `gate.resumeWindow`; the user walked away). |

## 5. The gate

**G-1.** Tapping a blocked app shows the system shield with Toll's words (§10). The shield MUST offer "Open Toll" and "Dismiss".

**G-2.** "Open Toll" opens Toll. On iOS 26.5+ the shield action returns `.openParentalControlsApp`, which opens Toll directly. Below 26.5 the action posts a local notification; tapping it opens Toll. In both cases the shield action first writes the tapped token and a timestamp to the App Group so Toll knows which block it is entering (§6). If notification permission is off on a pre-26.5 device, the shield subtitle says "Open Toll from your home screen."

**G-3.** When Toll opens from a shield (notification tap or home-screen open within `gate.resumeWindow` of a `block_hit`), it enters the gate for that block:
- If a free pass remains today → `pass(free)` immediately and the session picker (G-6) is shown at once. No wait screen.
- Else → start a wait (G-4).

**G-3a. Naming.** If the app ref has no tag, the wait card asks "Which app is this?" with the tag chips above Cancel, once. The wait runs meanwhile; answering is not required to pass. The device never needs the tag for its own display: the system renders real names and icons via `Label(token)` everywhere in Toll and on the shield. The tag exists only for what friends see, and because tags are stored by app ref (§4), a wrong or skipped tag is fixed from the block editor and the fix applies to history.

**G-4. Wait.** Duration = `gate.waits[n]` where `n` is the number of waited passes already taken today (capped at the last value). Duration is fixed at start. The wait MUST continue if Toll is backgrounded or killed: end time is persisted; on return Toll computes remaining from the clock. The wait MUST work offline. The wait is shown only inside Toll (Home overlay). No lock-screen countdown, no notification at the end. The user comes back when they come back.

**G-5.** One open request at a time. A second block hit during a wait joins the same wait (it does not reset or extend). Leaving the gate screen does not abandon the wait; only the user tapping "Cancel" does, which records `wait_abandoned`.

**G-6. Session.** When the wait ends and the user is in Toll, Toll shows the session choice (`gate.sessionMinutes`) and unlocks that block only: the token is removed from the shield set and a DeviceActivity session is started with a usage-threshold event of the chosen minutes inside a `gate.sessionWindowMinutes` interval. The session ends, and the token is re-shielded, on whichever comes first: the threshold callback, the interval end, or Toll next running (foreground, or any extension wake) after the persisted expiry. Callbacks can be late or missing; the persisted expiry is the truth. A session cannot be extended; a new request follows it.

**G-7.** Every pass is recorded (`pass`, tag, time, free/waited, wait minutes). Friends see it on their next open. No push.

**G-7a. Schedules.** A block's shield is applied at the start of its schedule window and removed at the end by a DeviceActivity schedule (§6); `always` is a single always-on shield. A session (G-6) that outlives the window simply ends with it. Changing a schedule records `block_changed`; a change that reduces coverage (shorter window, fewer days, or always → anything) is pinned for friends like a removal (N-5).

**G-8.** The gate never dead-ends. Any failure (extension crash, missing token, clock skew) MUST fall back to: shield stays up, Toll shows the block and a working path through it. A user MUST always be able to reach Settings → Blocks and remove a block (recorded and visible to friends).

**G-9.** Clock integrity: waits use monotonic time where available plus wall-clock; if wall-clock jumps backward by more than `gate.clockSkewTolerance`, the wait end is recomputed from monotonic elapsed time, not shortened.

**G-10. Toll opens.** Toll counts its own foreground opens per day and shows the number on Home ("You opened Toll 14 times today").

**Levers** (values in §14): free passes per day; wait ladder; day reset hour; session lengths.

## 6. What the platform forces

Facts about Apple's Screen Time APIs that shape the build. Verified 8 November 2026; sources in §18.

- **Shield → Toll.** Until May 2026 a shield's buttons could only close, defer, or do nothing; the supported route into the host app was a local notification the user taps, and Apple engineers said so repeatedly. iOS 26.5 added `ShieldActionResponse.openParentalControlsApp`, which opens the shielding app directly. Its behaviour under individual (non-family) authorization is undocumented, so it is verified on hardware in week 1 and gated behind `#available(iOS 26.5, *)`; the notification route stays as the fallback. The shield extension receives only an opaque token, so it writes that token to the App Group before responding. Competing apps: one sec uses the notification route; Jomo and ScreenZen appear to open directly by means they have not described; a developer using a private launch method (`LSApplicationWorkspace`) was rejected under 2.5.1 in May 2026. Toll never ships a private method.
- **Notification-route pitfalls.** Needs notification permission; delivery can be delayed ~10 s by notification prioritization; Focus modes can suppress it; it is two taps. The shield action delays its `.defer` response ~0.4 s so the notification registers.
- **Tokens are opaque.** The main app cannot read which app a token is; `Label(token)` renders the icon and name as a view the app cannot read as text. The ShieldConfiguration extension does receive the display name but is sandboxed from exporting it (App Group writes from it are ignored on device, and attempting it is a 2.5.1 risk). Tags come from the user. This is final.
- **No minutes.** Toll cannot read screen-time usage. All social data comes from gate events Toll records itself. Do not add the iOS 26.4 "App and Website Usage" capability: it changes the permission prompt to an all-or-nothing usage disclosure.
- **No revocation signal.** Toll cannot observe the permission being turned off or the app being deleted. The daily `checkin` is how silence is seen (N-9).
- **Schedules.** A block's window is a repeating `DeviceActivitySchedule`; `intervalDidStart` applies the shield, `intervalDidEnd` removes it. The same lateness caveats apply, so the app also reconciles shields against schedules on every launch and foreground. Up to 20 concurrent activities per app: `blocks.max` of 8 blocks plus sessions fits.
- **Sessions.** `DeviceActivitySchedule` intervals must be ≥ 15 minutes (max 1 week; 20 concurrent activities). Usage-threshold events can fire late, not at all, or spuriously (iOS 26 phantom thresholds acknowledged by Apple). Persist the session expiry in the App Group and re-check on every launch and foreground; `stopMonitoring` then `startMonitoring` synthesizes `intervalDidEnd`.
- **Extensions.** DeviceActivityMonitor has a ~6 MB memory limit. Shield extensions are re-instantiated per call, keep no state, have no network, and must return fast or the system draws the default shield. SwiftData/SQLite in the App Group fails inside ShieldConfiguration. Extensions therefore append JSON lines to a spool file in the App Group (with `NSFileCoordinator`); the app ingests.
- **Shield limit.** More than 50 app + web-domain tokens across all named stores shields nothing. Toll caps tokens at `blocks.maxTokens` (40) and shows the limit.
- **Entitlement.** One Family Controls (Distribution) request per bundle identifier: the app and each of the three extensions. Reported turnaround is four business days to several weeks. Required before any TestFlight upload. The development entitlement works meanwhile. Justification: a personal self-control tool on the user's own device; no usage data read or transmitted. File all four now.
- **Rule 4.10** forbids monetizing the phone's screen-time controls. Toll charges time, never money. The listing and review notes say so.
- **Also required by review:** in-app account deletion including Apple token revocation; a privacy policy; report and block for user-written display names (1.2 UGC); privacy nutrition labels that list gate events as collected and linked to the account; the 2026 age-rating questionnaire (16+ tier). Keep to shields; "hiding" apps via `blockedApplications` has drawn 2.5.1 rejections.

Minimum iOS version and targets: §11.1.

## 7. The network

**N-1. Shape.** There are no groups. There is you, your friends, your mutuals, and your school. Everything social is passive. A person never receives anything from Toll on another's behalf and never has to act.

**N-2. Friends** are mutual: one sends a request, the other accepts. Friends see each other's week: passes this week next to last week, trend, clean days, today's status, tagged blocks with their schedule label ("Instagram · nights"), and the list of passes for today and yesterday.

**N-3. Ordering.** Friends are ordered by improvement against their own last week (best improvement first), never by level. Ties by name.

**N-4. Shared number.** "Your friends held 83 percent of gates this week" = gates held ÷ block hits across all friends including you, this week.

**N-5. Pinned.** A removed block ("Adi removed Instagram from his blocklist") or a loosened schedule ("Adi's Instagram block is now nights only") is pinned at the top of the friends list for `network.pinHours`. Silence (N-9) is pinned while it lasts.

**N-6. Visibility is mutual.** You see a friend's week only if they can see yours. A solo user sees nothing social and shows nothing.

**N-7. Mutuals** are friends of friends who are not your friends, shown as "friends with Adi and 2 others" with status level and trend only. Never tags, never pass lists. One tap sends a friend request.

**N-8. School.** Verified by an academic email domain (allowlist in §11.3). Members see the school's number (gates held % and median passes/week) and their own trend against it, and can find mutuals at their school. Nobody is ranked. School aggregates are only shown when the school has at least `network.schoolMinMembers` active members this week.

**N-9. Silence.** A device sends `checkin` once a day when blocks are on. `network.silenceMissedCheckins` consecutive missed check-ins while blocks were on → friends see "Toll has been off on Adi's phone since Tuesday". Covers both permission revoked and app deleted. Clears on the next check-in.

**N-10. Naming apps.** Names are asked once per app at its first wait (G-3a), never at setup. Friends see the tag; mutuals never see names; untagged is "a blocked app". Block names are never shown to anyone.

**N-11. Finding people.** Invite link (universal link with a code) sent outside Toll; mutuals; same school; contacts matching (N-12).

**N-12. Contacts matching** (in only if ≤ 1 engineering day): the user grants Contacts access once; the device hashes normalized phone numbers and emails (SHA-256, salted per deployment) and asks the server which hashes belong to accounts that opted in. Raw contacts never leave the device. Matches appear as "In your contacts" with a request button. Opt-in for being discoverable is a Settings toggle, default on, stated at signup.

**N-13. Notifications.** The complete list of everything Toll may put on a lock screen:
1. The daily summary: one optional push a day at `notify.hour` local with yesterday's count and position among friends (the N-3 improvement order, counting yourself), same sentence good or bad. If friend requests are waiting, the sentence ends with the count. On by default once notification permission is granted; off in Settings.
2. The shield-route local notification ("Open Toll"), only on devices below iOS 26.5, only when the user has just tapped "Open Toll" on a shield. It is a mechanism, not a message.
3. Silent background pushes that refresh data and show nothing.
Nothing else, ever: no friend-request alert, no wait-ended alert, no removed-block alert, no silence alert, no reminders. Everything social is seen on the next open. It is a server push (§11.3) because the position is server-side. Nothing else, ever, except silent background pushes that only refresh data. The feed is a record, not an alert.

**N-14. Opting out.** Remove the friend. Leave the school. Block a person (hides them from you and you from them everywhere, including mutuals). Nothing softer.

**N-15. Report.** Any person can be reported from their row (reason list + optional text). Reports go to a founder inbox. Required by Apple for user-written display names.

**N-16. Identity.** Display name, `@handle` and photo are set at sign-up (Set up 1) and shown to friends and mutuals; a stranger at the school sees display name and handle. Photos are user content: stored in R2, served through the API, removable by report (N-15). Handles are the future basis for user search (ledgered C22), not built in 0.1; the invite link remains the way in.

**N-17. Find your friends.** The last setup step for an account with no friends and no school: invite code or link, contacts (if built), school email, with Done and Skip beneath it. Shown once; the same actions live in People forever. Never a popup.

## 8. Screens and navigation

Detail in `toll-design.md`. Summary:

- **Home** — top: you (today's count + glyph, week vs last week, a 7-day strip). Then pinned items, then friends ordered per N-3, scrollable. Footer: the Toll-opens count. Device-state lines at the very top when needed: "Screen Time is off · Fix", "Blocks need re-picking · Fix", or (no blocks yet) "Nothing blocked yet · Add apps". When a session is active, one line at the top states it. When a wait is running, an overlay card sits above Home content: block tag, time remaining, Cancel; when the wait ends in-app the card becomes the session picker.
- **People** — requests, friends (same N-3 order as Home), mutuals, school, "In your contacts" (if built), invite. Reached from Home.
- **Friend detail** (sheet) — the friend's week, today and yesterday, tagged blocks; remove / block / report.
- **Invite** (sheet) — the user's code and a share link.
- **Blocks** — one row per block: the apps' icons and names (system labels), the schedule beneath. Tap a row to edit apps or schedule; swipe to remove. "Add a block" → picker → When chips → Done. Limit state at `blocks.maxTokens`. Reached from Settings, Home's empty state and the gate.
- **Insights** — per `toll-insights-spec.md`. Reached from Home.
- **Settings** — account, school, notifications (daily summary toggle and hour), discoverability, blocks shortcut, data (export, delete account), about (privacy policy, terms, support address, version), donation link (last group).
- **Gate** — the wait overlay on Home and the session picker it turns into.

Navigation: a standard tab bar with Home · Insights · People. Settings is a bar item on Home; Blocks is reached from Settings, from Home's empty state, and from the gate. Every destination is one tap from every other. (Decided in design review, 8 Nov; replaces the original "one screen, no tab bar".)

## 9. Onboarding and setup

Two separate things, routed by state: **Welcome** (who are you) and **Set up** (this phone, and the account if it is new). An account is server state; permission and blocks are device state; identity is account state. Any of them can be missing independently.

**Routing on launch.** O-1. If the Keychain holds a valid session → skip Welcome. (Keychain survives uninstall on iOS.) O-2. Else show Welcome. O-3. If signed in and the account has no identity → Set up 1 (You). O-4. If the device has no Screen Time authorization or no blocks → Set up 2 (Permissions) and Set up 3 (Blocks). O-5. If signed in and the account has no friends and no school and the step has not been shown → Set up 4 (Find your friends). O-6. Home.

**Welcome.** The mark and the name, nothing else, then Continue with Apple · Continue with email · Continue without an account, and the legal line beneath ("By continuing you confirm you're 16 or older and agree to the Terms and Privacy Policy"). An invite code captured from a universal link is kept through all of this.

**Email sign-in** (two screens, pushed). "What's your email?" → "Enter the code": six boxes, autofilled from Mail (`textContentType = .oneTimeCode`), Resend. No passwords exist in Toll.

**Set up** (progress bar of three; solo users and returning accounts skip step 1 and see a bar of two):
1. **You.** Photo (optional, tap the circle), Name (prefilled from Apple when available), Handle (suggested from the name, live availability check). Continue.
2. **Permissions.** "Toll needs two things": two icon rows and one Allow button that runs both system sheets. There is no skip: Toll cannot work without Screen Time. Denied → the row reads Denied, one line says why, the button becomes Try again; after the system stops prompting, Try again opens the Settings app. Notifications denied is fine: the shield fallback copy turns on and the daily summary stays off.
3. **Block these.** The fast creator: the screen arrives with an empty apps card whose one row is "Choose apps", which opens the picker (the picker never opens by itself: a system sheet nobody asked for hides the screen it belongs to); back on the screen the chosen apps are listed with Choose more, then the When tiles (Always preselected), then Done with "Add another block" beneath it. Add another saves the block as a compact row above the creator and empties the card for the next one. Tagging and block names are not here; both happen later (G-3a, New block). Returning users see "Block these again".
4. **Find your friends** (signed-in accounts with no friends and no school): invite code or link (prefilled if captured), contacts, school email; Done, with Skip directly beneath it. A full step, not a sheet.

**Layout rule.** Every screen after Welcome puts its title at the same position (28 pt under the 44 pt bar). Steps push and pop with the system transition; sheets (Custom hours, Friend detail, Invite) rise over the current screen and never replace it. Every user choice at every node is drawn in `toll-user-flows.md`.

**Paths this produces.**

| Who | Screens |
|---|---|
| New, solo | Welcome → Permissions → Blocks → Home |
| New, signed in | Welcome (Apple, or email + code) → You → Permissions → Block these → Find your friends → Home |
| New, from an invite link | Same as above; Find your friends opens with the code prefilled and the request already sent |
| Returning, reinstalled or new phone, no session | Welcome (sign in) → Permissions → Block these again → Home |
| Returning, session in Keychain | Permissions → Block these again → Home |
| Solo user who later signs in | Settings or People → sign in → You → history uploads (A2) |
| Permission revoked or tokens expired while installed | Not onboarding: Home shows "Screen Time is off · Fix" or "Blocks need re-picking · Fix" |

Three system prompts on the core path: Screen Time, notifications, app picker. Sign in with Apple, Contacts and the photo picker add a sheet only when chosen.

## 10. Words in the app

Every line is a fact, a number, or a question. No adjectives about the user. No encouragement, no lecture. The same line for the person doing well and badly; only the numbers change.

| Where | Line |
|---|---|
| Shield | "Instagram is blocked." Subtitle: "You've unblocked this 2 times today." Buttons: "Open Toll" · "Dismiss". If notifications are off: "Open Toll from your home screen." |
| Home, you | "3 passes today" with the glyph. Beneath: "11 this week · 17 last week". |
| Home, footer | "You opened Toll 14 times today." |
| Home, session active | "Instagram is open · ends after 10 min of use." |
| Wait overlay | Title "Instagram". Countdown "2:41". Beneath: "Wait 3 of today · next wait 8 min". Button: "Cancel". |
| Session picker | "How long?" Chips: "5 min · 10 min · 15 min". Button: "Open Instagram". |
| Friend row, pass | "Opened Instagram at 11:40 p.m. after a 5-minute wait" |
| Friend row, free | "Opened Instagram at 9:10 a.m. (free pass)" |
| Friend row, clean | "0 passes today" |
| Friend row, silent | "Toll has been off since Tuesday" |
| Mutual row | "friends with Adi and 2 others" |
| Pinned, removal | "Adi removed Instagram from his blocklist." |
| Pinned, silence | "Toll has been off on Adi's phone since Tuesday." |
| Friends number | "Your friends held 83% of gates this week." Short form in the Friends header: "held 83% this week". |
| Daily notification | "4 passes yesterday. 2nd of 6 friends." With a pending request: "4 passes yesterday. 2nd of 6 friends. 1 friend request waiting." |
| Welcome | "Toll". Legal: "By continuing you confirm you're 16 or older and agree to the Terms and Privacy Policy." |
| Store listing, cost | "The first wait is 3 minutes. Each one after it is longer. Nothing shortens it." (listing and website, not in-app) |
| Email | "What's your email?" Button: "Send code". Line: "A 6-digit code, no password." |
| Code | "Enter the code" · "Sent to adit@uwaterloo.ca" · "Resend code" |
| You | "You". Fields: "Name", "Handle". Line: "Friends find you by handle. Both can be changed in Settings." |
| Permissions screen | "Toll needs two things". Rows: "Screen Time" · "Notifications". Button: "Allow". Denied: row "Denied", line "Toll can't block anything without Screen Time.", button "Try again". |
| Block these (setup) | "Block these" · "Choose more" · When tiles · "Done" · "Add another block". |
| New block | "New block" · "Choose more" · Line under the apps: "Names on the right are what friends see. Tap to change." · When: "Always · every day", "Nights · 11 pm – 7 am", "Weekdays · 9 am – 5 pm", "Custom · pick times" · "Block name" (caption "Optional. Only you see it.") · "Done". |
| Find your friends | "Find your friends". Groups: Invite code, Contacts, School. Buttons: "Done" · "Skip". |
| First wait, naming | "Which app is this?" Beneath: "Friends see the name. Change it any time from Blocks." Then the tag chips. |
| Blocks row | "Instagram, TikTok, YouTube" beneath "Always"; "Reddit, Snapchat" beneath "Nights · 11 pm – 7 am". Button: "Add a block". |
| Pinned, schedule loosened | "Adi's Instagram block is now nights only." |
| Welcome buttons | "Continue with Apple" · "Continue with email" · "Continue without an account" |
| Your blocks, returning | "Block these again". No line. |
| Friends step | "Find your friends." No body. |
| Home, device state | "Screen Time is off · Fix" · "Blocks need re-picking · Fix" · "Nothing blocked yet · Add apps" |
| Before Screen Time prompt | "The next screen is Apple's. It lets Toll block apps on this phone." |
| Screen Time denied | "Toll can't block anything without this." Buttons: "Try again" · "Skip for now". |
| Before notification prompt | "This is how the block screen reaches Toll." |
| Blocks header | "Removing a block is shown to your friends." |
| Blocks at limit | "40 apps is the most this phone allows." |
| Remove block confirm | "Remove Instagram? Your friends will see this." Buttons: "Remove" · "Keep". |
| Invite caption | "Friends who install from this link are added when they accept." |
| Empty friends | "No friends yet." Button: "Send an invite". |
| School below minimum | "Not enough people at your school yet." |
| Store listing, first screen | Lead with time and friends. Write during build. |

## 11. Architecture

Chosen for a small senior team, agentic tooling, speed, and no over-engineering. Every choice below is conventional and well documented.

### 11.1 iOS

| Decision | Choice | Reason |
|---|---|---|
| Deployment target | **iOS 18.0** | ~97% of iPhones (Apple: iOS 26 79% + iOS 18 14%, June 2026; TelemetryDeck Oct 2026: 27+26+18 ≈ 98%). Gives `@Observable` (17+), Swift Charts (16+), SwiftUI 18 APIs. Going to 17 adds ~1% of users for a second QA target; 16 adds another ~1% and loses `@Observable`; going to 26 only removes pre-Liquid-Glass QA and loses ~7–10% today. |
| Toolchain | Xcode 26 / iOS 26 SDK, Swift 6 strict concurrency | Required for App Store Connect since April 2026. |
| UI | SwiftUI. One `@MainActor @Observable` view model per screen holding UI state only; services injected via `init`; `@Environment` only for app-wide singletons. | Current Apple practice; testable; no framework. |
| Dependency injection | A `Dependencies` struct of protocol-typed services with `.live`, `.preview`, `.test` factories. | No DI library. |
| Persistence (app) | **GRDB 7** (SQLite). Explicit migrations, `ValueObservation` for live screens. | Append-only event log with aggregations; SwiftData's concurrency behaviour is still a liability in 2026. |
| Persistence (extensions) | JSON-lines spool file in the App Group written with `NSFileCoordinator`; read-only config in `UserDefaults(suiteName:)`. | A shared SQLite file between app and extensions risks `0xdead10cc` suspension kills. |
| Concurrency | `actor` for the store and sync engine; `@MainActor` view models; structured concurrency only. | |
| Targets | `Toll` (app), `TollShieldConfig` (ShieldConfigurationDataSource), `TollShieldAction` (ShieldActionDelegate), `TollMonitor` (DeviceActivityMonitor). | Four Family Controls entitlements. |
| Packages (local SPM) | `TollCore` (domain model, event types, pure logic: day/week math, status levels, metrics engine, config) · `TollData` (GRDB store, spool ingest, outbox, API client, Keychain) · `TollUI` (tokens, components, charts) · `TollFeatures` (one folder per screen). App and extensions depend on `TollCore` only where needed; extensions never import `TollData`. | Clear module boundaries help agents; `swift test` per package. |
| Keychain | Session token, device id. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Small wrapper, no library. | |
| Screen Time | `FamilyControls` individual authorization; one `ManagedSettingsStore(named: "blocks")`; tokens kept in a `FamilyActivitySelection` persisted in the App Group; `DeviceActivityCenter` for the daily check-in schedule and per-session threshold activities. | |
| Networking | `URLSession` + `Codable`; one `APIClient` actor; all requests carry the session token and an idempotency key where they write. | |
| Charts | Swift Charts. | |
| Sharing | `ImageRenderer` + `ShareLink` with `Transferable` (`FileRepresentation` PNG) and `SharePreview`. | |

**Gate implementation notes.**

- `TollShieldAction`: on primary button → append `{type: "block_hit", token, at}` to the spool, then `.openParentalControlsApp` (26.5+) or post a local notification and `.defer` after ~0.4 s. On secondary → `.close`. Nothing else runs here.
- `TollShieldConfig`: returns the configuration from App Group config (tag counts for the subtitle, notification-permission flag for the fallback subtitle). Must return in milliseconds.
- `TollMonitor`: `intervalDidStart`/`intervalDidEnd` for the daily `checkin` activity (writes a `checkin` line); `eventDidReachThreshold` and `intervalDidEnd` for session activities (re-shield the token, write `session_ended`). Keep it under 6 MB: no GRDB, no large imports.
- App launch and foreground: ingest the spool into GRDB; if a `block_hit` is within `gate.resumeWindow`, enter the gate; re-shield any session whose expiry has passed; flush the outbox.
- The daily summary is a server push (§11.3), not a local notification, because position among friends is server-side.

### 11.2 Backend (Cloudflare)

| Component | Choice | Reason |
|---|---|---|
| Runtime | Workers + **Hono** + TypeScript + Zod | Conventional, fast, agents know it. Workers Paid ($5/month) from day one for CPU time and subrequests. |
| Database | **D1**, single database, **Drizzle ORM**, `drizzle-kit` migrations applied by CI (`wrangler d1 migrations apply`), additive-only migrations | Relational friend graph; 10 GB and 25B row reads/month is years of headroom; Time Travel (30 days) for restore. Single-threaded per database: use `batch()` for multi-statement writes. |
| Sessions | Opaque 32-byte tokens, hashed, in D1 `sessions`, 90-day sliding expiry | One indexed read; immediate revocation on account deletion. No JWT access tokens. |
| Auth | Hand-rolled: Sign in with Apple id-token verification with `jose` (`createRemoteJWKSet` on Apple's JWKS, check `iss`, `aud` = bundle id, `exp`, `nonce`); email **6-digit OTP via Resend** (free tier covers launch) | Two providers only; ~300 lines; avoids auth-library schema lock-in. Exchange the Apple authorization code at sign-in and store the refresh token for revocation on delete. |
| Push | Direct `fetch` to APNs (`api.push.apple.com`) with a WebCrypto ES256 JWT from the `.p8` key, cached 50 min; fan-out through **Queues** (batches of 100, ≤ 6 concurrent connections) | Proven on production Workers. Does not work under `wrangler dev` (no HTTP/2 locally): test against a deployed preview Worker. Used only for the daily summary and for silent sync pushes. |
| Jobs | **Cron Triggers**: hourly "daily summary" dispatch (send to users whose local hour is `notify.hour`); nightly rollups and school aggregates; nightly retention prune; weekly D1 export to **R2** | Free, 15-minute wall time. |
| Config / flags | One JSON document in **KV** (`config:v1`), fetched by the app at launch, cached 5 min, keyed by app version | No flag service. |
| Rate limiting | Workers Rate Limiting binding, keyed by user id (IP for unauthenticated OTP endpoints) | OTP send, friend requests, event ingest. |
| Secrets | `wrangler secret put`: APNs key, Apple client secret key, Resend key | |
| Observability | Sentry (`@sentry/cloudflare`) for errors; Workers Logs for request logs | |
| Not used | Durable Objects, Hyperdrive/Postgres, read replicas, WebSockets, multiple Workers, GraphQL | Not needed at this scale. |

**API surface (v1).** All JSON, bearer session token unless noted. Writes carry `Idempotency-Key`.

- Auth: `POST /auth/apple` · `POST /auth/email/start` · `POST /auth/email/verify` · `POST /auth/logout` · `DELETE /account` (revokes Apple token, deletes rows, tombstones the Apple subject hash)
- Me: `GET /me` · `PATCH /me` (display name, handle, discoverable, timezone, exam weeks) · `GET /handles/:handle/available` · `PUT /me/photo` (multipart, ≤ 2 MB in, resized server-side) · `DELETE /me/photo` · `PUT /devices` (push token, timezone)
- Apps and blocks: `PUT /apps/:appRef` (tag) · `PUT /blocks/:blockRef` (schedule; name is device-only and never sent)
- Events: `POST /events` (batch ≤ 100; `INSERT … ON CONFLICT(event_id) DO NOTHING`; returns accepted ids)
- Home: `GET /home` (my rollups; friends' rollups, today/yesterday pass lists, status; pinned items; the friends number)
- People: `GET /people` (friends, requests, mutuals) · `POST /friends/requests` · `POST /friends/requests/:id/accept` · `POST /friends/requests/:id/decline` · `DELETE /friends/:userId`
- Invites: `POST /invites` · `GET /invites/:code` (public; returns display name only)
- Contacts: `POST /contacts/match` (hashes in → matching user ids out, only for users with `discoverable = true`)
- School: `POST /school/start` · `POST /school/verify` · `DELETE /school` · `GET /school` (aggregate)
- Safety: `POST /blocks/:userId` · `DELETE /blocks/:userId` · `POST /reports`
- Insights: `GET /insights/friends?week=` · `GET /insights/school?week=`
- Config: `GET /config` (public, cached)

**Data model (D1).** `users` (display_name, handle UNIQUE, photo_key, handle_changed_at) · `auth_identities` (apple sub hash / email hash) · `sessions` · `devices` · `invites` · `friendships` (lower/higher user id pair, status: requested/accepted, requested_by) · `person_blocks` · `reports` · `schools` (domain suffix, name, country — vendored from the Hipo list filtered to CA/US/GB) · `school_memberships` (user, school, email hash, verified_at) · `app_refs` (user, app_ref, tag, updated_at — the only place a tag lives) · `blocks_meta` (user, block_ref, schedule, name — name never served to others) · `events` (event_id PK, user, device, type, app_ref, occurred_at, tz_offset, received_at, wait_minutes, free; tag resolved by join at read time) · `rollups_daily` (user, day, passes, free, waited, hits, held, wait_minutes, level; Toll opens stay on device) · `rollups_weekly` (user, week, same + clean_days, trend) · `hour_histograms` (user, week, 24 ints) · `school_rollups_weekly` · `exam_weeks` (user, week) · `contact_hashes` (user, hash) · `tombstones` (apple sub hash). Server time (`received_at`) is authoritative for ordering; device time and offset are kept for display. Events skewed more than 7 days are rejected. Raw events are pruned after 90 days; rollups are kept.

**Visibility enforcement** lives in one place: a `visibility.ts` module that, given viewer and subject, returns `none | mutual | friend`, consulting friendships and person blocks. Every read of another person's data goes through it.

### 11.3 Daily summary path

Cron (hourly) → select users whose local hour is `notify.hour` and whose notification is on → compute yesterday's count and position among friends → enqueue → consumer sends an APNs alert with the sentence (§10). The app shows it as-is; nothing is computed on device. If the push fails or the device has no token, nothing is sent; there is no fallback.

### 11.4 Solo mode

No account: the app never calls the API. Everything (events, metrics, Me insights, share cards) works from GRDB. Creating an account later uploads the local event history (decision ledgered; default: upload, with one line telling the user).

## 12. Engineering standards (agentic development)

These are written to be followed by agents and reviewed by humans. Keep them short in the repo too.

**Repo.** One monorepo: `ios/` (Xcode project + local packages), `api/` (Worker), `docs/` (these specs), `CLAUDE.md` at the root (≤ 60 lines: commands, conventions, where things live, what not to touch). Each package or folder has a `README.md` ≤ 40 lines stating purpose, entry points and invariants. No generated API docs.

**Code.**
- Swift 6 strict concurrency; no `@unchecked Sendable` without a one-line reason. No force unwraps outside tests. `swift-format` with the default configuration; no SwiftLint.
- TypeScript strict; Zod schemas are the single source of request/response types; Biome for lint/format.
- Config values only in `TollConfig` / `config.ts`, never inline.
- Copy strings in one file per platform (`Copy.swift`), keyed, so the tone rules in §10 can be reviewed in one place.

**Comments.** Comments say why, not what. No narration of obvious code, no doc comments on self-describing members, no file headers, no commented-out code, no TODOs without an issue link. A function that needs a paragraph of comment is too big.

**Context hygiene (for agents).** Specs stay in `docs/` and are the source of truth; do not paste spec text into code comments. Keep files under ~300 lines; split by feature, not by type. Name things by domain terms from §4 (`GateEvent`, `Pass`, `Wait`, `Session`, `Rollup`), never by UI layer. One PR per task in §15; PR description cites the requirement ids it satisfies.

**Testing.** Tests only where logic can be wrong in ways a reviewer would not see:
- `TollCore` with Swift Testing: day/week boundaries (04:00 reset, DST change, year end), wait ladder and free-pass accounting, status levels (threshold and personalised), metrics engine against fixture event logs, spool parsing with truncated lines, outbox dedupe.
- `api/` with Vitest + `@cloudflare/vitest-pool-workers` (Miniflare D1): visibility rules, idempotent ingest, rollup math, school suffix matching, auth verification against fixture tokens, account deletion cascade.
- No UI tests, no snapshot tests, no end-to-end suites. One manual checklist for the gate on a device before each TestFlight build (E10.48).

**Observability.** OSLog `Logger` per subsystem/category with `privacy: .private` on identifiers. Sentry on iOS and the Worker (free tiers). TelemetryDeck with at most 10 named events, no identifiers (§16). No other SDKs.

**CI/CD.** Xcode Cloud for iOS: build, run package tests, TestFlight on tag. GitHub Actions (Linux) for the Worker: test, `wrangler deploy` to preview on PR and to production on main, `d1 migrations apply`. No fastlane.

**Errors.** The gate never shows an error state (G-8); it logs and falls back. Elsewhere, one inline line in `label2`, never an alert, except for destructive confirmations.

## 13. Privacy, security, App Review

- **Data minimization.** Server stores events, not content: type, tag, time, wait minutes. Never tokens, never bundle ids, never app lists beyond the user's own tags. Email and Apple subject are stored hashed; display email is kept only for OTP delivery and account recovery. Contacts are hashed on device and never stored raw.
- **Solo mode** never touches the network. Stated in the privacy policy and on the first screen.
- **Account deletion** (5.1.1(v)): Settings → Delete account → re-auth → `DELETE /account` → revoke Apple refresh token at `appleid.apple.com/auth/revoke` → delete all rows by cascade → tombstone the Apple subject hash so friend edges cannot be re-imported → sign out and wipe local data (keep nothing) → confirmation email if an email exists.
- **Report and block** (1.2): from any person's row; reports land in a D1 table and email the founders. Blocked pairs are invisible to each other everywhere, including mutual counts.
- **Privacy labels.** "Data linked to you": identifiers (user id), usage data (gate events), contact info (email, if given), contacts (hashes, if contacts matching is used). Tracking: none. No ATT prompt.
- **Age rating.** 16+ under the 2026 tiers; questionnaire answered accordingly. Age gate in onboarding: a single "I am 16 or older" confirmation (decision ledgered).
- **Review notes.** State: self-control tool on the user's own device; individual authorization; no usage data read or transmitted; getting past a block costs time, never money (4.10); test account credentials with 5 seeded friends and an 8-week history; the shield → app path is Apple's `openParentalControlsApp` with a notification fallback.
- **Security.** TLS only; session tokens in Keychain; rate limits on OTP and social writes; Zod validation on every input; no secrets in the client; Worker secrets via `wrangler secret`. D1 Time Travel plus a weekly R2 export are the backup.
- **Support.** A `support@` address in Settings → About; a founder checks it daily during exam periods (decision ledgered: who).

## 14. Configuration

All tunables. One source of truth in code (`TollConfig` / `config.ts`), overridable by remote config in KV (§11.2, E11.50) with these defaults.

| Key | Default | Note |
|---|---|---|
| `gate.freePassesPerDay` | 2 | A day of Instagram-for-messages costs nothing; a binge pays. |
| `gate.waits` | `[3, 5, 8]` minutes | Index = waited passes already taken today; last value repeats. |
| `gate.dayResetHour` | 4 | Local time. |
| `gate.sessionMinutes` | `[5, 10, 15]` | Measured in use of the app. |
| `gate.resumeWindow` | 120 s | Opening Toll within this window of a `block_hit` enters the gate for that block. |
| `gate.clockSkewTolerance` | 60 s | |
| `status.levels` | `[0–2, 3–4, 5+]` passes | Three glyph levels for the first week. |
| `status.personalise` | true | After the user's first full week, levels centre on their own median: better than usual / usual / worse. |
| `network.pinHours` | 24 | |
| `network.schoolMinMembers` | 20 | Below this, the school shows "Not enough people at your school yet." |
| `network.silenceMissedCheckins` | 2 | |
| `network.tags` | instagram, tiktok, youtube, snapchat, x, reddit, other | Fixed list; display forms in §4. |
| `identity.handleCooldownDays` | 30 | |
| `identity.photoMaxPx` | 512 | Stored as one 512 px JPEG in R2. |
| `notify.hour` | 10 | Local. The daily summary is on by default once notification permission is granted (step 4); off in Settings. |
| `gate.sessionWindowMinutes` | 60 | DeviceActivity interval that bounds a session; ≥ 15 by platform rule. |
| `blocks.maxTokens` | 40 | Platform shields nothing above 50 tokens. |
| `blocks.max` | 8 | Blocks per device; keeps DeviceActivity activities under the platform's 20. |
| `blocks.presets` | always; nights 23:00–07:00 daily; weekdays 09:00–17:00 Mon–Fri | The When chips. Custom is a window plus a day set. |
| `sync.flushIntervalSeconds` | 300 | Also on foreground and on any pass. |
| `retention.rawEventDays` | 90 | Server-side; rollups are kept. |
| `insights.*`, `share.*` | see `toll-insights-spec.md` §9 | |

## 15. Work breakdown

Epics in dependency order. Each task is one PR. "Done" means: requirement ids satisfied, tests in §12 for that logic passing, README updated if an invariant changed.

**E0. Setup (day one, in parallel with everything)**
1. Apple: bundle ids for app + 3 extensions; file four Family Controls (Distribution) requests; App Group; push key; Sign in with Apple service id. Blocks TestFlight.
2. Repo scaffold: monorepo layout, `CLAUDE.md`, package READMEs, `swift-format`, Biome, Xcode Cloud and GitHub Actions pipelines running on empty projects.
3. Cloudflare: Workers Paid, D1 database, KV namespace, Queue, R2 bucket, secrets; Hono skeleton with `/config` and `/health`; Drizzle migration 0001; Sentry on both sides.
4. Vendor school domain list into `schools` (CA/US/GB), with a script to refresh it.

**E1. Gate (TollCore + extensions)** — G-1…G-10
5. `TollCore` domain model and `TollConfig` with §14 defaults. Tests: day/week math, wait ladder, status levels.
6. App Group spool: writer (extensions) and ingester (app) with `NSFileCoordinator`; tests for truncated lines.
7. Screen Time authorization flow (individual), `FamilyActivitySelection` persistence per block, named store, shield apply/remove, schedule activities with reconciliation on launch and foreground.
8. `TollShieldConfig` with §10 copy and fallback subtitle.
9. `TollShieldAction`: spool write + `openParentalControlsApp` (26.5+) / notification fallback. **Hardware verification of 26.5 behaviour under individual authorization; file Feedback if it fails.**
10. Wait engine: persisted end time, monotonic guard (G-9), one-at-a-time, abandon.
11. Session engine: unlock, DeviceActivity threshold + window, re-shield on callback/expiry/foreground, `session_ended`.
12. Daily `checkin` activity in `TollMonitor`.
13. Gate UI: `WaitOverlay` with first-wait naming, `SessionPicker`, Toll-opens counter.

**E2. Local data and sync (TollData)**
14. GRDB schema and migrations: events, blocks (local), settings. `ValueObservation` for Home.
15. Outbox: UUIDv7 event ids, batch `POST /events`, backoff, flush triggers.
16. Keychain wrapper; `APIClient` actor with idempotency keys.

**E3. Accounts (API + app)**
17. `/auth/apple` with `jose` verification, authorization-code exchange, refresh-token storage; name prefill from the first Apple credential.
18. `/auth/email/start|verify` with Resend OTP and rate limits.
19. Sessions table and middleware; `/me`, `/devices`; handles (uniqueness, suggestion from name, cooldown); photo upload to R2 with server-side resize and the report path.
20. Account deletion end to end incl. Apple revoke, tombstone, local wipe.
21. Solo mode: run with no account; later sign-in uploads local history (ledgered default).

**E4. Network (API + app)** — N-1…N-16
22. Friendships, requests, invites, `visibility.ts`; tests.
23. Rollups: daily/weekly per user computed on ingest (incremental) and recomputed nightly; hour histograms.
24. `GET /home` with pinned items (removal pins, silence detection from check-ins).
25. Mutuals query (friends of friends minus friends minus blocks).
26. School: start/verify with suffix matching and email hashing; school weekly rollups with `schoolMinMembers` gate.
27. Person block and report endpoints; founder email on report.
28. Contacts matching (only if ≤ 1 day): hashing on device, `POST /contacts/match`, discoverability toggle.
29. App: People screen, Friend detail sheet, Invite sheet (universal link `toll.app/i/CODE`, associated domains), request flows, avatars with initials fallback.

**E5. Home and Blocks (app)**
30. Home per `toll-design.md` §4.1 with live data from GRDB + `/home` cache; pull-to-refresh.
31. Blocks screens: block rows with schedule, New block editor (picker, per-app tag column, When chips, optional name), Custom hours sheet, edit, remove with confirmation; app refs and the tag mapping; `block_added` / `block_changed` / `block_removed` events; loosened-schedule pin; token and block limits.

**E6. Onboarding (app)** — §9
32. Launch routing O-1…O-6; Welcome; email + code screens; Set up 1 (You), 2 (Permissions, no skip), 3 (fast block creator with Add another), 4 (Find your friends); returning-user title; Home device-state lines. Every path in `toll-user-flows.md` §0–§6 has a test or a manual-checklist line.
33. Universal link handling: a captured invite code survives Welcome and setup and lands prefilled on the Friends step; the request is sent on Done.

**E7. Notifications**
34. Local notification permission flow; shield fallback copy flag in App Group.
35. APNs sender (ES256 JWT, Queues consumer); `/devices` token registration; hourly cron for the daily summary; step-4 and Settings toggle and hour.

**E8. Insights and sharing** — `toll-insights-spec.md` §8
36. `MetricsEngine` in `TollCore` with fixture tests.
37. Insights Me segment (I-1…I-9).
38. Hour histograms per user-week and `GET /insights/friends`, `GET /insights/school` (rollups themselves are E4.23 and E4.26).
39. Friends and School segments (I-10…I-19).
40. Exam-week marking, local and synced.
41. Share cards: views, `ImageRenderer` pipeline, preview with appearance toggle, `ShareLink`.
42. Insights accessibility pass (labels, audio graphs, Dynamic Type).

**E9. Settings** — design doc §4.8
43. Settings: account, school, notifications, discoverability, blocks shortcut, data export (JSON of own events), delete, about, donation link.

**E10. Compliance and release**
44. Privacy policy and terms pages (Workers static assets); support address.
45. App Store listing copy and screenshots (from the mockup designs); review notes; age-rating questionnaire; privacy labels.
46. Reviewer test account seeding script (5 friends, 8 weeks of events, one school). Also serves `toll-insights-spec.md` §8 task 8.
47. TestFlight build.
48. Gate manual checklist on two devices (one on iOS 26.5+, one on 18.x); fix list.

**E11. Operations**
49. Nightly retention prune; weekly R2 export; D1 Time Travel restore rehearsal once.
50. Remote config in KV with the §14 keys; app reads at launch.
51. Dashboards: Sentry alerts; a single Worker-side `GET /admin/stats` (founders only) with installs, users with ≥ 1 friend, weekly lookers — the three numbers in §1.

## 16. Instrumentation (ours)

TelemetryDeck, anonymous, ≤ 10 events: `app_open`, `onboarding_step` (step, skipped), `screen_time_auth` (granted/denied), `block_added`, `block_removed`, `gate_entered` (free/waited), `wait_abandoned`, `friend_added` (source: invite/mutual/school/contacts), `share_card` (type, format), `account_deleted`. No user ids, no tags, no timestamps beyond TelemetryDeck's own. The product metrics in §1 come from the server, not from analytics.

## 17. Open decisions

See `toll-future-ledger.md`. Anything there that blocks a task is listed on that task. Defaults taken in this spec and awaiting confirmation are marked "(decision ledgered)".

## 18. Sources

Screen Time APIs: Apple docs for `ShieldActionResponse.openParentalControlsApp` (iOS 26.5+), `AuthorizationCenter.requestAuthorization(for:)` (iOS 16+), `Application.localizedDisplayName` (nil outside the shield extension), `ShieldConfigurationDataSource`, `ManagedSettingsStore`; Apple Developer Forums threads 719905, 766644, 793060, 804012, 820790, 728044, 716698, 762431, 733361, 783153, 729841, 820956, 823431, 779449, 838802, 820283, 776058; drobinin.com Family Controls notes; newly.app entitlement guide. iOS adoption: developer.apple.com/support/app-store (June 2026), 9to5mac (Feb 2026), telemetrydeck.com/survey (Oct 2026), gs.statcounter.com. Review: App Store Review Guidelines 1.2, 2.5.1, 4.10, 5.1.1(v); Apple account-deletion and token-revocation docs; macrumors.com on 2026 age ratings. Cloudflare: developers.cloudflare.com D1 limits/pricing/read-replication/time-travel, KV limits, Queues limits, Workers limits and pricing, rate-limit binding changelog; workerd issue 4841 (HTTP/2 to APNs); example Workers `lorislabapp/lumen-push`, `aptove/push-relay`. Auth: Apple "Verifying a user" and JWKS docs; better-auth Apple docs; wisp.blog on Lucia's deprecation; resend.com pricing and Workers guide. iOS architecture: GRDB 7 releases; mjtsai.com on SwiftData (June 2026) and on SQLite in App Group containers (May 2025); pistack.xyz persistence comparison (Aug 2026); theswiftk.it.com on Swift Testing, CI options, crash reporters; telemetrydeck.com; sentry.io iOS docs; github.com/Hipo/university-domains-list. Design: Apple HIG (materials, color, layout, typography, accessibility; Sept 2026 updates), WWDC25 session 323 notes, strv.com Liquid Glass guide, nilcoalescing.com on `ConcentricRectangle`, Swift Charts docs and fatbobman.com on binning, Apple `ImageRenderer` and `ShareLink` docs, socialsizes.io and firstpier.com on story safe zones, Okabe-Ito palette, GitHub colorblind themes, Opal community thread 8457, unstar.app and habitdoom.com screen-time app reviews (2026), blakecrosley.com on Flighty and typography systems.
