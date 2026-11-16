# Toll — Design Doc (v0.1)

Companion to `toll-mvp-spec.md`. Covers foundations, components, every screen, and accessibility. Visual identity (wordmark, icon, final accent) is not designed yet; see `toll-brand-tbd.md`. Everything here uses a placeholder accent that swaps in one token.

## 1. Principles

1. **One question per screen.** Home answers "am I keeping my resolution, are my friends keeping theirs." Insights answers "what does the data say." Nothing on a screen competes with that question.
2. **A glance, then leave.** The person should get what they came for in under three seconds and in under three taps. No screen is a destination to linger on.
3. **Hero + list.** Every main screen is one hero fact, then a list. No grids of equal tiles. No dashboard.
4. **One accent.** Everything else is label grays and system backgrounds. Colour means something or it is not there.
5. **Numbers are the content.** Tabular numerals everywhere; weight and size make hierarchy; icons are rare.
6. **Negative space is the premium.** Larger margins, fewer elements, and restraint read as expensive. Fill nothing to fill it.
7. **System first.** Apple components, Dynamic Type, semantic colours, standard sheets and bars. Liquid Glass only on the system's floating controls, never in content. Toll looks like it belongs on the phone.
8. **Both appearances are first-class.** Every token has a light and dark value; nothing harsh in either. Dark mode uses raised grays, never pure black cards on pure black.
9. **Facts only, in the UI as in copy.** No celebratory motion, no confetti, no red alarms. Level is shown by shape and fill before colour.

## 2. Foundations

### 2.1 Layout and composition

- **Grid:** 8 pt base. Horizontal gutter 20 pt (16 pt on 4.7"/5.4" widths). Section gap 32 pt. Intra-card padding 16 pt. Row height ≥ 52 pt.
- **Hero zone:** the hero numeral sits centred, 12 pt under the toolbar, in a zone of its own with nothing beside it: numeral + glyph, unit line, the three facts (3.3), then the 7-day strip (3.15). 32 pt of air before the list. Tested against the top-left "large title" placement and the upper-third placement: centred-near-top gives the breathing room without the number floating. The wait's countdown numeral is centred in Home's sheet the same way.
- **Alignment:** two axes, deliberately: the hero zone is centred; everything from the first pinned row down left-aligns to the gutter, with trailing numbers right-aligned on a shared column so rows read like a departure board. Nothing else on Home is centred except the footer caption.
- **Weight falls monotonically.** One hero, then rows of equal weight. Nothing between them (no links row, no boxed card) interrupts the gradient. Navigation lives in the tab bar, never in the content.
- **Containers only where grouping needs them.** Home's list sits on the page background with hairline separators, no card. Settings and People use standard grouped lists because they have several groups.
- **Hierarchy by position:** top-leading is most important. Secondary facts sit directly beneath the hero in a single line, never beside it.
- **Containment:** group with whitespace first, separators second, cards third. Home uses whitespace + a single card (friends). Settings uses standard grouped lists.
- **Density:** max one chart per card; max ~7 rows visible before a scroll; never two accents on screen.
- **A fill must differ from its page.** `surface` is the page colour on `bg` and `surfaceRaised` is the page colour on `bgGrouped` (light mode), so a card, tile, chip or field takes `surfaceRaised` on `bg` and `surface` on `bgGrouped`. A control that can be hosted on either (a field inside a list row, a disabled button) takes `fill`, which is translucent and reads on all three.
- **Nothing stretches to fill.** Tiles, cards and sheets take their content's height; spare room on a tall phone becomes space above the bottom action, never taller tiles.
- **Bottom actions** sit 12 pt above the bottom safe area, on a bar of the page's own colour, so scrolled content ends at the bar instead of showing around the button.

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
| `surfaceRaised` | tertiarySystemGroupedBackground `#F2F2F7` | `#2C2C2E` | Chips, tiles and cards on `bg` |
| `fill` | tertiarySystemFill (translucent) | tertiarySystemFill | Disabled buttons; fields and tiles whose host colour varies |
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
- Materials: system bars only. No glass in content. The one floating control of Toll's own, Home's state bar (3.18), is the `floating` fill (`secondarySystemBackground`: `#F2F2F7` light, `#1C1C1E` dark) with a hairline, and in light mode a soft shadow (0 6 20, 6%); dark mode has none.

### 2.5 Motion and haptics

