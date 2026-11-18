# TollFeatures

One folder per screen (MVP spec §7): a `View` and a `@MainActor @Observable` model holding UI state only. `App/RootView` is the one window.

Invariants
- No business rules here: they live in `TollCore`, and models call into it.
- Every string comes from `Copy`.
