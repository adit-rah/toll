# False insights over a year

The mark "a non-zero effect shown to at most 5% of people when the start does nothing" was set at night 56 (D53, D66). The insight is checked every night for as long as Dusk is used, so the share of people ever told about an effect that isn't there keeps growing after night 56. `gap.md` found D66's policy at 5.0% by week 12, and 6.9% with drift (#117). This report measures it over a year, tunes a fix, and says what the fix costs. The fix ships in `sleep-model.v1`; section 7 is v2's, for a usual time that moves (#154).

```
uv run python -m sim.longrun --people 1000 --out reports/longrun-sweep.json                  # every variant, seed 7
uv run python -m sim.longrun --people 2000 --seed 20261127 --only v0,d66,v1 --out reports/longrun-final.json
for s in 101 202 303 404 505 606; do uv run python -m sim.longrun --people 2000 --seed $s --only v1 \
  --scenarios null,differ --out seed$s.json; done
uv run python -m sim.longrun --pool seed*.json --out reports/longrun-seeds.json
uv run python -m sim.criteria          # the pass criteria, with the null run for a year
```

The runs use the simulator's own loop (`sim.run`) with the policy and the insight rule the phone runs (`dusk_model.timing`, `dusk_model.insights`), so every number here is the reference model's, not a stand-in. Each variant is an artifact: `export/v1.py` with some numbers changed (`sim/longrun.py` lists them). The people and their nights are the same as in `sim.criteria`, run for 52 weeks.

## What is compared

- **v0**: the shipped artifact before this one. A new start every night.
- **D66, fixed zero test**: D66's held, settling week (below), with v0's 98% zero test at every night. This is #117 as found.
- **v1**: the same policy, and a zero test that tightens after 30 usable nights.

D66's policy, as built in `dusk_model/timing.py`: on a week's first night the start is drawn by Thompson sampling with the 0.10 floor and held to Sunday; a person is settled if the insight shows (the start goes to the side it supports) or, after 14 usable nights, if the 90% range lies inside ±15 minutes (the plan); a settled person draws again in 7% of weeks. Two choices differ from `sim/dampen.py`, where `dampening.md`'s numbers come from. Settling is checked only on a week's first night, so the start never moves mid-week. And it is checked afresh every week, so a person whose insight no longer holds draws again, which `dampening.md` proposed but did not simulate.

## Scenarios

The six scenarios of `sim.criteria` and two kinds of background change in each person's usual time to fall asleep:
- **drift**: `dampening.md`'s random walk, 2 minutes a night. Over 8 weeks it wanders about 15 minutes; over a year about 38, which carries the 8-week stress past where it means much.
- **wander**: new here, for a year. The usual time wanders by about 15 minutes and comes back, with a memory of about 4 weeks (an AR(1) process with sd 15 and correlation e^(−1/28) a night). It stands for seasons, a new job, a hard month.

## 1. #117 measured: false insights by week

2,000 people per scenario, seed 20261127 (`longrun-final.json`). The share of people ever shown an insight by week 8 / 12 / 26 / 52.

| Start does nothing | v0 | D66, fixed zero test | **v1** |
|---|---|---|---|
| null | 4.5 / 6.1 / 9.2 / 11.1 | 4.2 / 5.3 / 7.6 / 9.8 | **4.0 / 4.2 / 4.5 / 4.5** |
| null + wander | 5.3 / 7.9 / 16.2 / 25.8 | 6.3 / 10.0 / 20.1 / 30.9 | 6.0 / 7.5 / 10.1 / 12.3 |
| null + drift | 5.5 / 8.2 / 16.0 / 29.8 | 5.0 / 7.1 / 14.9 / 31.6 | 4.4 / 5.1 / 7.2 / 12.8 |

![False insights over a year](figures/false-insights-year.png)

With one fixed test, nothing stops the share from growing: v0 reaches 11% in a year and D66's policy 10%. The held week isn't the cause. D66 is slightly lower than v0 under the null, because about three quarters of null people settle at their own time and then explore only one week in 14.

## 2. The fixes tried

1,000 people per scenario, seed 7 (`longrun-sweep.json`). Ever shown under the null by week 8 / 12 / 26 / 52; with drift at week 52; then "differ": people with an effect of 15 minutes or more who get an insight by night 56 (the D66 mark, at least 50%), and everyone ever shown one in a year.

| Tried | Null | Null + drift, a year | ≥15 by night 56 | Differ, a year |
|---|---|---|---|---|
| v0 | 3.4 / 4.8 / 7.4 / 9.6 | 27.7 | 50.4 | 64.8 |
| D66, fixed 98% zero test | 3.0 / 4.3 / 6.0 / 9.0 | 30.5 | 47.6 | 61.9 |
| *A stricter fixed test* | | | | |
| 99% | 1.4 / 2.1 / 3.0 / 4.3 | 23.2 | **44.4** | 55.3 |
| 99.5% | 0.9 / 1.2 / 1.6 / 2.1 | 16.8 | **40.6** | 48.8 |
| *98%, tightening after n usable nights as (n / nights)^k* | | | | |
| n 28, k 1 | 2.8 / 3.4 / 4.1 / 4.5 | 18.9 | 47.1 | 49.5 |
| n 28, k 1.5 | 2.6 / 3.1 / 3.3 / 3.4 | 15.7 | 46.4 | 46.1 |
| n 40, k 1 | 3.0 / 3.8 / 4.6 / 5.0 | 21.3 | 47.6 | 51.3 |
| n 40, k 1.5 | 3.0 / 3.8 / 4.3 / 4.5 | 18.6 | 47.4 | 48.0 |
| n 40, k 2 | 3.0 / 3.8 / 4.1 / 4.1 | 16.3 | 47.4 | 46.3 |
| n 56, k 1.5 | 3.0 / 4.1 / 5.1 / 5.5 | 21.4 | 47.6 | 51.3 |
| n 56, k 2 | 3.0 / 4.1 / 5.1 / 5.3 | 19.5 | 47.6 | 49.4 |

Seed 7 is an unlucky draw for learning: v0 gets 50% here and 54–58% elsewhere. Compare within the table. The sweep ran before v1 kept a showing insight on the 98% test (section 4); that changes nothing in this table.

The finalists were rerun on six more seeds of 2,000 people (null and differ only; a year under the null, the D66 mark at night 56):

| n, k | Null, a year: mean (lowest–highest) | ≥15 by night 56: mean (lowest–highest) |
|---|---|---|
| 40, 2 | 4.5 (3.5–5.9) | 53.8 (51.8–56.1) |
| 34, 2 | 4.1 (3.2–5.5) | 53.1 (51.0–55.3) |
| 28, 1.5 | 4.0 (3.2–5.2) | 52.3 (50.1–54.4) |
| 28, 2 | 3.6 (2.9–4.9) | 51.7 (49.5–53.6) |
| **30, 2 (v1)** | **3.8 (3.1–5.0)** | **52.2 (49.9–54.4)** |

The v1 row is `longrun-seeds.json`; the others are the same seeds run before v1 was chosen.

## 3. What we learned

- **A fixed test can't hold a mark for an open-ended time.** Each night is one more look, and with forgetting (a night's weight halves in about 10 weeks) the estimate keeps moving, so new chances to cross never stop. Any fixed test only moves the year's number, and a test strict enough for a year (99.5%) costs 7 points of the D66 learning mark at night 56.
- **Most false insights come before week 8, and those can't be removed without losing learning.** Under the null, v1 has 3.1% by week 8 on average and 3.8% by week 52. The 98% test before night 56 is what the D66 learning mark is tuned on, so the tightening has to start late. Starting it at 56 usable nights (about 11 weeks) lets too much through in weeks 8 to 26: 5.1% by week 26 and 5.3–5.5% in a year. Starting at 28–34 nights (about 6 to 7 weeks) costs one or two points of the learning mark and keeps a year near 4%.
- **The power sets the long tail.** With k = 1 the share still grows by about half a point after week 26. With k = 2 almost nothing is added: v1 adds 0.0–0.1 points from week 26 to 52.
- **Chosen: tighten after 30 usable nights, with k = 2.** It keeps the null under 5% for a year in five of six runs and at 5.0% in the sixth (3.9% in the pass criteria's own run), and the D66 mark at 52% on average (49.9–54.4%, 52.6% in the pass criteria). Both marks sit close to their lines; neither can move without the other.
- **The cost is later insights for real effects.** Among "differ" people, 43% get an insight within a year under v1, against 62% under D66's fixed test; for effects of 15 minutes or more, 77% against 95%. Insights by night 56 barely change (27.0% against 27.9%). The sleep benefit doesn't depend on the insight: −8.4 min a night over the year in "differ", against −8.6 for D66 and −7.9 for v0.
- **Wrong-side insights fall.** Shown with the wrong sign within a year, in "differ": 0.2% under v1, 0.4% under D66, 0.5% under v0; with the wander, 1.2%, 3.8% and 2.4%.

## 4. A showing insight keeps the 98% test

With a test that tightens with the nights, an insight that showed at night 40 had to pass a stricter test at night 200 to keep showing. With a settled start, the estimate of the start's effect slowly widens (forgetting, and few nights at other starts), so most insights were taken away again only because time passed: in "differ", 12% of people still saw one at the end of the year, against 27% under D66.

v1 keeps a showing insight while the 98% range is clear of zero, and withdraws it quietly when it isn't. The stricter test applies only to an insight that isn't showing. The person's state carries whether it showed after the last night (`shown`), so a rebuild from the night log gives it back. This never changes who sees an insight first, so every false-insight number above is the same. At the end of the year 19% of "differ" people see an insight, the sleep benefit is −8.4 min a night against −8.1 without it, and the start changes 0.28 times a week against 0.30.

## 5. What it doesn't fix: background change

A stricter test doesn't fix background change. With the wander, false insights reach 6.0% by week 8 and 12.3% in a year; with the random walk, 12.8%. v1 is much better than v0 or D66 here (26–32%), but well above 5%.

The cause is the model, not the test. The model treats each night's noise as independent and lets the usual time move only through forgetting. When the usual time wanders for weeks, nights close together share an error, the posterior is too sure, and a held week's start lines up with a week's wander. Under the wander, coverage at night 56 is 85.9% in "differ" (85.7% at a year), at the bottom of the band.

The fix would be to let the model's intercept wander too (a little process noise on the usual time each night, a Kalman step). That is a change to the model's update, so to the Swift package's arithmetic, and it will cost learning, because a held week's contrast is exactly what a wandering intercept explains away. It needs its own ticket, and how much real people's usual time wanders is something the pilot's night records can measure. It got one (#154): section 7, `sleep-model.v2`.

## 6. What the policy does over a year (v1)

From `longrun-final.json`, "differ" unless named:
- **Calm:** the start changes 0.28 times a week over the year (D66 0.27, v0 2.28).
- **Settled at the end of the year:** 49% of "differ" people, 28% at the plan; 75% of null people (72% at the plan).
- **Coverage** of the 90% range: 89.4% at night 56 and 94.0% at night 364.
- **Safety:** in the pass criteria's 10,000 people, no start outside a person's limits and no wake time moved, over 476,209 block nights. The smallest logged chance is 0.007 (a settled person's exploring week, 0.07 × 0.10).

## 7. The usual time moves (#154, `sleep-model.v2`)

```
uv run python -m sim.longrun --people 2000 --seed 20261127 --only v1,v2 --out reports/longrun-wander.json
g=$(uv run python -c "from sim.profiles import PROFILES; print(','.join('null+' + p for p in PROFILES))")
uv run python -m sim.longrun --people 1000 --scenarios null,null+wander,null+drift,differ,$g \
  --out reports/longrun-wander-sweep.json --only v1,w5-k0,w10-k0,w0-k5-z98,w0-k5-z96,w0-k5-z95,w0-k5-z94,\
w3-k5-z95,w0-k5-z95-x25,w0-k5-z95-m21,w0-k5-z95-m28,w0-k5-z94-m28,w0-k7-z94-m28,w0-k5-z94-m35,v2      # seed 7
for s in 101 202 303 404; do uv run python -m sim.longrun --people 2000 --seed $s --only v2 \
  --scenarios null,null+wander,null+drift,differ,$g --out vseed$s.json; done
uv run python -m sim.longrun --pool vseed*.json --out reports/longrun-wander-seeds.json
```

A variant's name says what it changes on v1 (`sim.longrun.wander_variant`): `w` the intercept's wander a week, in minutes; `k` the nights of κ = 1 the noise's scale starts from; `z` the base zero test, in percent; `n` the usable night the test starts to tighten after; `m` the usable nights before any insight; `x` the widest shown range.

### How much a usual time moves

Section 5's wander (sd 15 minutes, a memory of about 4 weeks) and drift were guesses. `sim/profiles.py` adds a grid of nine invented profiles that bracket how much people's usual time moves. Its range was checked against a real Health export (n=1, private); none of the profiles is that export. In each, the usual time is set week by week, Monday to Sunday, by an AR(1) across weeks, so a week's level lines up with a held week's start: the hard case. The grid crosses a level of sd 20, 45 or 90 minutes with a memory from one week to the next of 0.2, 0.6 or 0.95 (all four corners and the middle), and four of the nine put heavy tails on the nights: 15% or 40% of nights drawn with sd 150 or 240 minutes in place of the simulator's own nightly noise. A name says it: `l90-r0.2-t40-240` is level sd 90, memory 0.2, 40% of nights with sd 240.

2,000 null people per scenario, seed 20261127 (`longrun-wander.json`), the share ever shown an insight by week 8 / 12 / 26 / 52:

| Start does nothing | v1 | **v2** |
|---|---|---|
| null | 4.0 / 4.2 / 4.5 / 4.5 | **1.7 / 1.8 / 1.9 / 1.9** |
| + wander (section 5) | 6.0 / 7.5 / 10.1 / 12.3 | **2.0 / 2.2 / 2.4 / 2.4** |
| + drift | 4.4 / 5.1 / 7.2 / 12.8 | **2.4 / 2.8 / 2.9 / 2.9** |
| + l20-r0.2 | 17.6 / 21.3 / 25.1 / 28.6 | **4.0 / 4.5 / 4.6 / 4.6** |
| + l20-r0.95 | 4.5 / 5.4 / 7.2 / 11.2 | **2.3 / 2.5 / 2.5 / 2.6** |
| + l45-r0.6 | 34.5 / 46.1 / 65.8 / 80.0 | **3.3 / 3.5 / 3.6 / 3.6** |
| + l90-r0.2 | 55.5 / 68.7 / 86.0 / 96.0 | **0.6 / 0.7 / 0.7 / 0.7** |
| + l90-r0.95 | 18.2 / 27.6 / 51.2 / 73.0 | **1.9 / 2.1 / 2.4 / 2.4** |
| + l45-r0.6-t15-150 | 36.2 / 46.8 / 65.0 / 76.6 | **2.3 / 2.6 / 2.7 / 2.7** |
| + l20-r0.95-t40-150 | 20.2 / 23.9 / 29.9 / 35.9 | **3.8 / 4.2 / 4.3 / 4.3** |
| + l90-r0.2-t40-240 | 46.0 / 57.8 / 76.3 / 88.8 | **0.7 / 0.8 / 0.9 / 0.9** |
| + l90-r0.95-t15-240 | 21.8 / 30.9 / 52.7 / 72.9 | **1.8 / 2.1 / 2.2 / 2.2** |
| same (an effect of 3 minutes) | 4.4 / 4.9 / 5.1 / 5.2 | 3.0 / 3.2 / 3.3 / 3.3 |

**v2's worst case across the grid is 4.6% within a year** (l20-r0.2) in this run, 3.9% in the 1,000-person sweep, and 3.9% at most over four more seeds of 2,000 (`longrun-wander-seeds.json`: means 0.6–3.6% per profile; null 2.3%, wander 2.6%, drift 2.6%). In the pass criteria's own run it is 4.0% (l20-r0.95-t40-150). At night 56, v1's 90% range held the truth for 33–91% of null people across the grid; v2's for 86–93%.

The hardest profiles for v2 are the mild ones, not the wild ones: with a level of sd 90 nobody's range gets narrow enough to show an insight, but a level of sd 20 moves little enough that a week's start can look like its cause.

### What was tried

1,000 people per scenario, seed 7 (`longrun-wander-sweep.json`). Ever shown within a year under the null, and the grid's worst profile; then "differ": people with an effect of 15 minutes or more who get an insight by night 56 (the D66 mark), and everyone ever shown one in a year.

| Tried | Null | + wander | + drift | Grid, worst | ≥15 by night 56 | Differ, a year |
|---|---|---|---|---|---|---|
| v1 | 3.0 | 12.7 | 13.4 | 95.8 (l90-r0.2) | 50.0 | 43.6 |
| *The intercept wanders (a Kalman step), sd a week* | | | | | | |
| 5 min (`w5-k0`) | 1.8 | 4.5 | 3.5 | 87.5 (l90-r0.2) | 44.1 | 38.3 |
| 10 min (`w10-k0`) | 0.7 | 1.9 | 2.6 | 72.0 (l90-r0.2) | 36.2 | 30.6 |
| *A noise scale from week sums; zero tests a t's* | | | | | | |
| 98% zero test (`w0-k5-z98`) | 0.3 | 0.5 | 0.3 | 2.0 | 23.2 | 22.1 |
| 96% (`w0-k5-z96`) | 1.7 | 2.4 | 1.6 | 5.0 | 34.9 | 29.8 |
| 95% (`w0-k5-z95`) | 2.5 | 3.2 | 2.4 | 5.9 | 38.6 | 32.2 |
| 94% (`w0-k5-z94`) | 3.9 | 3.9 | 3.2 | 7.5 | 42.2 | 34.5 |
| 95%, and the intercept wanders 3 min (`w3-k5-z95`) | 2.2 | 2.8 | 2.2 | 5.4 | 37.6 | 32.0 |
| 95%, shown range under 25 min (`w0-k5-z95-x25`) | 2.4 | 3.0 | 2.3 | 4.7 | 33.8 | 31.0 |
| *Waiting for more usable nights before any insight* | | | | | | |
| 95%, 21 nights (`w0-k5-z95-m21`) | 2.4 | 2.6 | 2.3 | 4.9 | 38.4 | 32.1 |
| 95%, 28 nights (`w0-k5-z95-m28`) | 2.1 | 2.7 | 2.1 | 3.6 | 36.8 | 31.6 |
| 94%, 28 nights (`w0-k5-z94-m28`) | 2.7 | 3.1 | 2.5 | 4.4 | 39.2 | 34.1 |
| 94%, 28 nights, scale from 7 nights (`w0-k7-z94-m28`) | 2.7 | 3.0 | 2.6 | 4.8 | 38.6 | 34.2 |
| 94%, 35 nights (`w0-k5-z94-m35`) | 1.3 | 2.0 | 1.3 | 2.8 | 32.7 | 32.7 |
| **94.5%, 28 nights (v2)** | **2.3** | **2.8** | **2.3** | **3.9** | **38.4** | **32.6** |

The noise scale runs from 5 nights of κ = 1 throughout: in an earlier sweep on two hand-made profiles (not kept), 5 nights adapted sooner than 7 or 14 at no cost to learning.

### What we learned

- **A wandering intercept is the textbook fix, and a costly one.** A held week's contrast is exactly what a moving usual time explains away, so the wander costs learning in everyone, including people whose time holds still: 10 minutes a week takes the D66 mark from 50% to 36% and still lets 72% of the grid's worst profile through. No one size fits.
- **The fix has to be per person, and the residuals show who needs it.** If the model is right, each night's residual divided by its predicted sd is independent with variance 1, so a week's sum of them, squared, averages the week's count of nights. When a person's nights are noisier, or their usual time moves for days or weeks, a week's residuals share a sign and the sums grow; with a slow wander, so do the products of one week's sum and the next's. Their ratio to the nights (a long-run variance with one week's lag, as Newey and West weigh it) is the person's noise scale κ². Every range is drawn from κ²Σ, so a week that moves together counts as fewer nights, and a person whose time holds still keeps about v1's ranges.
- **The scale rests on weeks, not nights.** Each week's sum is one look at κ², so in the first weeks it is a guess. The zero tests are a Student t's, with the scale's weeks (its prior included) as degrees of freedom. The 90% range shown stays a normal's, so it stays a 90% range when the scale is right: every scenario's range holds the truth for 90–92% at night 56 (`criteria.json`), inside the 85–95% band. Holding κ² at 1 or more, tried in the earlier sweep, made calm people's ranges too wide (null coverage above 95%) and cost learning for little gain.
- **What was left came early.** With the scale and the t, most false insights on the mild profiles came before week 8, while the scale rests on a few weeks. Waiting for 28 usable nights (about five weeks) before any insight holds them for less learning than a stricter test: 94.5% and 28 nights has a lower grid worst case than a 96% test from 14 nights (3.9% against 5.0%) and learns 3.5 points more.
- **Chosen (v2): no intercept wander, κ² from 5 nights of 1, a 94.5% zero test that tightens after 30 usable nights as before, and no insight before 28 usable nights.** The intercept's wander stays in the artifact (`intercept_week_sd`) and both models, at 0.

### What it costs

From `longrun-wander.json`, 2,000 people, "differ" unless named:

| | v1 | v2 |
|---|---|---|
| Effect of 15 min or more: insight by night 56 (D66 mark) | 49.7% | 38.8% |
| The same, within a year | 76.7% | 66.4% |
| Ever shown an insight within a year | 42.7% | 32.5% |
| Shown with the wrong sign within a year | 0.2% | 0.2% |
| Sleep benefit over the year, min a night | −8.4 | −8.1 |
| Start changes a week | 0.28 | 0.31 |
| Across the grid: D66 mark | 32.5–58.9% | 0.7–35.2% |
| Across the grid: wrong sign within a year | 1.1–49.3% | 0.1–0.8% |

- **The D66 learning mark is now 40%,** the founders' call for v2 (half before, D66): ranges that stay honest when the usual time moves learn less. v2 measures 41.7% in the pass criteria's own run (v1 52.6%), and 38.4–43.1% over the six other runs here (mean of four seeds 41.9%), so the 40% line sits inside its spread. The pass criteria enforce it again.
- **Where the usual time moves, many of v1's insights were noise.** Across the grid v1 showed an insight to 52–96% of "differ" people within a year, and up to half saw one with the wrong sign (l90-r0.2: 49%). v2 shows one to 1–28%, which is about what that much movement allows, and the wrong way to under 1%. A person whose time swings like that gets no insight, and is told nothing false.
- **The start moves more for people whose time moves.** Fewer of them settle (none to 46% of null people across the grid at the end of the year, against 61–70% under v1), so their start keeps exploring: 0.41–0.50 changes a week, against D66's 0.5. Calm people are unchanged (0.33).
- **No insight before 28 usable nights** means nobody sees one by night 28 (v1: 16%). That mark was already waived (D53, D66).
- **The sleep benefit barely moves:** −8.1 against −8.4 min a night in "differ", and −5.0 against −5.4 over 8 weeks in the pass criteria. It doesn't depend on the insight.

### What it doesn't settle

- The grid brackets, it isn't a population. How many people move like each corner is for the pilot's night records (D92's records carry Health's sleep since D97); a new profile is one line in `sim/profiles.py`.
- The scale is one number for the whole posterior. A person whose usual time drifts but whose start effect is clean is treated as noisier than they are. The intercept's wander is the targeted tool if the pilot shows most of the movement is slow drift.

