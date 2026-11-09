# Toll — Visual Identity (not yet designed)

Toll has a name and a bundle id (`com.advan.toll`) and nothing else. The design doc and mockups use placeholders so the build is not blocked. This note says what is placeholder, what the identity needs to supply, and the constraints it has to respect.

## Placeholders in use

- **Accent:** `#3A6EA5` light / `#8FB4E3` dark. One token (`accent`); swapping it restyles buttons, "you" in charts, links and the pinned-row bar.
- **Type:** SF Pro (Inter stands in on the web mockups). Hero numerals in SF Pro Rounded semibold.
- **Wordmark:** the word TOLL in semibold caps with a ring glyph beside it, on share cards only.
- **App icon:** a white ring on near-black, used on the shield mockup. Placeholder.
- **Status glyphs:** shape-based (filled / half / ring-with-dot) in Okabe-Ito-derived colours. These are functional, not brand, and can stay.

## What the identity needs to supply

1. Wordmark (and whether the app name appears in the UI at all; currently it does not).
2. App icon, light and dark variants, plus the tinted variant iOS 26 asks for. Must read at 29 pt.
3. One accent colour with light and dark values that pass 4.5:1 on `#FFFFFF` and `#1C1C1E` for 17 pt text.
4. Optional: a display face for the hero numeral only. Body stays SF Pro.
5. Share-card frame: how the wordmark and invite link sit on the card (currently bottom corners).
6. Store assets: six screenshots (from the mockup screens), a 1024 icon, and the poster for campus.

## Constraints the identity must keep

- One accent on screen. No gradients in UI, no coloured icon circles, no illustration system.
- Nothing harsh in either appearance: dark mode uses raised grays, never pure-black cards on pure black; accents are desaturated in dark mode.
- Level is never carried by colour alone (glyph shape does it).
- Tone of the mark matches the copy: plain, factual, no mascot, no personality fluff.
- Everything lives in one asset catalog with light / dark / increased-contrast variants and swaps in without touching layout.