Motion in Toll explains where things came from and where they went. It never celebrates, never loops, and never asks to be noticed. Three durations: 200 ms (state changes), 300 ms (things moving), 450 ms (things appearing for the first time). One spring: response 0.35, damping 0.85, no overshoot beyond 2%. Reduce Motion replaces every move or scale with a crossfade of the same duration; numeric transitions stay.

| Moment | Motion |
|---|---|
| Any step push | The system navigation transition. The progress segment fills left to right over 250 ms as the new screen lands, not before. |
| Returning from the app picker | The apps card is already in place; its rows fade in and rise 6 pt with a 40 ms stagger, once. A second return adds only the new rows the same way. |
| Selecting a When tile | Fill crossfades 200 ms; the tile scales 0.98 → 1 on release. The previously selected tile fades out its fill, nothing else moves. |
| Add another block | The creator's apps card shrinks into the compact row above (`matchedGeometryEffect` on the icon cluster and names), 300 ms, leaving the card empty. The picker does not open by itself. |
| Welcome → sign-in sheet | System sheet. On success the sheet drops and the next step pushes in one motion; no intermediate blank. |
| Code boxes | The active ring moves to the next box 150 ms; a wrong code shakes the row ±6 pt twice over 300 ms and the boxes clear on the way back; a correct sixth digit pushes the next screen with no button. |
| Handle availability | The check mark fades in 200 ms after the server answers; never a spinner for under 300 ms. |
| Home, first appearance | Hero numeral and glyph fade in together, then the week strip bars grow from the baseline 450 ms with a 30 ms stagger, then the list rows fade in with a 25 ms stagger. Total under 900 ms. Only on cold launch; returning from a tab is instant. |
| Hero number changes | `contentTransition(.numericText())`, 300 ms. The glyph crossfades between levels. |
| Friend order changes on refresh | Rows move to their new positions, 300 ms, with stable ids; new rows fade in; nothing bounces. |
| A pinned line arrives | Slides down from under the hero zone with opacity, 300 ms, pushing the list down. Expiry fades it out and the list closes up. |
| Device-state line | Same as pinned. Clearing it (Fix succeeded) collapses it 200 ms. |
| Wait starts | Home's sheet rises (system sheet). Countdown digits use `numericText`; the colon never blinks. |
| Naming chips at the first wait | Appear with the sheet; on a tap the chosen chip fills, the others fade 200 ms, the section's height collapses 300 ms and the hairline goes with it. |
| Wait reaches 0 in app | In the open sheet the countdown crossfades into "How long?" and the chips, 300 ms; `.light` haptic once. With the sheet closed, the bar's line changes to "Unlock ready" with no motion. |
| Unblock on the session picker, Not now, Cancel the wait, Lock now | The sheet closes (system). Nothing else confirms it: the bar beneath already says what is true now. |
| State bar → sheet | System sheet, medium detent, grabber. The bar itself arrives, changes and leaves with no motion. |
| State bar, countdowns | `contentTransition(.numericText())` on the wait's digits each second; the session's line swaps its digits plainly. |
| Shield (system) | No Toll motion; Apple animates the shield. |
| Friend detail, Invite, Custom hours | System sheets with their own detents and spring. |
| Insights charts, first appearance | Bars grow from the baseline 450 ms with a 20 ms stagger; lines draw left to right 450 ms; the heatmap fades in by row. Only on first appearance per session; segment switches crossfade 200 ms. |
| Chart selection | The callout fades and rises 4 pt, 200 ms; it leaves on scroll with a 150 ms fade. |
| Share preview appearance toggle | Light and dark variants crossfade 300 ms. |
| Tab bar | System; minimises on scroll on iOS 26+. |
| Pull to refresh | System. New data applies with the row-move animation above. |
| Removing a block or friend | The row collapses 300 ms after the confirmation; the pin that results for friends is their motion, not yours. |

Haptics: `.light` when a wait starts and again when it ends, and on Lock now (the shield going back up is the same kind of moment as a wait starting); `.warning` on confirming a removal or a block of a person; `.selection` on When tiles and tag chips. Nothing else. No haptic on a pass being granted.

Never: confetti, pulsing, looping, parallax, bouncing rings, progress rings that fill, typewriter text, skeleton shimmer longer than 300 ms, or any motion on the shield.

### 2.6 Iconography

