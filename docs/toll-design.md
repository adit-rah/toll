# Toll — Design Doc (v0.1)

Companion to `toll-mvp-spec.md`. Covers foundations, components, every screen, and accessibility. Visual identity (wordmark, icon, final accent) is not designed yet; see `toll-brand-tbd.md`. Everything here uses a placeholder accent that swaps in one token.

## 1. Principles

1. **One question per screen.** Home answers "am I keeping my resolution, are my friends keeping theirs." Insights answers "what does the data say." Nothing on a screen competes with that question.
2. **A glance, then leave.** The person should get what they came for in under three seconds and in under three taps. No screen is a destination to linger on.
3. **Hero + list.** Every main screen is one hero fact, then a list. No grids of equal tiles. No dashboard.
4. **One accent.** Everything else is label grays and system backgrounds. Colour means something or it is not there.
5. **Numbers are the content.** Tabular numerals everywhere; weight and size make hierarchy; icons are rare.
6. **Negative space is the premium.** Larger margins, fewer elements, and restraint read as expensive. Fill nothing to fill it.
7. **System first.** Apple components, Dynamic Type, semantic colours, standard sheets and bars. Liquid Glass only on floating controls, never in content. Toll looks like it belongs on the phone.
8. **Both appearances are first-class.** Every token has a light and dark value; nothing harsh in either. Dark mode uses raised grays, never pure black cards on pure black.
9. **Facts only, in the UI as in copy.** No celebratory motion, no confetti, no red alarms. Level is shown by shape and fill before colour.

## 2. Foundations

### 2.1 Layout and composition

- **Grid:** 8 pt base. Horizontal gutter 20 pt (16 pt on 4.7"/5.4" widths). Section gap 32 pt. Intra-card padding 16 pt. Row height ≥ 52 pt.
- **Hero zone:** the hero numeral sits centred, 12 pt under the toolbar, in a zone of its own with nothing beside it: numeral + glyph, unit line, week line, then the 7-day strip (3.15). 36 pt of air before the list. Tested against the top-left "large title" placement and the upper-third placement: centred-near-top gives the breathing room without the number floating. The wait overlay's countdown numeral is centred in the card the same way.
- **Alignment:** two axes, deliberately: the hero zone is centred; everything from the first pinned row down left-aligns to the gutter, with trailing numbers right-aligned on a shared column so rows read like a departure board. Nothing else on Home is centred except the footer caption.
- **Weight falls monotonically.** One hero, then rows of equal weight. Nothing between them (no links row, no boxed card) interrupts the gradient. Navigation lives in the tab bar, never in the content.
- **Containers only where grouping needs them.** Home's list sits on the page background with hairline separators, no card. Settings and People use standard grouped lists because they have several groups.
- **Hierarchy by position:** top-leading is most important. Secondary facts sit directly beneath the hero in a single line, never beside it.
- **Containment:** group with whitespace first, separators second, cards third. Home uses whitespace + a single card (friends). Settings uses standard grouped lists.
- **Density:** max one chart per card; max ~7 rows visible before a scroll; never two accents on screen.

### 2.2 Type

SF Pro via Dynamic Type styles only. Hero numerals use `.rounded` design, semibold, `.monospacedDigit()`. All other numbers `.monospacedDigit()`.

| Token | Style | Use |
|---|---|---|
| `hero` | custom 72 pt rounded semibold, letter-spacing −2.5 (scales with `@ScaledMetric`, caps at AX2) | Today's count on Home; countdown |
| `title` | Title2 22 semibold | Section headers, screen titles in content |
| `headline` | Headline 17 semibold | Friend names, card titles |
| `body` | Body 17 regular | Rows, settings |
| `number` | Body 17 medium tabular | Trailing numbers in rows |
| `subhead` | Subheadline 15 regular, secondaryLabel | Context line under hero, row detail |
| `caption` | Footnote 13 regular, secondaryLabel | Chart captions, timestamps |
| `micro` | Caption2 11 medium, tertiaryLabel | Axis labels, glyph legends |

