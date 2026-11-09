# App Store submission (E10.45) — draft

Listing copy is the founders' (ledger B1–B3): the thesis sentence, the first screen and the poster are left blank on purpose. Everything else below is drafted from the spec for sign-off.

## Listing

- **Name:** Toll
- **Subtitle (≤ 30):** _founders (B2)_
- **First screen / promotional text:** _founders (B1, B2)_. Lead with time and friends (spec §10).
- **Cost sentence (listing and website, never in-app):** "The first wait is 3 minutes. Each one after it is longer. Nothing shortens it."
- **Price:** Free. No in-app purchases.
- **Category:** Productivity (secondary: Health & Fitness).
- **Screenshots:** six, from the mockup canvas: Home (light), the wait card, the session picker, Block these, People, Insights · Me. 6.9" and 6.5" sizes.

## Review notes

> Toll is a self-control tool for the person using it, on their own iPhone. It uses FamilyControls individual authorization (not family), ManagedSettings shields and DeviceActivity schedules. It reads no Screen Time usage data and transmits none; it records its own events (a pass, a wait) and nothing else.
>
> Getting past a block costs time, never money (Guideline 4.10). There are no purchases of any kind.
>
> The shield's "Open Toll" button opens Toll with `ShieldActionResponse.openParentalControlsApp` on iOS 26.5 and later. Below 26.5 it posts a local notification the user taps to open Toll (the documented route). No private API is used.
>
> Test account: sign in with email **review@toll.alders.dev**; the code is **[REVIEW_CODE]** (fixed for this address only). The account has 5 friends, one school and 8 weeks of history.
>
> To see the gate: Toll → Settings → Blocked apps → Add a block → choose any app → Done. Open that app → "Open Toll". The first two opens each day are free; after that a 3-minute wait runs inside Toll, then you choose a session length.
>
> Account deletion: Settings → Delete account (re-authentication, then all data is removed and the Apple token is revoked). Report and block: long-press any person, or open them and use Report / Block.

## Privacy nutrition labels

Data linked to you:
- **Identifiers** — User ID. Purpose: App Functionality.
- **Usage Data** — Product Interaction (gate events: block hits, waits, passes, with a user-chosen app name from a fixed list). Purpose: App Functionality.
- **Contact Info** — Email Address, if the user signs in with email or Apple shares one. Purpose: App Functionality (sign-in codes, account recovery).
- **Contacts** — only if the user uses Find friends from contacts: hashed on the device; hashes are matched and not stored. Purpose: App Functionality.
- **User Content** — Photos (optional profile photo). Purpose: App Functionality.

Data not linked to you:
- **Diagnostics** — Crash Data (Sentry), and **Usage Data** — Product Interaction (TelemetryDeck: ten anonymous event names, no identifiers). Purpose: Analytics.

Tracking: none. No ATT prompt.

## Age rating

The 2026 questionnaire answered for **16+**: user-generated content limited to display names, handles and optional profile photos, visible to people the user connects with; report and block are available everywhere a person appears. No other sensitive content. In-app: the Welcome legal line confirms 16 or older (ledger A3).

## Before submitting

- [ ] Four Family Controls (Distribution) entitlements approved (`docs/apple-setup.md`).
- [ ] Privacy policy and terms signed off (`api/public/privacy.html`, `api/public/terms.html`) and live at toll.alders.dev.
- [ ] Reviewer account seeded and `REVIEW_CODE` set (`api/DEPLOY.md`).
- [ ] Gate checklist passed on both phones (`docs/gate-checklist.md`).