SF Symbols, monochrome, `.secondary` weight regular. Used for navigation affordances: the tab bar (house, chart.bar, person.2), chevron, plus, gear, person.badge.plus, square.and.arrow.up. One exception since Home v2: the state bar and its sheet lead with a 36 pt tile (`fill`, radius 10) holding `shield` or `clock` when their subject is not an app; the shield is `level3` when the gate cannot work (Screen Time off, apps missing), `accent` in "Blocked right now", `label2` otherwise. No icons in rows. No coloured icon circles.

### 2.7 Navigation

A standard `TabView` with three tabs: **Home · Insights · People**, `.tabBarMinimizeBehavior(.onScrollDown)` on iOS 26+, the system floating glass bar. Settings is the trailing bar item on Home, alone; New block is "Add a block" in Home's sheet (3.18). Blocks is reached from Settings and the gate; each block from a row in Home's sheet. Every destination is one tap from every other. The tab bar is the only glass in the app.

## 3. Components

Each component lists anatomy, states, and sizing. Names are the SwiftUI type names.

### 3.1 `StatusGlyph`

- 14 pt (row) / 20 pt (hero) circle. Level by shape and fill: **L1** filled circle; **L2** half-filled circle (left half, straight vertical split); **L3** outlined ring with a 4 pt centre dot. Colour from `level1..3`. Count is never inside the glyph; it is the adjacent number.
- Unknown/silent: dashed ring in `label3`.
- Accessibility label: "fewer than usual", "about usual", "more than usual" (personalised) or "0 to 2 passes" etc. (thresholds).

### 3.2 `HeroStat`

- Centred column: numeral `hero` on the screen's centre axis, with the `StatusGlyph` (20 pt) hung 10 pt off its trailing side, vertically centred on the numeral (centring the pair instead pushes the numeral off the axis the lines beneath share); beneath, closed up to the numeral, the unit line `body` medium ("unlocks today"); 10 pt beneath, the optional subhead line (`subhead`); optional second line (`caption`). Home passes no subhead since v2: its facts (3.3) carry the week.
- States: normal; zero ("0 passes" is a fact and looks identical); loading (numeral placeholder shimmer-free: `--`).

### 3.3 `MetricPair` and `FactColumn`

- `MetricPair`: label (`caption`) above value (`number`), with last-period value small and `label2` to the right ("11 · 17 last week"). Insights hero and Friend detail.
- `FactColumn` (Home v2): three equal columns under the hero, at most 330 pt wide together, 20 pt under the unit line; each an uppercase `micro` label in `label2` (11 pt medium, tracking 0.6; `label2`, not `label3`, because it names the number) over a `number` value, centred. SCREEN TIME "1h 42m" (drawn by the report extension, spec §6; "—" in `label3` with no blocked apps) · THIS WEEK "11" with "▼ 17" in `caption` `label2` beside it (▲ when ahead, no arrow when level; the arrow is never coloured) · BLOCKED "11" (block hits today, Dismiss included). At accessibility sizes the three stack. VoiceOver: "Screen time on blocked apps today, 1 hour 42 minutes"; "This week, 11 unlocks, 17 last week"; "Blocked, 11 times today".

### 3.4 `FriendRow`

- 60 pt min height, hairline separator above (none on the first row). Leading `Avatar` 32 pt with the `StatusGlyph` as a 12 pt badge at its bottom-right (on a 16 pt `bg` disc so it reads on any photo); name `headline`; detail line `micro`-sized (12 pt, `label2`, one line, truncated with an ellipsis at ~200 pt so it never crowds the trailing column: "Opened Instagram at 11:40 p.m. after a 5-min…"); trailing column: today's count `number` with week trend beneath (`caption`, "▼ 23%" / "▲ 8%" — arrow glyph in `label2`, never coloured). The full sentence is in Friend detail.
- Tap → `FriendDetail` sheet. Long-press → context menu: Remove friend, Block, Report.
- States: normal; silent (dashed glyph, detail "Toll has been off since Tuesday"); request pending (trailing "Accept" / "Decline" quiet buttons).

### 3.5 `PinnedRow`

- Same leading geometry as `FriendRow` (52 pt min height), no background, no box: an 8 pt `accent` dot where the glyph would sit, then the line in `body` medium. Because nothing else on Home uses the accent as text decoration, this is the only accent on the page and the eye stops on it. No icon. Dismiss by swipe is not allowed in 0.1 (it expires on its own).

### 3.6 `MutualRow`

- `Avatar` with level badge + name + "friends with Adi and 2 others" (`subhead`) + trend (`caption`, "▼ 12%") + trailing "Add" quiet button. Never a count, never tags.

