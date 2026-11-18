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

- **Grid:** 8 pt base. Horizontal gutter 20 pt (16 pt at 375 pt wide). Section gap 32 pt. Card padding 16 pt. Row height ≥ 52 pt.
- **Titles sit at one position on every screen** (MVP spec §7): 34 pt semibold, 28 pt under the 44 pt bar, leading-aligned to the gutter (`ScreenTitle`).
- **Weight falls monotonically.** One title or state line, then facts of equal weight beneath.
- **Group with whitespace first, separators second, cards third.** Settings uses a standard grouped list.
- **A fill must differ from its page.** `surfaceRaised` on `bg`, `surface` on `bgGrouped`; `fill` where the host varies.
- **Nothing stretches to fill.** Spare room on a tall phone becomes space above the bottom action.
- **Bottom actions** sit 12 pt above the bottom safe area on a bar of the page's own colour (`tollBottomBar`).

### 2.2 Type

SF Pro via Dynamic Type styles only. Countdown numerals use `.rounded`, semibold, `.monospacedDigit()`; all other numbers `.monospacedDigit()`.

| Token | Style | Use |
|---|---|---|
| `hero` | 72 pt rounded semibold, tracking −2.5, scales with `@ScaledMetric`, caps at AX2 | The door's countdown |
| `screenTitle` | Large Title 34 semibold | Screen titles |
| `title` | Title2 22 semibold | Status's state line |
| `headline` | Headline 17 semibold | Buttons |
| `body` | Body 17 regular | Lines, settings rows |
| `subhead` | Subheadline 15, secondaryLabel | One-line explanations |
| `caption` | Footnote 13, secondaryLabel | Quiet facts |

Never more than three sizes on one screen. Line length ≤ 60 characters.

### 2.3 Colour

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | systemBackground | system | Screen background |
| `bgGrouped` | systemGroupedBackground | system | Settings |
| `surface` | secondarySystemGroupedBackground | `#1C1C1E` | Cards, rows |
| `surfaceRaised` | tertiarySystemGroupedBackground | `#2C2C2E` | Cards on `bg` |
| `fill` | tertiarySystemFill | tertiarySystemFill | Disabled buttons |
| `label` / `label2` / `label3` | system tiers | system tiers | Text |
| `separator` | system | system | Hairlines |
| `accent` | `#3A6EA5` | `#8FB4E3` | Primary action, selected state. **Placeholder.** |
| `accentSoft` | accent @ 12% | accent @ 18% | Selected backgrounds |

All text ≥ 4.5:1 in both modes; hero ≥ 3:1; Increase Contrast variants on the accent.

### 2.4 Shape and depth

Radii: card 16, row in card 12, sheet 20, chip 8, button 12. No elevation in light mode; dark mode uses surface tiers, no shadows. Materials on system bars only.

### 2.5 Motion and haptics

Motion explains where things came from and where they went. It never celebrates, never loops, never asks to be noticed. Three durations: 200 ms (state changes), 300 ms (things moving), 450 ms (first appearance). One spring: response 0.35, damping 0.85, ≤ 2% overshoot. Reduce Motion replaces every move or scale with a crossfade of the same duration; numeric transitions stay. **If a transition is not in this table, there is none.**

| Moment | Motion |
|---|---|
| Setup step push | The system navigation transition. The progress segment fills left to right over 250 ms as the new screen lands. |
| Returning from the system picker | Chosen items are already listed; they fade in and rise 6 pt with a 40 ms stagger, once. |
| A permission row changes | Its status text crossfades 200 ms. |
| Status state line changes | Crossfade 200 ms. Numbers in it use `numericText`, 300 ms. |
| Door sheet opens or closes | System sheet. |
| Door: choosing → waiting → open | Content crossfades 300 ms inside the sheet; the sheet does not move. |
| Countdown | `contentTransition(.numericText(countsDown: true))` each second; the colon never blinks. |
| Regret line expires | Fades out 200 ms; nothing else moves. |
| Settings | System list and pushes. |
| Block screen (system) | None of ours; Apple animates the shield. |

Haptics: `.light` when the door's wait starts and when it ends; `.warning` before something that cannot be undone; `.selection` on picker changes. Nothing else.

Never: confetti, pulsing, looping, parallax, rings that fill, typewriter text, shimmer, or any motion on the block screen.

### 2.6 Iconography

SF Symbols, monochrome. A gear for Settings, chevrons in lists. No coloured icon circles. App icons on the door come from the system (`Label(token)`), never drawn by us.

## 3. Buttons

- `PrimaryButton`: full width, 50 pt, `accent` fill, `headline` label (white in light; `#0F1115` in dark, where white fails on the light accent). One per screen. Disabled: `fill` with a `label3` title.
- `QuietButton`: text only, `accent`, body medium, 44 pt hit area. "Not now", "Cancel", "Restore purchase".
- `DestructiveQuiet`: text only, systemRed. Not used yet.

## 4. Accessibility

- Dynamic Type to AX5. Lines wrap, never truncate; the countdown caps at AX2.
- VoiceOver: every control has a label; the countdown is spoken in 30 s steps and announced every 30 s, never every second; Status's lines read as one sentence each.
- Colour never carries meaning alone.
- Contrast and Increase Contrast variants for every token. Touch targets ≥ 44 pt.