Rules: never more than three sizes on one screen besides axis labels; adjacent levels differ by weight before size; line length ≤ 60 characters.

### 2.3 Colour tokens

Semantic first. Custom tokens are defined in one asset catalog with light / dark / high-contrast variants.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | systemBackground `#FFFFFF` | `#000000` (system) | Screen background |
| `bgGrouped` | systemGroupedBackground `#F2F2F7` | `#000000` | Settings, People lists |
| `surface` | secondarySystemGroupedBackground `#FFFFFF` | `#1C1C1E` | Cards, rows |
| `surfaceRaised` | tertiarySystemGroupedBackground `#F2F2F7` | `#2C2C2E` | Chips, selected rows |
| `label` / `label2` / `label3` | system label tiers | system label tiers | Text |
| `separator` | system | system | Hairlines |
| `accent` | `#3A6EA5` | `#8FB4E3` | Primary action, "you" in charts, selected state. **Placeholder; swaps when identity exists.** |
| `accentSoft` | `#3A6EA5` @ 12% | `#8FB4E3` @ 18% | Late-hour shading, selected bin background |
| `neutralBar` | `#C7C7CC` | `#48484A` | "Others" / last week in charts |
| `heat1…heat5` | `#E9EEF5` → `#3A6EA5` | `#1F2A38` → `#8FB4E3` | Term heatmap, sequential |
| `level1` | `#2E8B6E` | `#5FC3A3` | Status: fewer passes than threshold/usual |
| `level2` | `#C98A1B` | `#E0B35B` | Status: around threshold/usual |
| `level3` | `#B8532C` | `#E08466` | Status: more than threshold/usual |

Level colours are Okabe-Ito derived (bluish green / orange / vermillion), desaturated for comfort; the glyph's shape carries the level without them (§3.1). Contrast: all text ≥ 4.5:1 in both modes; large hero ≥ 3:1. Verified with Increase Contrast on.

### 2.4 Shape and depth

- Corner radii: card 16, row-in-card 12 (concentric: inner = outer − padding, via `ConcentricRectangle` on iOS 26+, fixed values below), sheet 20+ matching device corners, chip 8, button 12.
- Elevation: none in light mode (flat surfaces on grouped background). Dark mode: surface tiers by lightness, no shadows.
- Materials: `.regular` material only for the wait overlay's backdrop and system bars. No glass in content.

### 2.5 Motion and haptics

Motion in Toll explains where things came from and where they went. It never celebrates, never loops, and never asks to be noticed. Three durations: 200 ms (state changes), 300 ms (things moving), 450 ms (things appearing for the first time). One spring: response 0.35, damping 0.85, no overshoot beyond 2%. Reduce Motion replaces every move or scale with a crossfade of the same duration; numeric transitions stay.

