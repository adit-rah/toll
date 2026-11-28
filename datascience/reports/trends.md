# Your sleep's trend lines

#165 asks whether Your sleep's change lines ("25 min earlier than your first 7 nights", D104) meet D99's standard: at most 5% of people ever shown a change that isn't there, here over 12 and 26 weeks, under the noise real nights have. D104's rule (means, Welch's errors, z 2.2, judged every night) said a false change on about 4% of days, as designed, but because it looked every day, about half of the people with no change at all saw one at some point within 12 weeks, and the line came and went. The rule below replaces it. The phone's `SleepTrends` gives the same answer as `trends/rule.py` on every fixture (`trends/fixtures.py`, `TrendParityTests`).

```
uv run python -m trends.study final --people 3000 --out reports/trends-final.json
uv run python -m trends.study sweep --people 1000 --scenarios still,shuffled,shift-30-early,shift-60-early,shift-60-week6 --out reports/trends-sweep.json
for s in 101 202 303; do uv run python -m trends.study sweep --people 4000 --seed $s --only winsor-m0.02-p2.0 --scenarios still,shuffled --out reports/trends-seeds-$s.json; done
```

## The rule

- **Judged once a week.** The line is judged on the week that ended before the latest Monday noon (Monday to Sunday by night, D99 and D100's week) and held until the next Monday noon. The value and the chart still move every night; only the line waits. Before the first Monday after the first nights, there is no line.
- **Robust.** Values and comparisons are 20% trimmed means: of a week's seven nights, the highest and the lowest are set aside. The error comes from the person's own night-to-night noise, each night against its own week's mean, winsorized at the same 20% and pooled over every week judged so far (Tukey and McLaughlin's error for a trimmed mean). One wild night can't make a change or hide one, and a calm or a wild week doesn't swing the error.
- **Spent over the looks.** The k-th weekly look needs the change to clear 0.02 / k² as its miss chance, on Student's t with the pooled nights' degrees of freedom (Yuen's), and the floor (15 min, 0.5 reaches, 10 min for How steady). Over every look for as long as Dusk is used, the nominal chances add to 0.02 · π²/6 ≈ 3.3%; with heavy tails, missing nights and short weeks the study finds up to about 4% by 26 weeks, and the growing test keeps later looks adding little.
- **Kept once said.** A change said the week before, the same way, is kept while it clears the floor and the first look's test. Being told again what was already said can't add a first false claim, and it keeps a real change from fading as the test grows.
- **How steady** is the same on each night's distance from its window's middle night, the first 14 nights against the 14 ending with the judged week (at least 10). Nights locked compares the judged week with the first seven on its floor alone, as before.
- Unchanged from D104: the first 7 nights (14 for How steady), at least 5 of the judged week's nights after them, the floors, the copy and the charts.

## Noise

`trends/noise.py` draws a person's nights as a weekly level that wanders (an AR(1) from week to week) plus each night's noise (a contaminated normal: most nights `core` minutes either side, a share of them much further), with nights missing. It also measures the aggregates a Health export is described by (spread within a week, the share of nights far from their week's median, the median change from night to night, the spread and memory of the weekly median) and fits a profile to them (`calibrate`).

The public study runs seven profiles (`noise.GRID`), invented to bracket how people's nights and usual time move, with the same grid idea as the sleep model's simulator (`sim/profiles.py`): the simulator's nights (30 min, E-006, with its 15-minute wander and that wander's weekly memory), Gaussian nights of 20 or 45 minutes, and heavy tails (15% or 40% of nights with sd 150 or 240), across a weekly level of sd 20, 45 or 90 minutes with a memory of 0.2, 0.6 or 0.95. A name says it: `t40-240-l45-r0.6` is 40% of nights with sd 240, a level of sd 45, memory 0.6; `g45` is Gaussian nights of 45 minutes. None is a person's export. **Checked against a real Health export (n=1, private):** the generator was fitted to that export's aggregates for two kinds of Health source, D104's rule on the fitted nights gave what a replay of the export gave, and the rule below holds the 5% mark on those profiles too. The export's numbers stay off this repo.

## What "false" means

Each profile runs as:
- **still:** its nights' noise, and the level never moves. This is the 5% mark: no change in level.
- **shuffled:** its nights with their wander, in a random order. The level's moves become night noise and nothing changes over time; this is what a replay of a shuffled export tests. Also held to 5%.
- **wander:** the level moves as the profile says. A change against the first nights is then a true description of a level that moved, not a false one. The study counts the claims made the wrong way, or about a level that moved less than half the floor.

**Why the baseline stays the first nights.** The line says "than your first 7 nights", and the founder chose facts against the person's own start (D104). Comparing with a recent baseline instead would turn the line into "than the weeks before", which is a different sentence and would need different words. With the first nights kept, the honest null is "the level is where it started": when the level has wandered, saying so is true. The error is the noise within weeks, because a moved level is the person's level, not noise. What wander does cost is lines that come and go as the level does, which judging weekly and keeping a said change hold down (below).

## Results (`trends-final.json`, 3,000 people a cell)

People ever shown a change with no change in level, % (the mark is 5):

| Profile | Asleep by / Time asleep: still, 12 wk / 26 wk | shuffled, 26 wk | How steady: still / shuffled, 26 wk | D104's rule, still, 12 wk (level / How steady) |
|---|---|---|---|---|
| g20-l45-r0.95 | 3.0 / 3.2 | 3.9 | 1.5 / 2.4 | 50.7 / 16.4 |
| g45-l20-r0.2 | 3.4 / 3.5 | 3.8 | 1.5 / 1.7 | 54.3 / 26.9 |
| g45-l90-r0.6 | 3.5 / 3.6 | 3.8 | 1.7 / 2.5 | 54.6 / 25.5 |
| t15-150-l90-r0.2 | 2.8 / 3.3 | 3.5 | 1.2 / 1.9 | 40.8 / 18.3 |
| t40-150-l20-r0.95 | 1.6 / 2.3 | 2.2 | 1.2 / 1.4 | 41.1 / 27.4 |
| t40-240-l45-r0.6 | 1.8 / 2.5 | 2.9 | 1.5 / 1.5 | 38.5 / 27.9 |
| sim | 3.2 / 3.4 | 3.9 | 2.0 / 1.7 | 50.9 / 24.3 |

Three more runs of the nulls with 4,000 people each (`trends-seeds-*.json`) give 2.1–4.4% for the level and 1.1–2.4% for How steady in every cell. The 1,000-person sweep's worst cell for this rule, 5.6% (sim, shuffled), is within its sampling error (about ±1.4 points) of those; the same cell is 3.9% with 3,000 people above.

People told of a real change the right way, %:

| Profile | 30 min from week 2: by wk 4 / 12 | 60 min from week 2: by wk 4 / 12 | 30 min from week 6: by wk 12 | 60 min from week 6: by wk 12 | differ: right / wrong way, 12 wk | Half the noise from week 3: How steady by wk 12 |
|---|---|---|---|---|---|---|
| g20-l45-r0.95 | 58.1 / 65.9 | 98.5 / 99.7 | 39.4 | 97.9 | 16.6 / 1.2 | 10.6 |
| g45-l20-r0.2 | 12.9 / 14.9 | 43.3 / 51.8 | 4.7 | 28.4 | 4.5 / 1.4 | 12.0 |
| g45-l90-r0.6 | 12.5 / 14.6 | 42.2 / 49.7 | 4.8 | 30.4 | 5.1 / 1.8 | 12.4 |
| t15-150-l90-r0.2 | 17.5 / 19.7 | 57.2 / 64.8 | 6.0 | 40.3 | 4.4 / 1.1 | 8.1 |
| t40-150-l20-r0.95 | 8.9 / 10.1 | 32.6 / 36.2 | 2.3 | 11.7 | 2.6 / 0.4 | 1.8 |
| t40-240-l45-r0.6 | 3.4 / 4.2 | 14.5 / 16.9 | 1.2 | 4.2 | 2.0 / 0.7 | 1.5 |
| sim | 29.5 / 34.3 | 83.5 / 90.1 | 11.8 | 72.4 | 7.5 / 1.8 | 16.2 |

"differ" is the simulator's effect of a 30-minute earlier lock (N(8, 15) minutes) from week 3: mostly smaller than the floor, so rarely said. A change that starts late is caught less often than one that starts early, because by then the test has grown; a change caught early is kept.

When the level wanders (not a null):

| Profile | Told of a change by wk 12 | the wrong way | about a move under half the floor | Lines changing per person in 12 wk: weekly / D104's nightly |
|---|---|---|---|---|
| g20-l45-r0.95 | 61.9 | 0.4 | 2.7 | 0.99 / 4.94 |
| g45-l20-r0.2 | 14.3 | 0.8 | 1.0 | 0.26 / 4.56 |
| g45-l90-r0.6 | 87.1 | 0.1 | 0.2 | 1.97 / 5.27 |
| t15-150-l90-r0.2 | 84.0 | 0.2 | 0.2 | 2.27 / 6.31 |
| t40-150-l20-r0.95 | 2.1 | 0.3 | 0.7 | 0.03 / 2.01 |
| t40-240-l45-r0.6 | 12.8 | 0.5 | 0.1 | 0.22 / 3.22 |
| sim | 12.9 | 0.8 | 1.5 | 0.22 / 4.49 |

A level of sd 90 that moves week to week is a level that really moves, so its lines change about twice in 12 weeks even when judged weekly.

## Choosing the numbers (`trends-sweep.json`, 1,000 people a cell)

The worst null over the seven profiles at 26 weeks, and power at 12 weeks, %:

| Rule | Level, worst null | How steady, worst null | sim: 30 min from week 2 | sim: 60 min from week 6 | t15-150-l90-r0.2: 60 min from week 2 |
|---|---|---|---|---|---|
| **winsor, 0.02, k^−2 (chosen)** | 5.6 | 2.5 | 33 | 71 | 63 |
| winsor, 0.02, k^−1.5 | 6.8 | 2.8 | 40 | 83 | 69 |
| winsor, 0.03, k^−2 | 7.0 | 3.4 | 39 | 76 | 69 |
| winsor, 0.04, k^−2 | 8.8 | 4.4 | 45 | 79 | 73 |
| winsor, 0.02, k^−1 | 8.8 | 4.0 | 50 | 92 | 76 |
| winsor, 0.04, k^−1.5 | 10.5 | 5.0 | 52 | 89 | 78 |
| winsor, 0.06, k^−1 | 19.2 | 10.5 | 70 | 97 | 88 |
| MAD-based error, 0.02, k^−2 | 36.4 | 27.6 | 44 | 87 | 81 |
| first 14 nights, 0.04, k^−1.5 | 12.1 | 5.0 | 22 | 99 | 26 |

- **A MAD-based error lets heavy-tailed nights through.** A MAD sees only the middle of the nights; a trimmed mean's error also depends on its shoulders, which a MAD misses when many of the nights are far out (36% false with 40% of nights in the tail). The winsorized error tracks both.
- **Student's t, not the normal.** The first look has two weeks of noise to go on, so its error is itself uncertain; with the normal's quantile most false claims came at the first look (an early sweep). Yuen's degrees of freedom fix it and cost little later, when the pooled weeks are many.
- **The first 14 nights** would see a change that starts in week 2 half as often, and at 26 weeks hold no better.
- Only the chosen rule keeps every null near 5% at 26 weeks (5.6% in this 1,000-person sweep, 3.9% with 3,000 and at most 4.4% over three 4,000-person seeds), and its spending bounds every look after that too.

## Doubts

- **Power is low for noisy nights.** With heavy-tailed nights, a real 30-minute shift is said for 4–20% of people within 12 weeks. That's the price of not telling a twentieth of everyone something false; "About the same" is the honest line for them.
- **How steady after a change in level.** A real shift inside the first 14 nights makes those nights look less steady, so How steady later says "steadier" (for 42% of people with 20-minute nights after a 60-minute shift at night 8). It's a true description of those 14 nights, not of a change in how steady the person is. Measuring each night's distance from its own week's middle would remove it; that changes the measure, so it's left for a decision.
- **A change in the noise alone** (half the noise from week 3, level still) lets the level's line through for 3.0–5.8% at 26 weeks: the first week's error is larger than the pooled noise says. Not a null of this study.
- **Health's correction after Monday noon.** The judgement is worked out from the nights each time, not stored. Health's sleep for Sunday night can arrive after Monday noon (D97's `rev` correction), and the week's line can then change once.
- **The stand-ins** (Phone down by, D104) use the same rule; how the last reach relates to Health's sleep onset is still unmeasured (#165's third point), since it needs real nights with both.
