# SleepModel

The phone's half of Dusk's sleep model: it reads the artifact exported from `datascience/`, updates one person's 4 numbers each night, picks tonight's block start for people who opted in, and states the one insight. All fitting, simulation and evaluation happen in Python (`datascience/README.md`).

Foundation only (no UIKit, HealthKit, Accelerate or simd), so `swift test --package-path ios/Packages/SleepModel` runs on Linux. The tests replay `Tests/SleepModelTests/Fixtures/fixtures.jsonl`, written by the Python reference, and must match to 1e-9 with identical chosen starts and generator state. On Linux they match bit for bit.

| File | What it does |
|---|---|
| `ModelArtifact.swift` | Decodes and validates the artifact; `bundled()` falls back to `builtIn` if the file is missing or invalid, so the block never depends on the model |
| `NightRecord.swift`, `LocalTime.swift` | The night record (contract 1) and what the model takes from it; skip rules in the reference's order |
| `SleepModel.swift` | State, nightly update, prediction |
| `SleepModel+Policy.swift` | Thompson sampling with a floor; returns the chance the chosen start had |
| `Insight.swift` | The start-time insight and its rule |
| `SeededRNG.swift` | SplitMix64 + Box–Muller, the same stream as Python |
| `Replay.swift` | One night at a time, as the app would; shared by the tests and `sleep-model-replay` |

Never edit `Resources/sleep-model.v0.json` or the fixtures by hand: run `uv run python -m export` in `datascience/`, then `ios/scripts/sync-model.sh`. CI fails if they differ (`ios/scripts/sync-model.sh --check`) or the checksum is wrong (`ios/scripts/check-model-artifact.sh`).

The app does not link this package yet; what it owes the model is listed in `docs/decisions.md` D52.