| Moment | Motion |
|---|---|
| Any step push | The system navigation transition. The progress segment fills left to right over 250 ms as the new screen lands, not before. |
| Returning from the app picker | The apps card is already in place; its rows fade in and rise 6 pt with a 40 ms stagger, once. A second return adds only the new rows the same way. |
| Selecting a When tile | Fill crossfades 200 ms; the tile scales 0.98 → 1 on release. The previously selected tile fades out its fill, nothing else moves. |
| Add another block | The creator's apps card shrinks into the compact row above (`matchedGeometryEffect` on the icon cluster and names), 300 ms; the picker rises as that lands. |
| Welcome → sign-in sheet | System sheet. On success the sheet drops and the next step pushes in one motion; no intermediate blank. |
| Code boxes | The active ring moves to the next box 150 ms; a wrong code shakes the row ±6 pt twice over 300 ms and the boxes clear on the way back; a correct sixth digit pushes the next screen with no button. |
| Handle availability | The check mark fades in 200 ms after the server answers; never a spinner for under 300 ms. |
| Home, first appearance | Hero numeral and glyph fade in together, then the week strip bars grow from the baseline 450 ms with a 30 ms stagger, then the list rows fade in with a 25 ms stagger. Total under 900 ms. Only on cold launch; returning from a tab is instant. |
| Hero number changes | `contentTransition(.numericText())`, 300 ms. The glyph crossfades between levels. |
| Friend order changes on refresh | Rows move to their new positions, 300 ms, with stable ids; new rows fade in; nothing bounces. |
| A pinned line arrives | Slides down from under the hero zone with opacity, 300 ms, pushing the list down. Expiry fades it out and the list closes up. |
| Device-state line | Same as pinned. Clearing it (Fix succeeded) collapses it 200 ms. |
| Wait overlay appears | Backdrop blur ramps 200 ms; the card rises 24 pt into place with the spring. Countdown digits use `numericText`; the colon never blinks. |
| Naming chips at the first wait | Appear with the card; on a tap the chosen chip fills, the others fade 200 ms, the section's height collapses 300 ms and the hairline goes with it. |
| Wait reaches 0 in app | The card keeps its frame; the countdown crossfades into "How long?" and the chips fade in beneath, 300 ms; `.light` haptic once. |
| Open the app from the session picker | The card drops 24 pt and fades 200 ms while the system switches apps. |
| Session line on Home | Appears and leaves like a pinned line. |
| Shield (system) | No Toll motion; Apple animates the shield. |
| Friend detail, Invite, Custom hours | System sheets with their own detents and spring. |
| Insights charts, first appearance | Bars grow from the baseline 450 ms with a 20 ms stagger; lines draw left to right 450 ms; the heatmap fades in by row. Only on first appearance per session; segment switches crossfade 200 ms. |
| Chart selection | The callout fades and rises 4 pt, 200 ms; it leaves on scroll with a 150 ms fade. |
| Share preview appearance toggle | Light and dark variants crossfade 300 ms. |
| Tab bar | System; minimises on scroll on iOS 26+. |
| Pull to refresh | System. New data applies with the row-move animation above. |
| Removing a block or friend | The row collapses 300 ms after the confirmation; the pin that results for friends is their motion, not yours. |

Haptics: `.light` when a wait starts and again when it ends; `.warning` on confirming a removal or a block of a person; `.selection` on When tiles and tag chips. Nothing else. No haptic on a pass being granted.

Never: confetti, pulsing, looping, parallax, bouncing rings, progress rings that fill, typewriter text, skeleton shimmer longer than 300 ms, or any motion on the shield.

### 2.6 Iconography

SF Symbols, monochrome, `.secondary` weight regular. Used only for navigation affordances: the tab bar (house, chart.bar, person.2), chevron, plus, gear, person.badge.plus, square.and.arrow.up. No icons in rows. No coloured icon circles.

### 2.7 Navigation

A standard `TabView` with three tabs: **Home · Insights · People**, `.tabBarMinimizeBehavior(.onScrollDown)` on iOS 26+, the system floating glass bar. Settings is the trailing bar item on Home; Blocks is reached from Settings, from Home's empty state, and from the gate. Every destination is one tap from every other. The tab bar is the only glass element in the app besides the wait overlay backdrop.

## 3. Components

Each component lists anatomy, states, and sizing. Names are the SwiftUI type names.

### 3.1 `StatusGlyph`

- 14 pt (row) / 20 pt (hero) circle. Level by shape and fill: **L1** filled circle; **L2** half-filled circle (left half, straight vertical split); **L3** outlined ring with a 4 pt centre dot. Colour from `level1..3`. Count is never inside the glyph; it is the adjacent number.
- Unknown/silent: dashed ring in `label3`.
- Accessibility label: "fewer than usual", "about usual", "more than usual" (personalised) or "0 to 2 passes" etc. (thresholds).

### 3.2 `HeroStat`

