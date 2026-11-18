# TollUI

Design tokens and components from `docs/design.md`. Views only; no services. iOS only.

- `Tokens/` — `TollColor`, `TollFont` / `TollText` / `HeroNumber`, `TollSpacing` / `TollRadius` / `Hairline` / `.tollGutter()`, `Motion` (and the Reduce Motion modifiers), `Haptic` / `Haptics`.
- `Controls/` — `PrimaryButton`, `QuietButton`, `DestructiveQuiet` and their styles, `EmptyState`.
- `Setup/` — `ProgressSegments`, `ScreenTitle`, `.tollBottomBar`.

Invariants
- Colours come from `TollColor` with light, dark and increased-contrast values; one accent on screen.
- Text comes from `Copy` or a parameter; components never hold copy of their own.
- App names from Screen Time are view slots (`Label(token)`), never strings.
- Numbers use monospaced digits. Motion comes from `Motion` (design §2.5) and respects Reduce Motion.
- Every control has a 44 pt hit area.
