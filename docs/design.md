# Design foundations

Carried over from Toll's design doc §2 (MVP spec §7: "Visual foundations and motion rules carry over"). Toll's components and screens are gone; what remains is the visual system, the motion rules with a table rewritten for this product's screens, and the accessibility bar. The accent is a placeholder until the product has a name and identity.

## 1. Principles

1. **One question per screen.** Status answers "is it blocked, and how many unlocks are left." Nothing competes with that.
2. **A glance, then leave.** Under three seconds, under three taps. No screen is a destination.
3. **One accent.** Everything else is label grays and system backgrounds. Colour means something or it is not there.
4. **Numbers are the content.** Tabular numerals everywhere; weight and size make hierarchy; icons are rare.
5. **Negative space is the premium.** Fewer elements, larger margins. Fill nothing to fill it.
6. **System first.** Apple components, Dynamic Type, semantic colours, standard sheets and bars. No glass in content.
7. **Both appearances are first-class.** Every token has a light and dark value.
8. **Facts only, in the UI as in copy.** No celebratory motion, no confetti, no red alarms.

## 2. Foundations

### 2.1 Layout

The design canvas (**Sleep App Screens**, linked in `docs/design-brief.md`) is the measure: build each screen at the board's spacing, and where a gap is not in `TollSpacing`, add it there under the name the board uses it for (decisions D43).

- **Gutter** 24 pt (16 pt at 375 pt wide). Content starts under the 59 pt status area, in a 44 pt bar.
- **Titles:** setup 32/38, 28 pt under the bar; pushed screens 30/35, 8 pt under the bar, then 20 pt to the first card (`ScreenTitle`).
- **Cards:** `surface`, 18 pt corners, 16 pt sides. Rows 60 pt with a 36 pt tile (editors, Ready, Settings), 58 pt (Home's blocks), 56 pt and 52 pt with a 32 pt tile (apps lists); 14 pt from tile to text; detail 1 pt under the title. Note cards 14/16 padding; the stats card 18/16.
- **The main button's bottom edge sits on the bottom safe area** (34 pt on Face ID phones; 16 pt above the edge without a home indicator). A quiet link under it reaches 16 pt into the indicator's space (`tollBottomBar`, `SheetPage`).
- **Sheets:** iOS's shape and grabber; title 37 pt from the top; the board's height at the default text size, taller with larger text, full height at accessibility sizes.
- **Small phones and large text scroll;** the main button stays pinned.

### 2.2 Type

SF Pro at the boards' sizes, weights and line heights, with no extra letter spacing (the boards' Inter tracking does not carry over). Each size scales with Dynamic Type like the text style nearest it. Tokens are `TollType`, applied with `.tollType(_:)`, which also sets the line height the way CSS does.

| Token | Size / line | Weight | Use |
|---|---|---|---|
| `display` | 40/47 | semibold | Welcome's title |
| `setupTitle` · `screenTitle` | 32/38 · 30/35 | semibold | Setup titles · pushed screens' titles |
| `sheetTitle` | 24/28 | semibold | Sheet titles |
| `hero` · `heroSuffix` | 64/70 · 24 | semibold · medium | Home's big time and its am/pm; caps at AX2 |
| `stat` | 22/28 | semibold | This week's numbers |
| `lead` | 18/26 | regular | Welcome's line |
| `button` · `bar` | 17 | semibold · regular | Buttons · the back button |
| `rowTitle` · `sheetBody` | 16/21 · 16/23 | medium · regular | Row titles · a sheet's sentence |
| `body` · `heroLine` · `link` · `quiet` | 15/21 · 15/20 | regular · regular · semibold · medium | Lines under titles · the hero's line · text links · quiet actions |
| `note` · `action` | 14/19 | regular · semibold | Note cards · "See all", "New" |
| `detail` · `trailing` | 13/18 | regular · semibold | A row's second line, footnotes · "On now" |
| `eyebrow` · `caption` | 12/16 | semibold uppercase, 0.8 apart · regular | Section headers · labels under stats |
| `micro` · `microNumber` · `microEyebrow` | 11/14 | medium · regular · semibold uppercase | Chart labels and values |

