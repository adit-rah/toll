# datascience

Dusk's sleep model, built, fitted and tested in Python, following the founders' model spec ("Dusk internal: sleep model spec"; decisions D52 and D53). The app gets only a small JSON file of numbers (`artifacts/sleep-model.v1.json`; every earlier version is kept beside it) and the pure Swift package `ios/Packages/SleepModel`, which must give the same numbers as the reference here. Nothing in this folder is imported by the app, and nothing here needs the app.

```
dusk_model/   reference implementation: rng, artifact, night records, model, policy, the held week (timing), insights
sim/          synthetic people, six scenarios, the pass criteria, tuning, dampened start policies, the growing gap, a year of nights, figures
replay/       real nights in (Health export or Dusk's night records), prediction error out
economy/      the buffer suggestion's reference and fixtures (#145), and the buffer and pause studies (#61)
export/       writes the artifacts (v0.py, v1.py), the parity fixtures and the rebuild fixture; compares the Swift package (parity.py)
artifacts/    every exported version, kept; fixtures.jsonl; rebuild.json (a night log and the state rebuilt from it)
reports/      criteria.json, tuning.md, figures/
tests/        pytest
```

## Setup

[uv](https://docs.astral.sh/uv/) with the pinned lockfile; Python 3.13, numpy, matplotlib, pytest.

```bash
cd datascience && uv sync
```

## The model, in one paragraph

For each night the outcome is when the person fell asleep, in minutes from planned bedtime. A frozen base predicts it from 4 features: an intercept, the block's start offset per 30 minutes (−30, 0 or +30), weekend, and a late arrival home. Each person has 4 numbers that correct the base, learned by Bayesian linear regression one night at a time: a 4×4 precision matrix and a vector, one small solve a night. People who opt in get a start held for a week (D66): on each Monday, Thompson sampling picks −30, 0 or +30, with every allowed start kept at a 10% chance or more, and the start holds to Sunday. Once the insight shows, the start settles on the side it supports; once the 90% range is inside ±15 minutes, it settles at the plan; a settled person draws again about one week in 14, and settling is checked afresh every week. The exact chance of each week's start is logged on each of its nights (`dusk_model/timing.py`). The one insight is the start's effect: "When the block started 30 minutes earlier, you were asleep N minutes sooner (range A to B)". It shows after 14 usable nights, when its 90% range is narrower than 30 minutes and a stricter range is clear of zero: 98% up to 30 usable nights, then stricter as the nights add up (its miss chance falls as (30 / nights)²), so false insights stay under 5% for as long as Dusk is used (#117, `reports/longrun.md`). An insight already showing stays while the 98% range is clear of zero, and is withdrawn quietly when it isn't.

## Commands

| What | Command |
|---|---|
| Unit tests | `uv run pytest` |
| Pass criteria (about 3 min; includes a year of null nights) | `uv run python -m sim.criteria --people 2000 --safety-people 10000` |
| Tuning sweep (about 20 min) | `uv run python -m sim.tune` |
| Dampened start policies (about 5 min; `reports/dampening.md`) | `uv run python -m sim.dampen_sweep` |
| The growing gap with personal timing (about 3 min; `reports/gap.md`) | `uv run python -m sim.gap_sweep marks --out reports/gap-sweep.json` |
| A year of nights: false insights and learning (about 20 min; `reports/longrun.md` lists every run) | `uv run python -m sim.longrun --people 1000 --out reports/longrun-sweep.json` |
| Export the artifact and fixtures | `uv run python -m export`, then `../ios/scripts/sync-model.sh` |
| Swift against Python | `uv run python -m export.parity` (needs Swift) |
| Figures | `uv run python -m sim.figures` |
| Replay your own Health data | `uv run python -m replay --health path/to/export.xml --bedtime 23:00 --weekend-bedtime 23:30` |
| Replay Dusk's night records | `uv run python -m replay --records nights.jsonl` |
| The buffer suggestion's fixtures for TollCore (#145) | `uv run python -m economy.fixtures` |
| The buffer suggestion in the simulator (`reports/buffers.md`) | `uv run python -m economy.buffers --people 2000 --out reports/buffers-final.json` |
| The pause economy (`reports/pauses.md`, #61) | `uv run python -m economy.pauses grid --out reports/pauses-grid.json` |

The Health export is from the Health app: Profile › Export All Health Data, then unzip it. Only sleep samples are read, and nothing leaves the laptop. Until the app logs night records, each night is replayed with the block at plan.

## Shipping a new artifact

1. Add `export/vN.py` with a new version string and list it in `export/versions.py`; the last one listed is the one the app carries. Never change a version that has shipped.
2. `uv run python -m sim.criteria` must pass, and `reports/tuning.md` says why the numbers changed.
3. `uv run python -m export && ../ios/scripts/sync-model.sh`, then `swift test --package-path ../ios/Packages/SleepModel`.
4. Commit the artifact, fixtures and Swift copies together. The weight change is reviewed as a diff.

CI (`.github/workflows/model.yml`) checks every step: the unit tests, that the committed files are exactly what the code exports, the checksum, that the Swift package holds the same files, the pass criteria, and the Swift tests on Linux. `ios.yml` runs the Swift tests again on macOS.

## Results (sleep-model.v1)

2,000 simulated people per scenario, 8 weeks each; safety over 10,000; the null for a year over 2,000 (`reports/criteria.json`). v0's results, from the same command when it shipped, are beside them.

| Check | Pass mark | v1 | v0 | |
|---|---|---|---|---|
| Ranges are honest | 90% ranges hold the truth for 85–95%, every scenario | 89.8–93.5% | 89.1–93.3% | Pass |
| Helps when people differ | Earlier sleep than always the plan | 5.4 min a night earlier (7.6 in weeks 5–8) | 5.8 min | Pass |
| Little harm when they don't | At most 5 min a night worse | 0.3 min earlier | 0.5 min earlier | Pass |
| No false insights | At most 5% shown an effect under the null, by night 56 | 3.2% | 3.7% | Pass |
| No false insights over a year (#117) | The same, by night 364 | 3.9% (six other runs: 3.1–5.0%, mean 3.8%) | 11.1% (`longrun.md`) | Pass |
| Learns fast enough (D66) | Half of people with an effect of 15 min or more, by night 56 | 53% (six other runs: 50–54%) | 56% | Pass |
| Learns fast enough (spec) | Median person gets an insight by night 28 | 16% by night 28 | 13% | Waived (D53, D66) |
| Calm | D66: the start changes about once in two weeks | 0.49 changes a week (differ) | 2.7 (`dampening.md`) | |
| Never unsafe | No start outside the allowed ones; wake time never moves | 0 and 0 in 476,209 block nights | 0 and 0 | Pass |
| Same numbers on the phone | Every fixture passes | 17,422 values over 638 nights in 12 cases, identical on Linux | 8,853 over 323 | Pass |
| Better than the base | Lower error after 3 weeks (replay) | Synthetic Health exports: 78% of people; founders' and pilot data pending | 78% | Not yet run on real data |

![Coverage](reports/figures/coverage.png)
![Benefit](reports/figures/benefit-by-week.png)
![Insights by night](reports/figures/insights-by-night.png)
![Insights by effect](reports/figures/insights-by-effect.png)
![Example person](reports/figures/example-person.png)
![Parity](reports/figures/parity.png)
![Replay](reports/figures/replay.png)
![False insights over a year](reports/figures/false-insights-year.png)

## What the simulator can't tell us

It tests the method, not Dusk: every scenario is an assumption, and the people in it fall asleep the way we wrote them to. The replay harness on the founders' Health exports is the first real test, then the pilot (model spec, section 4).