- Centred column: numeral `hero` with the `StatusGlyph` (20 pt) beside it, vertically centred on the numeral; beneath, the unit line `body` medium ("passes today"); beneath, the subhead line (`subhead`); optional second line (`caption`).
- States: normal; zero ("0 passes" is a fact and looks identical); loading (numeral placeholder shimmer-free: `--`).

### 3.3 `MetricPair`

- Horizontal: label (`caption`) above value (`number`), with last-period value small and `label2` to the right ("11 · 17 last week"). Used in rows of 3–4 under the hero and in Insights hero.

### 3.4 `FriendRow`

- 60 pt min height, hairline separator above (none on the first row). Leading `Avatar` 32 pt with the `StatusGlyph` as a 12 pt badge at its bottom-right (on a 16 pt `bg` disc so it reads on any photo); name `headline`; detail line `micro`-sized (12 pt, `label2`, one line, truncated with an ellipsis at ~200 pt so it never crowds the trailing column: "Opened Instagram at 11:40 p.m. after a 5-min…"); trailing column: today's count `number` with week trend beneath (`caption`, "▼ 23%" / "▲ 8%" — arrow glyph in `label2`, never coloured). The full sentence is in Friend detail.
- Tap → `FriendDetail` sheet. Long-press → context menu: Remove friend, Block, Report.
- States: normal; silent (dashed glyph, detail "Toll has been off since Tuesday"); request pending (trailing "Accept" / "Decline" quiet buttons).

### 3.5 `PinnedRow`

- Same leading geometry as `FriendRow` (52 pt min height), no background, no box: an 8 pt `accent` dot where the glyph would sit, then the line in `body` medium. Because nothing else on Home uses the accent as text decoration, this is the only accent on the page and the eye stops on it. No icon. Dismiss by swipe is not allowed in 0.1 (it expires on its own).

### 3.6 `MutualRow`

- `Avatar` with level badge + name + "friends with Adi and 2 others" (`subhead`) + trend (`caption`, "▼ 12%") + trailing "Add" quiet button. Never a count, never tags.

### 3.7 `WaitOverlay`

- Full-screen `.regular` material backdrop over Home including the tab bar (Home stays visible beneath, dimmed; tabs are not tappable while the card is up). Centred card (`bg`, hairline border, radius 20, width = screen − 2×gutter): tag name `title` ("Instagram"), countdown `hero` ("2:41"), line beneath `subhead` ("Wait 3 of today · next wait 8 min"), bottom: `QuietButton` "Cancel". Nothing else. No ring, no progress bar: the number is the progress.
- When the wait ends while in app: the card swaps to `SessionPicker` (3.8) with a `.light` haptic. A free pass shows `SessionPicker` in the same card with no countdown.
- The card sits with its top at 180 pt; the countdown is centred in it with 28 pt above and 12 pt below.

### 3.8 `SessionPicker`

- Title `title` "How long?", three `ChoiceChip`s (5 min · 10 min · 15 min), `PrimaryButton` "Open Instagram". Tapping chips selects; button confirms. Default selection: the user's last choice.

### 3.9 `TagChips` (first-wait naming)

- Inside the wait card, beneath a hairline: "Which app is this?" `subhead` medium, one `micro` line ("Friends see the name. Change it any time from Blocks."), then the seven tag chips (display forms: Instagram, TikTok, YouTube, Snapchat, X, Reddit, Other) wrapped and centred (34 pt, `surface`; selected = `accent` fill). Shown only when the token has no tag; the countdown keeps running above it. Tapping a chip stores the tag and the section fades out.

### 3.10 `BlockRow`

- One row per block, 64 pt: a cluster of up to three app icons (system `Label(token)` icons, 28 pt, overlapping by 6 pt), the app names on one line (system labels, truncated), the schedule beneath in `caption` ("Always", "Nights · 11 pm – 7 am"), chevron. Tap → edit. Swipe → "Remove" (destructive) with the confirmation from spec §10.

### 3.11 `ChartCard`