Times are the phone's 12- or 24-hour format with "am"/"pm" lowercase; Home's rows drop ":00" when both ends are whole hours ("9 am – 5 pm").

### 2.3 Colour

The canvas's tokens (sticky note s4), dark first (decisions D36). Light mode is worked out from the same names. Tokens live in `TollColor`.

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#0D1015` | `#F6F5F1` | Page |
| `surface` | `#161A21` | `#FFFFFF` | Cards, rows, sheets |
| `surfaceRaised` | `#1F242C` | `#EDEBE5` | Icon tiles, tracks, the Apple tile, disabled and neutral buttons |
| `separator` | `#262B34` | `#E3E1DA` | Hairlines |
| `bar` | `#2C323C` | `#D9D6CE` | Chart bars, dashed empty slots |
| `label` / `label2` / `label3` | `#EEECE6` / `#A2A8B2` / `#646B76` | `#1A1C20` / `#5B6068` / `#9A9EA5` | Text |
| `accent` | `#E9B96E` | `#8E5E14` | The one accent: main buttons, links, what is on |
| `accentSoft` | accent @ 14% | accent @ 14% | Leading tiles, "on" backgrounds |
| `onAccent` | `#1C1408` | `#FFFFFF` | Text on the accent |
| `ok` | `#86C9A9` | `#2E7D5B` | A number going the right way |
| `warn` · `warnSoft` | `#EE9E74` · @ 12% | `#B4542C` · @ 12% | Over a limit; deleting |

All text ≥ 4.5:1 in both; Increase Contrast pushes the accent further. Appearance: Dark (default) · Light · Match iPhone, in Settings.

### 2.4 Shape and depth

Radii: card 18, button 16, field 12, chart bar 6; tiles 8/10/11/12/13 by size (`TileSize`). No shadows; surface tiers carry depth. Apple's own controls (sheets, wheels, segmented control, back button, alerts, the block screen) keep Apple's shape; we match colour and content.

### 2.5 Motion and haptics

Motion explains where things came from and where they went. It never celebrates, never loops, never asks to be noticed. Three durations: 200 ms (state changes), 300 ms (things moving), 450 ms (first appearance). One spring: response 0.35, damping 0.85, ≤ 2% overshoot. Reduce Motion replaces every move or scale with a crossfade of the same duration; numeric transitions stay. **If a transition is not in this table, there is none.**