### 3.7 Wait (in Home's sheet)

- Since Home v2 there is no overlay: the wait is a state of the sheet Home's bar opens (3.18), and the sheet opens by itself when a wait starts or a free pass arrives (switching to the Home tab if needed). Header: the app's icon (36 pt) and name ("Instagram"), with "Blocked · Always" beneath. Body, centred: countdown `hero` ("2:41"), the wait line `caption` beneath ("Wait 3 of today · next wait 8 min"), first-wait naming (3.9) when the app has no tag, then "The wait keeps running if you close this. You choose how long when it ends." in `caption`. Bottom: `QuietButton` "Cancel the wait" in `label2`. No ring, no progress bar: the number is the progress.
- Swiping the sheet down leaves the wait running; the bar reads "Instagram unlocks in 2:41" with the wait line beneath. The countdown owns its tick: a second passing redraws the digits only.
- When the wait ends with the sheet open, the header line becomes "Waited 5 min" (or "Free unlock") and the body crossfades into `SessionPicker` (3.8) with a `.light` haptic. With the sheet closed the bar reads "Unlock ready" / "Instagram · Choose how long" and the sheet does not open by itself.

### 3.8 `SessionPicker`

- In Home's sheet: "How long?" `subhead`, three `ChoiceChip`s (5 min · 10 min · 15 min), `PrimaryButton` "Unblock for 10 min" (the chosen length; the same words for a pass from a shield and one asked for inside Toll, because Toll cannot switch to the app and must not say "Open"), `QuietButton` "Not now" beneath it. Tapping chips selects and the button's number follows; the button confirms. Default selection: the user's last choice.

### 3.9 `TagChips` (first-wait naming)

- In the wait sheet, between the wait line and the note, beneath a hairline: "Which app is this?" `subhead` medium, one 12 pt `label2` line ("Friends see the name. Change it any time from Blocks."), then the seven tag chips (display forms: Instagram, TikTok, YouTube, Snapchat, X, Reddit, Other) wrapped and centred (34 pt, `surfaceRaised`, because the sheet is `bg`; selected = `accent` fill). Shown only when the token has no tag; the countdown keeps running above it. Tapping a chip stores the tag and the section fades out.

### 3.10 `BlockRow`

- One row per block, 64 pt: a cluster of up to three app icons (system `Label(token)` icons, 28 pt, overlapping by 6 pt), the app names on one line (system labels, truncated), the schedule beneath in `caption` ("Always", "Nights · 11 pm – 7 am"), chevron. Tap → edit. Swipe → "Remove" (destructive) with the confirmation from spec §10.

### 3.11 `ChartCard`

- `surface` card, 16 pt padding. Title `headline`, optional range toggle (segmented, 2 options max) top-trailing, chart, caption `caption`. Fixed heights: bars 160 pt, line 140 pt, histogram 160 pt, heatmap rows × 20 pt. Chart styles per `toll-insights-spec.md` §4.

### 3.12 Buttons

- `PrimaryButton`: full-width, 50 pt, `accent` fill, label `headline` in white (light) or `#0F1115` (dark, where the accent is light and white would fail contrast). One per screen max. Disabled: `fill` with a `label3` title, so it still reads as a button on any page.
- `SecondaryButton`: the same shape in `fill` with a `label` title, for the second of two equal choices (Continue with email). The whole shape is the tap target.
- `QuietButton`: text-only, `accent` label, `body` medium. Used for Cancel, Skip, Add.
- `DestructiveQuiet`: text-only, systemRed. Remove, Delete account.
- No icon buttons in content; nav bar uses standard bar items.

### 3.13 `EmptyState`

- One line `body` in `label2`, centred in the section's space, optional one `QuietButton`. No illustration.

### 3.14 `ShareCardView`

- 360×640 pt (story) / 360×360 pt (square) canvas; opaque `bg`; hero numeral at 96 pt rounded; one fact line; one small chart; display name (optional) top-left `caption`; wordmark bottom-left at 12 pt; date range and invite link bottom-right `caption`. Safe band: nothing in the top 90 pt or bottom 130 pt of the story format. Rendered at scale 3.

### 3.15 `WeekStrip`

- Seven 12 pt-wide bars, 6 pt apart, 28 pt tall at the week's maximum, Monday to Sunday, passes per day; today in `accent`, other days `neutralBar`, zero days a 2 pt stub; tops rounded 2 pt, feet square on a shared baseline. No axis, no labels, no values: it is texture that rewards a second look, not a chart. Tapping it opens Insights. Accessibility label reads the seven numbers.