- `surface` card, 16 pt padding. Title `headline`, optional range toggle (segmented, 2 options max) top-trailing, chart, caption `caption`. Fixed heights: bars 160 pt, line 140 pt, histogram 160 pt, heatmap rows × 20 pt. Chart styles per `toll-insights-spec.md` §4.

### 3.12 Buttons

- `PrimaryButton`: full-width, 50 pt, `accent` fill, label `headline` in white (light) or `#0F1115` (dark, where the accent is light and white would fail contrast). One per screen max.
- `QuietButton`: text-only, `accent` label, `body` medium. Used for Cancel, Skip, Add.
- `DestructiveQuiet`: text-only, systemRed. Remove, Delete account.
- No icon buttons in content; nav bar uses standard bar items.

### 3.13 `EmptyState`

- One line `body` in `label2`, centred in the section's space, optional one `QuietButton`. No illustration.

### 3.14 `ShareCardView`

- 360×640 pt (story) / 360×360 pt (square) canvas; opaque `bg`; hero numeral at 96 pt rounded; one fact line; one small chart; display name (optional) top-left `caption`; wordmark bottom-left at 12 pt; date range and invite link bottom-right `caption`. Safe band: nothing in the top 90 pt or bottom 130 pt of the story format. Rendered at scale 3.

### 3.15 `WeekStrip`

- Seven 12 pt-wide bars, 6 pt apart, 28 pt tall at the week's maximum, Monday to Sunday, passes per day; today in `accent`, other days `neutralBar`, zero days a 2 pt stub. No axis, no labels, no values: it is texture that rewards a second look, not a chart. Tapping it opens Insights. Accessibility label reads the seven numbers.


### 3.16 `WhenChips`

- A 2×2 grid of 88 pt tiles, 10 pt apart: icon (infinity, moon, sun, clock), label `subhead` semibold, one `micro` line ("every day", "11 pm – 7 am", "9 am – 5 pm", "pick times"). Selected = `accent` fill with white text; others `surface`. Always is preselected. Custom opens the Custom hours screen.

### 3.17 `Avatar`

- Circle, 32 pt in rows, 40 pt in Settings, 44 pt in Friend detail, 96 pt on the You step. Photo if set, else the first letter of the name at 42% of the size, semibold, `#3A3A3C` on a muted pastel chosen by hashing the handle (six fixed tones; no saturated colours). The status badge sits at bottom-right when the row has a status. Never a coloured ring, never an online dot.

## 4. Screens

### 4.1 Home

Home tab. Nav bar: no title (the hero is the title). Bar items: trailing `gear` (Settings). Content, top to bottom, on the page background:

1. **You** (centred, no card, 12 pt below the toolbar): `HeroStat` "3" + glyph, "passes today", "11 this week · 17 last week", then `WeekStrip`. 36 pt below it the left-aligned content begins.
2. **Pinned** (if any): `PinnedRow`s.
3. **Friends** section: header row with `micro`-style uppercase label "FRIENDS" (`caption` weight medium, `label2`) and trailing `caption` "held 83% this week"; then `FriendRow`s ordered by improvement, hairlines between. Empty: `EmptyState` "No friends yet." + "Send an invite".
4. **Footer**: one centred `caption` in `label3`, "You opened Toll 14 times today.", above the tab bar. It is the last thing on the screen and the quietest.

Device-state line: when Screen Time is off, tokens have expired, or nothing is blocked, a `PinnedRow`-style line sits above everything else ("Screen Time is off · Fix"); "Fix" is the accent word and opens the system sheet or the picker. It outranks a removed-block pin because the gate does not work until it is cleared.

The tab bar floats over the bottom; content scrolls under it.

Wait running: `WaitOverlay` over all of the above. Session active: a thin `PinnedRow`-styled line at the top of Home: "Instagram is open · ends after 10 min of use." (fact; no countdown).

Refresh: pull-to-refresh syncs. Last-synced timestamp is shown only if older than 1 hour (`caption` under Friends header).

### 4.2 Shield (system-rendered)

