# TollFeatures

One folder per screen (spec §8, design §4): a `View` and a `@MainActor @Observable` model holding UI state only. Services arrive through `Dependencies` in `init`. `RootView` routes launch per spec §9 (O-1…O-6).

Invariants
- No business rules here: they live in `TollCore`, and models call into it.
- Every string comes from `Copy`.