| Moment | Motion |
|---|---|
| Setup step push | The system navigation transition. The progress segment fills left to right over 250 ms as the new screen lands. |
| Returning from the system picker | Chosen items are already listed; they fade in and rise 6 pt with a 40 ms stagger, once. |
| A permission row changes | Its status text crossfades 200 ms. |
| Status state line changes | Crossfade 200 ms. Numbers in it use `numericText`, 300 ms. |
| A pip empties or fills | Crossfade 200 ms (#72). |
| Door sheet opens or closes | System sheet. |
| Door: choosing → waiting → open | Content crossfades 300 ms inside the sheet; the sheet does not move. |
| Countdown | `contentTransition(.numericText(countsDown: true))` each second; the colon never blinks. |
| Regret line expires | Fades out 200 ms; nothing else moves. |
| Settings | System list and pushes. |
| Block screen (system) | None of ours; Apple animates the shield. |

Haptics: `.light` when the door's wait starts and when it ends; `.warning` before something that cannot be undone; `.selection` on picker changes. Nothing else.

Never: confetti, pulsing, looping, parallax, rings that fill, typewriter text, shimmer, or any motion on the block screen.

### 2.6 Iconography

SF Symbols, monochrome, outline. **One symbol per concept, one concept per symbol** (#72), named in `TollSymbol` (`TollUI/Tokens/Symbols.swift`); no feature types a symbol string. App icons on the door come from the system (`Label(token)`), never drawn by us. No coloured icon circles: tiles use `accentSoft` or `surfaceRaised`.

| Concept | Symbol |
|---|---|
| Sleep, a night | `moon` |
| A night's end, morning (moon start – end sun, D68) | `sun.max` |
| Another block | its kind: `book`, `briefcase`, `bolt`, `ellipsis` |
| **State:** blocked now · starts later · away · paused · nothing can block · working with less (While Using) · waiting for Always | `lock` · `clock` · `figure.walk` · `pause.circle` · `exclamationmark.triangle` (warn) · `location.slash` · `hourglass.bottomhalf.filled` |
| An unlock, the door · the door's wait | `lock.open` · `timer` |
| Apps on a blocklist · a block's hours | `square.grid.2x2` · `clock` |
| Home · another place · no place (anywhere) | `house` · `mappin` · `globe` |
| Current position, the Location permission · Precise | `location` · `scope` |
| Screen Time · weekends differ · wake time | `hourglass` · `calendar` · `alarm` |
| Done · purchased · failed · waiting for approval · nothing found | `checkmark` · `checkmark.seal` · `xmark` · `person.badge.clock` · `magnifyingglass` |
| Leaves for iOS Settings · privacy | `arrow.up.forward.app` · `hand.raised` |
| Insights · Settings · add · delete · forward | `chart.bar` · `gearshape` · `plus` · `trash` · `chevron.right` |

**State has a glyph, in the same place** (`StateLine`): before the eyebrow on Home, and with the word on every row and status value (`StatusValue`). When nothing will block (paused, Screen Time off), the big time gives way to the state's glyph in a 64 pt tile. **Counts are shapes** (`Pips`): unlocks as dots wherever they're shown. **Actions look like actions:** a screen's main action is a button, never a text link (the door on Home is the exception: a quiet grey capsule by the unlock dots, D61); links that act carry a glyph (`See all ›`, `+ New`); anything that leaves for Settings carries `arrow.up.forward.app` (`SettingsLink`). **Notes have a severity** (`NoteCard(severity:)`): info, degraded (`location.slash`), broken (`exclamationmark.triangle` on `warnSoft`).

## 3. Buttons

- `PrimaryButton`: full width, 54 pt, 16 pt corners, 17 semibold. Tones: `accent` (one per screen), `neutral` (`surfaceRaised`, `label`: "Choose again", "Cancel" while waiting), `warn` (`warnSoft`, `warn`: "Delete block" in its sheet). Disabled: `surfaceRaised` with a `label3` title.
- `QuietButton`: text only, 44 pt hit area, 15 medium in `label2` ("Not now", "Cancel", "Restore purchase"); accent links are 15 semibold.
- `DestructiveQuiet`: trash symbol and text in `warn`, 15 semibold: "Delete block".

## 4. Accessibility

- Dynamic Type to AX5. Lines wrap, never truncate; the countdown caps at AX2.
- VoiceOver: every control has a label; the countdown is spoken in 30 s steps and announced every 30 s, never every second; Status's lines read as one sentence each.
- Colour never carries meaning alone.
- Contrast and Increase Contrast variants for every token. Touch targets ≥ 44 pt.

## 5. The wordless test

The founders' measure of understandability (21 Nov 2026): **if every character on the screen were wiped, or the screen were in a language the user can't read, could they still understand what they're seeing?** Words should confirm what the screen already shows, not carry it alone.

A screen passes when, from its shapes, symbols, numbers, colour and position, someone can tell:

1. **Where am I?** Which screen, and which state it's in (blocked, waiting, paused, away, off).
2. **What's true now?** Is anything blocked, roughly until when, and what happens next.
3. **What do I do?** The one main action, and what's safe to ignore.
4. **Did it work?** After acting, the screen visibly changes to say so.

Two levels:
- **Wordless** (strict): every line is a bar, digits included. Render variant `wordless` (or `dark-wordless`) draws each `tollType` line as a placeholder bar. Judge with the normal render beside it.
- **Foreign** (lenient): letters unreadable, digits and symbols kept. Numbers, times and counts carry meaning here, which is why principle 4 holds.

How a screen earns it: one symbol per concept, used everywhere (a moon is Sleep, a lock is an unlock, a pin is a place); geometry for time and supply (the night strip, pips, bars); position that means the same thing on every screen (state at the top, the one action at the bottom); and colour only together with a shape or symbol (§4). This amends principle 4's "icons are rare" to "a symbol wherever it carries a concept". Decoration is still out.
