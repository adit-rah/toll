# Design foundations

Carried over from Toll's design doc §2 (MVP spec §7: "Visual foundations and motion rules carry over"). Toll's components and screens are gone; what remains is the visual system, the motion rules with a table rewritten for this product's screens, and the accessibility bar. The accent is a placeholder until the product has a name and identity.

## 1. Principles

1. **One question per screen.** Status answers "is it blocked, and how many pauses are left." Nothing competes with that.
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
- **Cards:** `surface` with a `separator` hairline (`tollSurface`), 18 pt corners, 16 pt sides. Rows 60 pt with a 36 pt tile (editors, Ready, Settings), 58 pt (Blocks' rows), 56 pt and 52 pt with a 32 pt tile (apps lists); 14 pt from tile to text; detail 1 pt under the title. Note cards 14/16 padding; the stats card 18/16.
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

The canvas's tokens (sticky note s4), dark first (decisions D36). Light mode is worked out from the same names. Tokens live in `TollColor`. The warm tones are a choice of look.

- **No large bright area in either appearance.** Nothing in the app's own palette is pure white: light mode is warm paper, page and cards near 80% relative luminance, sheets and buttons included. Dark is a warm near-black.
- **Cards are no brighter than the page.** In light, `surface` sits a step darker than `bg` (1.07:1) and cards are edged with a one-pixel `separator` hairline (`tollSurface`), so tone and a line, not glare, set them apart. Tonight's band and Setup's cards still draw `surface` alone, by tone only, until they move to `tollSurface`. In dark, cards are a step lighter, with the same hairline. Tiles and tracks are one step further (`surfaceRaised`).
- **Text stays strong.** Body text (`label`) is 13:1 or more on every surface, and never under 7:1; secondary text (`label2`) 5.4:1 or more. Increase Contrast takes text and the accent further (the second value in a cell).
- **`label3` is for marks, never words** someone needs to read: chevrons, empty pips, outlines, dashed slots, a glyph beside a word. It is 3:1 or more on `bg` and `surface`. Disabled titles, footnotes and headers use `label2`. Your sky's faint names (D89) are the one exception.
- **Apple's chrome keeps Apple's colours:** the glass tab bar and back button, switches, alerts, the block screen.
- **The launch screen is the dark page** (`LaunchBackground`), since the app opens dark by default, and the app asks iOS for the reading white point (`UIWhitePointAdaptivityStyleReading`), so True Tone adapts it as it does a reading app.

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#131210` | `#EDEAE4` | Page |
| `surface` | `#1C1A17` | `#E6E3DC` | Cards, rows, sheets |
| `surfaceRaised` | `#25231F` | `#DAD6CE` | Icon tiles, tracks, the Apple tile, disabled and neutral buttons |
| `separator` | `#2D2B27` | `#CFCAC0` | Hairlines, between rows and around cards |
| `bar` | `#35332E` | `#C6C1B6` | Chart bars, dashed empty slots |
| `label` | `#EEECE6` · `#F7F5F0` | `#1A1C20` · `#0E0F11` | Text: 14.7:1 (dark) and 13.3:1 (light) on `surface` |
| `label2` | `#AAA69E` · `#C2BEB6` | `#4F5258` · `#3F4247` | Secondary text: 7.2:1 and 6.1:1 on `surface` |
| `label3` | `#77736B` · `#8E8A83` | `#72757B` · `#5B5E64` | Marks: 3.7:1 and 3.6:1 on `surface` |
| `accent` | `#E9B96E` · `#F2CD91` | `#744C0B` · `#5E3D09` | The one accent: main buttons, links, what is on. 5.9:1 on the light `surface`, 4.8:1 on its `accentSoft` |
| `accentSoft` | accent @ 14% | accent @ 14% | Leading tiles, "on" backgrounds |
| `onAccent` | `#1C1408` | `#F6F4EF` | Text on the accent: 10.1:1 and 6.9:1 |
| `ok` | `#86C9A9` | `#256B4D` | A number going the right way |
| `warn` · `warnSoft` | `#EE9E74` · @ 12% | `#8C3F1F` · @ 12% | Over a limit; deleting. 4.8:1 on the light `warnSoft` |

Your sky (D79) is the same night in both appearances; only the land under it follows light or dark. Your sleep opens onto it: full bleed under the status bar, about the top 45% of the screen at every text size, "Your sleep" set on it in the sky's `text`, and "N nights locked" with its moon on the land just under it. Its colours are `SkyColor` (`TollUI/Tokens/SkyColors.swift`):

| Token | Value | Use |
|---|---|---|
| `palette(.evening)` | `#05070F` → `#0C1030` → `#1F1D47` → `#3A2B4E`, glow `#E9B96E` @ 42% | Opened from 4 pm: dusk, the app's name |
| `palette(.night)` | `#04060D` → `#0A0E26` → `#141A3B`, glow `#2A3366` @ 35% | Opened from 9 pm: almost no glow |
| `palette(.morning)` | `#070A18` → `#131B3D` → `#2C3A5E` → `#4A5A7A`, glow `#B4C2D6` @ 45% | Opened from 5 am: cool, pale blue-grey |
| `star` · `line` · `newest` · `text` | `#EEECE6` · `#646B76` · `#E9B96E` · `#EEECE6` | Lit stars before their B–V tint · figure lines and names · the newest star · words on the sky |
| `lineBright` · `nameBright` | `#A2A8B2` · `#EEECE6` | Lines and names a tap brought forward |
| `dust` · `moon` | `#DDE3F0` at 7–35% · `#F1EEE4` | The fixed dust and the Milky Way · the moon, its earthshine at 10% |

- **Light:** three fixed palettes by the hour the screen opens (`TollConfig.sky`), with nothing moving between them. A vertical gradient, near-black blue at the top through deep indigo, and a low elliptical glow from the horizon's middle.
- **Land:** a low, gentle hill line in the page's own `bg`, with a fainter ridge (`bg` at 32%) behind it. Abstract: no houses, trees or home.
- **Atmosphere:** a fixed, seeded dust of tiny faint points (`SkyDust`), about half of them gathered along a soft diagonal Milky Way, which is two blurred strokes. None of it is a catalogue star; unlit stars are never drawn.
- **Stars:** lit stars only, sized by magnitude with a soft radial halo and tinted subtly by their real B–V (`StarColour`, 38% over `star`, so warm stars stay apart from the newest star's amber). Lines are thin `line`, stopping 3 pt short of each disc. A completed figure's name sits beside it in small spaced capitals in `line`, under or over the figure, wherever it covers no other name or star; where neither side is clear it is left off, as a chart declutters (VoiceOver names every one). Incomplete figures have none. Names and lines stay faint so the sky reads as a sky; a curious tap brings them forward (`SkyFocus`). A tap on the open sky (not within 22 pt of a lit star) brightens every name to `nameBright` and every line to `lineBright`, and another fades them; the empty sky has nothing to brighten. A tap within 22 pt of a lit star opens its night in a system popover and, while it is open, brings that star's own figure forward the same way (only its lines, if it is incomplete). Nothing is kept: Your sleep is faint again each time it appears. VoiceOver's sky element says every name, and its double-tap does what a tap on the open sky does, with the hint "Double-tap to show the names." Names never sit on the land.
- **Moon:** last night's real phase in the upper right, lit on the correct side for the night's place, the rest in a faint earthshine, with a halo that grows with the lit fraction.
- **The newest star** is `newest` with a stronger halo until the next night starts.
- **One renderer** (`SkyScene`) draws Your sleep, the landmark tile and the shared 1080 × 1920 poster (the evening light over dark land, the moon, named figures, "30 nights locked", the date small and a small wordmark).

All text ≥ 4.5:1 in both; Increase Contrast takes text and the accent further. The sky keeps its own values, so its names stay 4.5:1 on every light (D89). Appearance: Dark (default) · Light · Match iPhone, in Settings.

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
| Tonight's strip: a segment's snippet opens or closes | System popover (a system sheet at accessibility sizes), D75. A pressed segment or pill dims at once, with no motion. |
| Door: choosing → waiting → open | Content crossfades 300 ms inside the sheet; the sheet does not move. |
| Countdown | `contentTransition(.numericText(countsDown: true))` each second; the colon never blinks. |
| Regret line expires | Fades out 200 ms; nothing else moves. |
| A card or note arrives or leaves (Tonight, the block editor) | Fades 200 ms in place; nothing else moves. |
| Last night's card opens or closes | It grows up from its row, or shrinks back to it, over 300 ms; its content fades in after the first 100 ms; nothing else moves. With Reduce Motion, a 200 ms crossfade. |
| Your sky's newest star (D79), the first time Your sleep shows it | The star brightens from nothing over 450 ms (`firstAppearance`); then each line it adds draws from the star it joins over 450 ms, a trimmed path. Once. Reduce Motion: the star and its lines crossfade in 200 ms. Nothing twinkles, pulses or loops; a landmark line arrives with last night's card. |
| Your sky: a star's night opens or closes | System popover (a system sheet at accessibility sizes), as Tonight's strip. |
| Your sky's names brighten or fade (a tap on the open sky) | Crossfade 200 ms. A star's figure, while its night is open, the same. Nothing dims them on its own. |
| Your sleep's bar as the sky scrolls under it | None: it takes the page's colour at once. |
| Settings | System list and pushes. |
| Block screen (system) | None of ours; Apple animates the shield. |

Haptics: `.light` when the door's wait starts and when it ends; `.warning` before something that cannot be undone; `.selection` on picker changes. Nothing else.

Never: confetti, pulsing, looping, twinkling, parallax, rings that fill, typewriter text, shimmer, or any motion on the block screen.

### 2.6 Iconography

SF Symbols, monochrome, outline. **One symbol per concept, one concept per symbol** (#72), named in `TollSymbol` (`TollUI/Tokens/Symbols.swift`); no feature types a symbol string. App icons come from the system (`Label(token)`), never drawn by us. No coloured icon circles: tiles use `accentSoft` or `surfaceRaised`.

| Concept | Symbol |
|---|---|
| Sleep, a night · the night's end | `moon` · `sun.max` |
| A "Never mind" tap ("You chose sleep") · a personal best | `iphone.slash` · `arrow.up.to.line` |
| The heads-up before the night (the one notification, D68) | `bell` |
| Before bed's helpers (D80): the capsule and its card (the gap's own glyph) · tomorrow's list on paper · the breathing tone · the word game, eyes closed · the tone playing · stopping it | `moon.haze` · `pencil` · `wind` · `eye.half.closed` · `speaker.wave.2` · `speaker.slash` |
| Another block | its kind: `book`, `briefcase`, `bolt`, `ellipsis` |
| **State:** blocked now (also the hours apps were locked, D75) · starts later · away · off (the free week ended, or a block switched off; never a pause glyph, D70) · nothing can block · working with less (While Using) · waiting for Always | `lock` · `clock` · `figure.walk` · `power` · `exclamationmark.triangle` (warn) · `location.slash` · `hourglass.bottomhalf.filled` |
| A pause (the code's door and unlock, D67) · its wait | `pause` · `timer` |
| Apps on a blocklist · a block's hours | `square.grid.2x2` · `clock` |
| Home · another place · no place (anywhere) | `house` · `mappin` · `globe` |
| Current position, the Location permission · Precise | `location` · `scope` |
| Screen Time · weekends differ · wake time | `hourglass` · `calendar` · `alarm` |
| Done (also a block's hours that have ended today, on the strip's snippet, D75) · purchased · failed · waiting for approval · nothing found | `checkmark` · `checkmark.seal` · `xmark` · `person.badge.clock` · `magnifyingglass` |
| Leaves for iOS Settings · privacy | `arrow.up.forward.app` · `hand.raised` |
| Insights · Settings · add · delete · forward | `chart.bar` · `gearshape` · `plus` · `trash` · `chevron.right` |
| Last night's folded row opens · the open card folds back | `chevron.down` · `chevron.up` |
| Share Your sky's picture (landmark mornings only, D79) | `square.and.arrow.up` |

**State has a glyph, in the same place** (`StateLine`): before the eyebrow on Home, and with the word on every row and status value (`StatusValue`). When nothing will block (off, Screen Time off), the big time gives way to the state's glyph at 64 pt, with no tile: a filled tile reads as a button. **The eyebrow says what the big time means** (D75): "Apps lock at", "Apps locked until", "Paused until", "Night ends at"; never "Tonight" alone. **Tonight's strip is the whole day** (D75), from the night's end to the same time tomorrow: the night is a 24 pt amber bar with its moon, other blocks are 14 pt grey bars with their kind's glyph (shorter and a different symbol, never colour alone), solid while on, outlined before, faint once over, dashed when nothing will block; a 2 pt line marks now; hours every six on the clock. Each segment is a button at least 44 pt wide (segments too close to tap apart share one); its snippet shows the block's tile, state, hours, apps, place and "Edit ›". Last night sits at the strip's start, where it ended: a faint amber stub with its moon until the next night starts; a tap opens last night's card in the popover. Each morning until noon, last night also sits in Tonight's band folded to one row, as light as a card can be: the moon and "Last night", the outcome as a glyph and a few words (`lock` "Locked 8 h 45 m", `figure.walk` "Away, nothing locked", `hourglass` "Screen Time was off", or a landmark's line), and `chevron.down`. The whole row is one button; it opens into the full card, which grows up from the row with its bottom edge kept above the strip, its header folding it again with `chevron.up`, and "OK" beside that chevron. It is folded each time Tonight appears. Setup's and Blocks' night picture keep the night-only strip. **Counts are shapes** (`Pips`): the week's pauses as dots wherever they're shown; the blocks' limits as a bar (`CapacityBar`, the 40 apps and sites) and segments (the 8 time windows). A row Save is still waiting for has a dashed tile (`EmptyTile`). **Actions look like actions:** a screen's main action is a button, never a text link (Pause on Tonight is the exception: a quiet grey capsule by the dots, D61, D67, and "Lock again" in its place while a pause is open; "Before bed" in the gap is a second one under them, D80); links that act carry a glyph (`See all ›`, `+ New`, the free-week pill's `›`, D75); anything tappable dims while pressed (`tollPressable`); anything that leaves for Settings carries `arrow.up.forward.app` (`SettingsLink`). **Notes have a severity** (`NoteCard(severity:)`): info, degraded (`location.slash`), broken (`exclamationmark.triangle` on `warnSoft`).

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

How a screen earns it: one symbol per concept, used everywhere (a moon is Sleep, a pause symbol is a pause, a pin is a place); geometry for time and supply (the day's strip, the night picture, pips, bars); position that means the same thing on every screen (state at the top, the one action at the bottom); and colour only together with a shape or symbol (§4). This amends principle 4's "icons are rare" to "a symbol wherever it carries a concept". Decoration is still out.
