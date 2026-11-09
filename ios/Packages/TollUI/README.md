# TollUI

Design tokens and components from `docs/toll-design.md` §2–§3. Views only; no services. iOS only.

- `Tokens/` — `TollColor`, `TollFont` / `TollText` / `HeroNumber`, `TollSpacing` / `TollRadius` / `Hairline` / `.tollGutter()`, `Motion` (and the Reduce Motion modifiers), `Haptic` / `Haptics`.
- `Status/` — `StatusGlyph` with `StatusMark`, `HeroStat`, `MetricPair`.
- `Rows/` — `Avatar`, `FriendRow`, `PinnedRow`, `MutualRow`, `SectionHeader`, `TrendLabel`, `AccessibilitySentence`.
- `Gate/` — `WaitCard` (countdown, session picker, first-wait naming), `WaitOverlay`, `WaitOverlayBackdrop`, `ChoiceChip`, `TagChips`, `FlowLayout`.
- `Controls/` — `PrimaryButton`, `QuietButton`, `DestructiveQuiet` and their styles, `EmptyState`, `FilledField`, `CodeBoxes`.
- `Blocks/` — `BlockRow`, `IconCluster`, `WhenChips`.
- `Charts/` — `ChartCard`, `WeekStrip`.
- `Setup/` — `ProgressSegments`, `ScreenTitle`. `Share/` — `ShareCardFrame`.

Invariants
- Colours come from `TollColor` with light, dark and increased-contrast values; one accent on screen.
- Text comes from `Copy` or a parameter; components never hold copy of their own.
- App names from Screen Time are view slots (`Label(token)`), never strings.
- Numbers use monospaced digits. Motion comes from `Motion` (design §2.5) and respects Reduce Motion.
- Every control has a 44 pt hit area; rows stack at accessibility sizes; level is shown by glyph shape.