### 3.16 `WhenChips`

- A 2×2 grid of tiles, 10 pt apart, radius 14, 88 pt tall at standard text sizes (taller only when larger text needs it; a pair in a row always matches; the grid never grows to fill spare height): icon (infinity, moon, sun, clock) at the top, label `subhead` semibold, one 12 pt line ("every day", "11 pm – 7 am", "9 am – 5 pm", "pick times"). Selected = `accent` fill with white text; others take the fill that differs from the page (§2.1): `surfaceRaised` in setup, `surface` on New block. Always is preselected. Custom opens the Custom hours screen.

### 3.17 `Avatar`

- Circle, 32 pt in rows, 40 pt in Settings, 44 pt in Friend detail, 96 pt on the You step. Photo if set, else the first letter of the name at 42% of the size, semibold, `#3A3A3C` on a muted pastel chosen by hashing the handle (six fixed tones; no saturated colours). The status badge sits at bottom-right when the row has a status. Never a coloured ring, never an online dot.

### 3.18 State bar and sheet (Home v2)

The bar states one fact about the phone right now and has no buttons. Tapping it opens one sheet with the same anatomy every time. Approved on the "Toll — Home v2" canvas, 14 Nov; they replace the block bar and cards, the wait overlay and the device-state line (ledger A127).

