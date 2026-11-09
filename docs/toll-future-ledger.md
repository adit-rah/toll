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