Toll controls: title, subtitle, primary and secondary button labels, background colour, icon. Title "Instagram is blocked." Subtitle "You've unblocked this 2 times today." Primary "Open Toll" (accent), secondary "Dismiss". Background `bg` with system blur; icon = Toll app icon. If notifications are off, the subtitle becomes "Open Toll from your home screen."

### 4.3 Welcome, sign in, set up

**Title position.** Every screen after Welcome places its title 28 pt below the 44 pt bar (back button, or the progress segments), at 34 pt semibold. Fields, rows and tiles start 28 pt under the title. Primary button at the bottom; the quiet action, when there is one, directly beneath it. Steps push and pop with the system transition; the progress bar persists across the setup steps; sheets rise over the current screen.

- **Welcome** — vertically centred: the mark (placeholder ring, 56 pt) and the name at 40 pt semibold, nothing else. Bottom: Continue with Apple (system black button), Continue with email (`surface` fill), Continue without an account (quiet), and the 11 pt legal line in `label3` with Terms and Privacy Policy as links.
- **Email** — back button; "What's your email?"; a 56 pt filled field (`surface`, radius 14, 17 pt text, accent caret); the `PrimaryButton` "Send code" 12 pt beneath it, where the keyboard leaves it, never at the bottom of the screen; one `caption` beneath, centred. Keyboard is up on arrival.
- **Code** — back; "Enter the code"; `subhead` "Sent to …"; six 60 pt boxes (`surface`, radius 14, 28 pt digits, the active box ringed in `accent` with a caret); "Resend code" centred beneath. Autofills from Mail; advances on the sixth digit without a button.
- **Set up 1 · You** (signed-in, new accounts only) — "You"; 96 pt `Avatar` with an accent "+" badge to add a photo; Name field (prefilled from Apple); Handle field with a live "available" check in `level1`; `caption` "Friends find you by handle. Both can be changed in Settings."; Continue.
- **Set up 2 · Permissions** — "Toll needs two things"; two icon rows (44 pt `surface` tile with the symbol, label `headline`); one `PrimaryButton` Allow runs both system sheets. No skip. Denied state: the Screen Time row's trailing text reads Denied in `level3`, Notifications reads Allowed with a check, one `subhead` line explains, the button reads Try again.
- **Set up 3 · Block these** — the fast creator, and it never scrolls: the apps card shows at most three app rows, then a 44 pt "+N more" row (opens the full list), then Choose more; the "WHEN" label, `WhenChips` with Always preselected, Done, "Add another block" quiet beneath Done. With one compact row from Add another, everything still fits a 4.7" screen; on a second Add another the compact rows collapse to one line ("2 blocks · Always, Weekdays"). After Add another, each finished block becomes a 48 pt compact row (icon cluster, names · schedule, chevron) stacked above the creator. Returning users: title "Block these again", bar of two.
- **Set up 4 · Find your friends** — a full step on `bgGrouped`, bar of four: three groups: Invite code (field + Paste), Contacts (one row), School (field + Send code); Done; Skip quiet directly beneath it.

### 4.4 People