- **Bar.** Docked 12 pt above the tab bar, full width inside the gutter, 64 pt minimum, radius 16, 14 pt side padding, the `floating` fill (§2.4). Leading: the icon cluster (24 pt icons, 3.10) for blocks, one app's icon (36 pt) for an app, or a symbol tile (§2.6). Then two lines: title `subhead` semibold (15 pt), line 12 pt `label2` tabular. Trailing: a `label3` chevron. One button; VoiceOver reads its lines as one sentence with the hint "Shows details". App names that do not fit become "Instagram, TikTok +1". At accessibility sizes its text stops at AX1 and the line wraps to two (§5).
- **States, in priority order.** Screen Time off ("Screen Time is off" / "Nothing is blocked until it's back on", shield in `level3`) · blocks missing apps ("Blocks need re-picking" / "Some apps are missing") · a wait running ("Instagram unlocks in 2:41" / the wait line) · a pass to use (the picker is due, or set aside with Not now: "Unlock ready" / "Instagram · Choose how long") · a session open ("Instagram is open" / "10-min unblock · 6:42 left", ticking) · blocks on ("Instagram, TikTok, YouTube blocked" / "Always · 2 more from 11 pm": the lead block's line, then the next block to start) · nothing on now ("Nothing blocked right now" / "Nights starts at 11 pm · 5 apps", clock tile; the block's own name, else its schedule's kind) · no blocks ("Nothing blocked yet" / "Choose apps to block"). App names are the system's labels, so they are views and the words after them are separate (`Copy.Bar`).
- **Sheet.** Medium and large detents, grabber, `bg`. 28 pt from its top: the bar's icon at 36 pt, a 20 pt semibold title and one `caption` line; 24 pt beneath, one body block; at the bottom (12 pt above the safe area) at most one primary and one quiet action. Swipe down or tap outside to dismiss; every action also closes it. It reads the live state, so it changes in place (a wait turning into the picker).
  - Blocks ("Blocked right now" / "3 apps · 2 more from 11 pm", accent shield; or "Nothing blocked right now"): a `surfaceRaised` card of 60 pt rows, the blocks on first, then the rest (icon cluster, names `body` medium, "Always · on now" / "Nights · from 11 pm" / "Always · open now" in `caption`, chevron; a row opens the block's editor); "Tap a block to change its apps or hours." in `caption`; quiet "Add a block" (disabled at `blocks.max`).
  - Session ("Instagram is open" / "Opened 7:12 pm · locks at 7:22 pm"): a card with a 6 pt line filling with the time gone (`accent` on `fill`) and "6:42 left" · "10 min" beneath; "The block comes back on its own at 7:22 pm. Locking now ends it early."; `PrimaryButton` "Lock now" (the shield returns at once, `.light` haptic).
  - Wait and session picker: 3.7, 3.8.
  - Screen Time off ("Since Tuesday", from when this phone first saw it off): a card, "Toll can't block anything until Screen Time is back on." with "After 2 days your friends see Toll as off on your phone." (`network.silenceMissedCheckins`) beneath; `PrimaryButton` "Turn on Screen Time" (the system sheet, or the Settings app once iOS stops showing it).
  - Re-picking: the affected blocks as rows; "Tap a block to choose its apps again."; no action.
  - No blocks: "Choose apps, then when to block them."; `PrimaryButton` "Add a block".
- No Unblock inside Toll since v2: the way through is the shield (spec G-3).
- **Not built: screen time as the hero.** The canvas's alternative ("1h 42m on blocked apps today" as the hero, friends in minutes) needs Toll to read minutes; it waits on a decision about the 26.4 usage capability (ledger C17, B7).

## 4. Screens

### 4.1 Home

Home tab. Nav bar: no title (the hero is the title). One bar item, trailing: `gear` (Settings). Content, top to bottom, on the page background:

1. **You** (centred, no card, 12 pt below the toolbar): `HeroStat` "3" + glyph, "unlocks today"; 20 pt beneath, the three facts (3.3); 18 pt beneath, `WeekStrip`. The numeral and the strip open Insights. 32 pt below it the left-aligned content begins.
2. **Pinned** (if any): `PinnedRow`s.
3. **Friends** section: header row with the uppercase label "FRIENDS" (`caption` weight medium, `label2`) and trailing `caption` "walked away 83%"; then `FriendRow`s ordered by improvement, hairlines between. Empty: `EmptyState` "No friends yet." + "Send an invite". Signed in, never synced and the fetch failed: `EmptyState` "No connection." with no button, in the same place.
4. **Footer**: 16 pt beneath the last row, one centred `caption` in `label3`, "You opened Toll 14 times today.", the quietest thing on the screen. It scrolls with the list.
5. **State bar** (3.18), docked above the tab bar; the list scrolls under it and fades out over 20 pt at the bar's top edge, the page colour filling down to the bottom edge, so no half-covered line shows between the bar and the tab bar.

The tab bar floats over the bottom; content scrolls under it. Refresh: pull-to-refresh syncs. Last-synced timestamp is shown only if older than 1 hour (`caption` under Friends header).

### 4.2 Shield (system-rendered)

Toll controls: title, subtitle, primary and secondary button labels, background colour, icon. Title "Instagram is blocked." Subtitle "You've unblocked this 2 times today." Primary "Open Toll" (accent), secondary "Dismiss". Background `bg` with system blur; icon = Toll app icon. If notifications are off, the subtitle becomes "Open Toll from your home screen."

### 4.3 Welcome, sign in, set up

**Title position.** Every screen after Welcome places its title 28 pt below the 44 pt bar (back button, or the progress segments), at 34 pt semibold. Fields, rows and tiles start 28 pt under the title, once: the title owns the gap above it and the content owns the gap below. Primary button at the bottom, 12 pt above the safe area; the quiet action, when there is one, directly beneath it. The bar and the bottom actions stay put; the title and content between them scroll only when they do not fit (a 4.7" screen, large text, the keyboard) and do not bounce when they do. Steps push and pop with the system transition; the progress bar persists across the setup steps; sheets rise over the current screen.

- **Welcome** — vertically centred: the mark (placeholder ring, 56 pt) and the name at 40 pt semibold, nothing else. Bottom: Continue with Apple (system black button), Continue with email (`surface` fill), Continue without an account (quiet), and the 11 pt legal line in `label3` with Terms and Privacy Policy as links.
- **Email** — back button; "What's your email?"; a 56 pt filled field (`surface`, radius 14, 17 pt text, accent caret); the `PrimaryButton` "Send code" 12 pt beneath it, where the keyboard leaves it, never at the bottom of the screen; one `caption` beneath, centred. Keyboard is up on arrival.
- **Code** — back; "Enter the code"; `subhead` "Sent to …"; six 60 pt boxes (`surface`, radius 14, 28 pt digits, the active box ringed in `accent` with a caret); "Resend code" centred beneath. Autofills from Mail; advances on the sixth digit without a button.
- **Set up 1 · You** (signed-in, new accounts only) — "You"; 96 pt `Avatar` with an accent "+" badge to add a photo; Name field (prefilled from Apple) and Handle field, each a 56 pt filled field with its `caption` label above it, so a prefilled screen still says which is which; the handle shows a live check mark and "available" in `level1`; `caption` "Friends find you by handle. Both can be changed in Settings."; Continue.
- **Set up 2 · Permissions** — "Toll needs two things"; two icon rows (44 pt `surface` tile with the symbol, label `headline`); one `PrimaryButton` Allow runs both system sheets. No skip. Denied state: the Screen Time row's trailing text reads Denied in `level3`, Notifications reads Allowed with a check, one `subhead` line explains, the button reads Try again.
- **Set up 3 · Block these** — the fast creator: the apps card (`surfaceRaised`, hairlines between rows) shows at most three app rows, then a 44 pt "+N more" row with a chevron (opens the full list), then "+ Choose more"; empty, the card is one centred "+ Choose apps" row. Then the "WHEN" label, `WhenChips` with Always preselected, and at the bottom Done with "Add another block" quiet beneath it. It fits without scrolling on 6.1" and up; on a 4.7" screen with a full card the content scrolls under the pinned buttons. With one compact row from Add another, everything still fits a 4.7" screen; on a second Add another the compact rows collapse to one line ("2 blocks · Always, Weekdays"). After Add another, each finished block becomes a 48 pt compact row (icon cluster, names · schedule, chevron) stacked above the creator. Returning users: title "Block these again", bar of two.
- **Set up 4 · Find your friends** — a full step on `bgGrouped`, bar of four: three groups, 24 pt apart, each a header and one 56 pt `surface` row: Invite code (field + Paste), Contacts (one row with a chevron), School (field + Send code); Done; Skip quiet directly beneath it. People, Settings and Insights embed the same groups, on `fill` because their host colour varies.

### 4.4 People

Grouped list, inline title. Rows sit on the system's inset-grouped cards with the row's own 60 pt height (no list padding on top of it). Sections: **Requests** (if any; `Avatar` without badge, name, "friends with Maya", Accept · Decline; stacked from the largest standard text size up) · **Friends** (`FriendRow`s with avatars, `@handle` in `caption` after the name, "14 this week · 18 last week" beneath and the trend trailing, in the same improvement order as Home) · **Mutuals** (`MutualRow`s) · **In your contacts** (if contacts matching is built; `MutualRow` geometry with "Add") · **School** (one two-line row with a chevron: school name; member count and "held 71% this week"; it opens the members list, and "Find people at Waterloo" is its VoiceOver hint; with no school, the school email field) · **Find friends** (invite code field and contacts row, the setup groups, N-17) · **Invite** (the user's code, with the "Share invite link" `PrimaryButton` beneath the card). A mutual already asked shows "Requested" as a note, not a button. Trailing nav item: person.badge.plus → Invite sheet.

### 4.5 Friend detail (sheet)

A large detent sheet over Home (top at ~96 pt, grabber). Header: 44 pt `Avatar`, name `title`, `caption` "@handle · friends since Oct 12"; today's count at 40 pt + glyph; a 4-up `MetricPair` row (this week, held %, waited, clean days, each with last week beside); "Today" and "Yesterday" lists of pass lines (`subhead`, 36 pt rows, hairlines); their tagged blocks as chips (`fill` with `label` text: they are not actions, and accent text on the accent tint is under 4.5:1). The four metrics are equal columns (2×2 at accessibility sizes); only "this week" carries a last-week value, because the API has no others. Bottom: three quiet actions in `label2`, centred, resting on the sheet's bottom edge when the content is short: Remove friend · Block · Report. Nothing older than yesterday.

### 4.6 Blocks

Grouped background, inline title. One grouped card of `BlockRow`s (one chevron per row; an empty list says "Nothing blocked yet"); caption beneath "Removing a block is shown to your friends." `PrimaryButton` "Add a block" on a bottom bar (§2.1). A block that has lost apps (flows §19) reads "Needs re-picking" where its schedule would be: words, not colour.

**New block** — pushed, inline title, arriving on the empty apps card ("+ Choose apps"); the picker opens only from that row. Back from the picker: the chosen apps card (system `Label(token)` icon + name, and on the right the friends-facing tag in `caption`, tappable → tag chips), a "Choose more" row, a `micro` line ("Names on the right are what friends see. Tap to change."), `WhenChips`, a "Block name" row (caption "Optional. Only you see it."), Done. Editing an existing block opens the same screen prefilled. A block that has lost apps opens with the ones it still has and one `subhead` line above the apps card, "Some apps are missing from this block. Choose them again."; the line goes once anything is chosen, and the screen is not treated as edited until the person changes something.

**Custom hours** — a 380 pt sheet over New block (full height at accessibility text sizes): "Custom" `title`; From and Until as two rows in one card, each with the system's compact time picker (two wheels side by side clip each other at phone width); a day row of seven equal tiles across the full width (44 pt tall, selected = `accent`); Done at the bottom. Choosing Custom in `WhenChips` opens it; Done returns with the Custom tile showing the chosen window.

At `blocks.maxTokens` the picker's Done is disabled and the limit line from spec §10 shows; at `blocks.max` the "Add a block" button is disabled and a second `caption` beneath the list says why: "8 blocks is the most." (the number is `blocks.max`).

### 4.7 Insights

Inline title; segmented control (Me · Friends · School) under the nav bar; a lazy vertical stack of `ChartCard`s per `toll-insights-spec.md` §3, 16 pt apart. Trailing nav item: square.and.arrow.up → the share sheet: a chip row to choose the card, the preview scaled to the space that is left, and Share on a bottom bar (3.14). Friends and School each tell loading, failed, signed out and "not enough yet" apart with one line; a new user sees empty charts with their axes, never a blank page.

### 4.8 Settings

Inset-grouped list, inline title. Account (40 pt `Avatar`, name, `@handle`, Edit trailing; sign out) · School (status, change, leave) · Notifications (daily summary toggle, time; with notifications off in iOS, a "Notifications are off" row and an "Open Settings" button row take their place) · Discoverability (contacts matching toggle) · Blocks shortcut · Data (export my data, delete account) · About (privacy policy, terms, support address, version) · **Support Toll** (donation link; last group, below the fold). Delete account is `DestructiveQuiet` with a two-step confirm.

### 4.9 Invite sheet

A half-height sheet over People with a grabber: "Your code" `caption` and the code at 44 pt semibold letter-spaced 6 pt, centred in the space above; `PrimaryButton` "Share link" (`ShareLink`) and the caption "Friends who install from this link are added when they accept." on the bottom edge. The code shows at once; the button holds its place, disabled, while the link loads.

### 4.10 Session picker (in Home's sheet)

The sheet's wait body swaps its countdown for: "How long?" `subhead`, three `ChoiceChip`s (last choice selected), one `caption` "From now. The block returns after.", then at the bottom `PrimaryButton` "Unblock for 10 min" with the chosen length and `QuietButton` "Not now" beneath it. The header keeps the app and reads "Waited 5 min" or "Free unlock".

Unblock starts the session and the sheet closes; Toll stays where it is (it cannot open the app) and the bar takes over with the countdown. Not now also closes it: a pass that came from a shield is kept for the day ("Unlock ready" on the bar, and the next shield hit or a tap on the bar brings the picker back). Neither was counted.

## 5. Accessibility

- Dynamic Type through AX5: rows stack vertically (glyph+name on one line, detail and number beneath) at ≥ AX1; hero capped at AX2 size.
- VoiceOver: every row reads "Adi, about usual, 3 unlocks today, down 23 percent on last week." Charts expose audio graphs. The wait's countdown in the sheet announces every 30 s, not every second. The state bar is one button read as one sentence with the hint "Shows details" ("Instagram, TikTok, YouTube blocked, Always, 2 more from 11 pm"); its countdowns are marked as updating frequently and spoken in 30 s steps, and announce nothing by themselves.
- The state bar at accessibility sizes: its text stops growing at AX1, as the tab bar's does, and its line wraps to two; app names that do not fit become "+2" rather than shrinking into each other. The sheet opens at full height with its icon above the title; it scrolls and its actions stay on the bottom edge. The three facts stack.
- Colour: nothing conveyed by colour alone (glyph shape; arrows for trend). Verified in grayscale.
- Contrast and Increase Contrast variants for all tokens.
- Touch targets ≥ 44 pt. Hit areas on chips and chart bars padded.

## 6. Mockup review

Mockups cover every screen: Home (light, dark, wait, first-wait naming, session picker), Shield, Welcome, Email, Code, the four setup steps (plus the denied, add-another and returning-user states), Blocks, New block, Custom hours, People, Friend detail, Invite, Blocks, Settings, Insights Me/Friends/School, Share card (story, light + dark), plus two kept Home explorations (one-line rows; "you as a row in the list"). Each phone screen is a 390×844 artboard at 1×. Decisions from review, 8 Nov: centred hero near the top; tab bar instead of in-content links; list on the page, no card; pinned line as a dot, not a box; detail lines at 13 pt with early truncation; week strip under the hero; Toll-opens count as the footer.
