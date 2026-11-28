# SleepModel

The phone's half of Dusk's sleep model: it reads the artifact exported from `datascience/`, updates one person's 4 numbers each night, picks the block start for people who opted in (held for a week and settling, D66), and states the one insight. All fitting, simulation and evaluation happen in Python (`datascience/README.md`).

Foundation only (no UIKit, HealthKit, Accelerate or simd), so `swift test --package-path ios/Packages/SleepModel` runs on Linux. The tests replay `Tests/SleepModelTests/Fixtures/fixtures.jsonl`, written by the Python reference, and must match to 1e-9 with identical chosen starts and generator state. On Linux they match bit for bit.

| File | What it does |
|---|---|
| `ModelArtifact.swift` | Decodes and validates the artifact; `bundled()` falls back to `builtIn` if the file is missing or invalid, so the block never depends on the model |
| `NightRecord.swift`, `LocalTime.swift` | The night record (contract 1) and what the model takes from it; skip rules in the reference's order |
| `PersonState.swift` | One person's numbers, as `model.json` keeps them; older caches read with the newer fields empty |
| `SleepModel.swift` | The nightly update and prediction |
| `SleepModel+Wander.swift` | Schema 3 (#154): the usual time may move between weeks, and each person's noise has a scale, learned from week sums of residuals; ranges are drawn from the scaled covariance and the zero tests are a t's |
| `SleepModel+Policy.swift` | Thompson sampling with a floor; returns the chance the chosen start had |
| `Hold.swift` | Personal timing's week (D66): `chooseStart` keeps a start Monday to Sunday, settles at the insight or at the plan, explores about one settled week in 14, and logs the exact chance; `Hold.latest` gives the hold back from the night log |
| `Insight.swift` | The start-time insight and its rule; the zero test tightens past `zero_test_spend_after` usable nights (#117) |
| `SeededRNG.swift` | SplitMix64 + Box–Muller, the same stream as Python |
| `Replay.swift` | One night at a time, as the app would; shared by the tests and `sleep-model-replay` |

Never edit `Resources/sleep-model.v2.json` or the fixtures by hand: run `uv run python -m export` in `datascience/`, then `ios/scripts/sync-model.sh`. CI fails if they differ (`ios/scripts/sync-model.sh --check`) or the checksum is wrong (`ios/scripts/check-model-artifact.sh`).

The app links it to keep `model.json` (TollData's `ModelStore`, #140) and, for a person who chose personal timing, to choose the week's start (`ModelStore.choose`, #155); TollCore keeps that start in force for every process and logs it in the night records. Nothing shows the insight yet. What the app owes the model is listed in `docs/decisions.md` D52.