Grouped list. Sections: **Requests** (if any; `Avatar` without badge, name, "friends with Maya", Accept · Decline) · **Friends** (`FriendRow`s with avatars, `@handle` in `caption` after the name, week numbers, in the same improvement order as Home) · **Mutuals** (`MutualRow`s) · **In your contacts** (if contacts matching is built; `MutualRow` geometry with "Add") · **School** (one row: school name, member count, "held 71% this week" + "Find people at Waterloo" → mutuals filtered by school) · **Invite** (one row showing the user's code and a "Share invite link" `PrimaryButton`). Trailing nav item: person.badge.plus → Invite sheet.

### 4.5 Friend detail (sheet)

A large detent sheet over Home (top at ~96 pt, grabber). Header: 44 pt `Avatar`, name `title`, `caption` "@handle · friends since Oct 12"; today's count at 40 pt + glyph; a 4-up `MetricPair` row (this week, held %, waited, clean days, each with last week beside); "Today" and "Yesterday" lists of pass lines (`subhead`, 36 pt rows, hairlines); their tagged blocks as chips. Bottom: three quiet actions in `label2`, centred: Remove friend · Block · Report. Nothing older than yesterday.

### 4.6 Blocks

Grouped background. One grouped card of `BlockRow`s; caption beneath "Removing a block is shown to your friends." `PrimaryButton` "Add a block" sticky above the safe area.

**New block** — pushed; the picker opens at once; on return: the chosen apps card (system `Label(token)` icon + name, and on the right the friends-facing tag in `caption`, tappable → tag chips), a "Choose more" row, a `micro` line ("Names on the right are what friends see. Tap to change."), `WhenChips`, a "Block name" row (caption "Optional. Only you see it."), Done. Editing an existing block opens the same screen prefilled.

**Custom hours** — a sheet over New block (top at ~300 pt): "Custom" `title`, From / Until as two inline wheel pickers side by side, a 7-tile day row (40 pt tiles, selected = `accent`), Done. Choosing Custom in `WhenChips` opens it; Done returns with the Custom tile showing the chosen window.

At `blocks.maxTokens` the picker's Done is disabled and the limit line from spec §10 shows; at `blocks.max` the "Add a block" button is disabled.

### 4.7 Insights

Segmented control (Me · Friends · School) under the nav bar; vertical stack of `ChartCard`s per `toll-insights-spec.md` §3. Trailing nav item: square.and.arrow.up → share sheet with card thumbnails (3.14).

### 4.8 Settings

Grouped list. Account (40 pt `Avatar`, name, `@handle`, Edit; sign out) · School (status, change, leave) · Notifications (daily summary toggle, time) · Discoverability (contacts matching toggle) · Blocks shortcut · Data (export my data, delete account) · About (privacy policy, terms, support address, version) · **Support Toll** (donation link; last group, below the fold). Delete account is `DestructiveQuiet` with a two-step confirm.

### 4.9 Invite sheet

A half-height sheet over People: "Your code" `caption`, the code at 44 pt semibold letter-spaced 6 pt, `PrimaryButton` "Share link" (`ShareLink`), caption "Friends who install from this link are added when they accept."

### 4.10 Session picker (wait card state)

The wait card swaps its countdown for: tag name, "How long?" `subhead`, three `ChoiceChip`s (last choice selected), one `caption` "Measured in use of the app. The block returns after.", `PrimaryButton` "Open Instagram". Same card geometry as the wait so nothing jumps.

## 5. Accessibility

- Dynamic Type through AX5: rows stack vertically (glyph+name on one line, detail and number beneath) at ≥ AX1; hero capped at AX2 size.
- VoiceOver: every row reads "Adi, about usual, 3 passes today, down 23 percent on last week." Charts expose audio graphs. Countdown announces every 30 s, not every second.
- Colour: nothing conveyed by colour alone (glyph shape; arrows for trend). Verified in grayscale.
- Contrast and Increase Contrast variants for all tokens. Reduce Transparency: overlay backdrop becomes opaque `bg` at 94%.
- Touch targets ≥ 44 pt. Hit areas on chips and chart bars padded.

## 6. Mockup review

Mockups cover every screen: Home (light, dark, wait, first-wait naming, session picker), Shield, Welcome, Email, Code, the four setup steps (plus the denied, add-another and returning-user states), Blocks, New block, Custom hours, People, Friend detail, Invite, Blocks, Settings, Insights Me/Friends/School, Share card (story, light + dark), plus two kept Home explorations (one-line rows; "you as a row in the list"). Each phone screen is a 390×844 artboard at 1×. Decisions from review, 8 Nov: centred hero near the top; tab bar instead of in-content links; list on the page, no card; pinned line as a dot, not a box; detail lines at 13 pt with early truncation; week strip under the hero; Toll-opens count as the footer.
