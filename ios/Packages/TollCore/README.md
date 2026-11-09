# TollCore

Domain model (spec §4), `TollConfig` (§14), `Copy` (§10), and pure logic: day/week math, wait ladder and free passes, status levels, schedules, spool format, metrics. No UI, no database, no network. Builds and tests on Linux.

Product `TollScreenTime` holds the FamilyControls / ManagedSettings / DeviceActivity glue the app and all three extensions share (shield application, session activities, token ↔ app ref map). Everything in it is `#if os(iOS)`.

Invariants
- Extensions link this package only; keep it small (DeviceActivityMonitor has ~6 MB).
- Time comes from an injected `TollClock`; nothing calls `Date()` directly.
- Tokens never leave the device. Events carry `AppRef`s.
