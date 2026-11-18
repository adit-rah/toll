# TollCore

`TollConfig` (MVP spec §10), `Copy` (§7, §8) and the pure logic: window maths, the block rule, reconcile decisions, the door, unlocks and trial nights. No UI, no persistence beyond App Group files, no network. Builds and tests on Linux.

Product `TollScreenTime` holds the FamilyControls / ManagedSettings / DeviceActivity glue the app and the extensions share. Everything in it is `#if os(iOS)`.

Invariants
- Extensions link this package only; keep it small (the monitor has ~6 MB).
- Time comes from an injected `TollClock`; logic never calls `Date()` directly.
