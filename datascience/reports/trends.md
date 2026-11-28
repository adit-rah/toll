# Your sleep's trend lines

#165 asks whether Your sleep's change lines ("25 min earlier than your first 7 nights", D104) meet D99's standard: at most 5% of people ever shown a change that isn't there, here over 12 and 26 weeks, under the noise real nights have. D104's rule (means, Welch's errors, z 2.2, judged every night) said a false change on about 4% of days, as designed, but because it looked every day, about half of the people with no change at all saw one at some point within 12 weeks, and the line came and went. The rule below replaces it (D108), with two amendments from #173 (How steady reads each night against the days around it; a first week noisier than every week since keeps its own error). The phone's `SleepTrends` gives the same answer as `trends/rule.py` on every fixture (`trends/fixtures.py`, `TrendParityTests`).

```
uv run python -m trends.study final --people 3000 --out reports/trends-final.json
uv run python -m trends.study sweep --people 1000 --scenarios still,shuffled,shift-30-early,shift-60-early,shift-60-week6 --out reports/trends-sweep.json
for s in 101 202 303; do uv run python -m trends.study sweep --people 4000 --seed $s --only winsor-m0.02-p2.0 --scenarios still,shuffled,steadier --out reports/trends-seeds-$s.json; done
uv run python -m trends.study sweep --people 3000 --only d108,steady-window,steady-halves,first-pooled,first-ratio2,first-own,winsor-m0.02-p2.0 --scenarios still,shuffled,wander,steadier,shift-30-early,shift-60-early,shift-60-monday,shift-60-week6,differ --out reports/trends-173.json
uv run python -m trends.late --people 2000 --out reports/trends-late.json
```

## The rule

- **Judged once a week.** The line is judged on the week that ended before the latest Monday noon (Monday to Sunday by night, D99 and D100's week) and held until the next Monday noon. The value and the chart still move every night; only the line waits. Before the first Monday after the first nights, there is no line.
- **Robust.** Values and comparisons are 20% trimmed means: of a week's seven nights, the highest and the lowest are set aside. The error comes from the person's own night-to-night noise, each night against its own week's mean, winsorized at the same 20% and pooled over every week judged so far (Tukey and McLaughlin's error for a trimmed mean). One wild night can't make a change or hide one, and a calm or a wild week doesn't swing the error.
- **A first week noisier than every week since** (#173). When the first nights' own winsorized spread is more than 1.5 times the pooled spread of the weeks since, each side takes its own: the first nights' spread for their mean, the weeks' since for the judged week's, with Welch's degrees of freedom (Yuen's test). Pooled, a person who calmed down would have the first nights' level taken as surer than it is.
- **Spent over the looks.** The k-th weekly look needs the change to clear 0.02 / k² as its miss chance, on Student's t with the pooled nights' degrees of freedom (Yuen's), and the floor (15 min, 0.5 reaches, 10 min for How steady). Over every look for as long as Dusk is used, the nominal chances add to 0.02 · π²/6 ≈ 3.3%; with heavy tails, missing nights and short weeks the study finds up to about 4% by 26 weeks, and the growing test keeps later looks adding little.
- **Kept once said.** A change said the week before, the same way, is kept while it clears the floor and the first look's test. Being told again what was already said can't add a first false claim, and it keeps a real change from fading as the test grows.
- **How steady** is the same on each night's distance from the middle (median) of the nights within three days of it, in the same window (#173): the first 14 nights against the 14 ending with the judged week (at least 10). A usual time that moves, between weeks or once inside the first nights, is then the level's change, said by Asleep by, and not read as unsteady nights. Nights locked compares the judged week with the first seven on its floor alone, as before.
- Unchanged from D104: the first 7 nights (14 for How steady), at least 5 of the judged week's nights after them, the floors, the copy and the charts.

## Noise

`trends/noise.py` draws a person's nights as a weekly level that wanders (an AR(1) from week to week) plus each night's noise (a contaminated normal: most nights `core` minutes either side, a share of them much further), with nights missing. It also measures the aggregates a Health export is described by (spread within a week, the share of nights far from their week's median, the median change from night to night, the spread and memory of the weekly median) and fits a profile to them (`calibrate`).

The public study runs seven profiles (`noise.GRID`), invented to bracket how people's nights and usual time move, with the same grid idea as the sleep model's simulator (`sim/profiles.py`): the simulator's nights (30 min, E-006, with its 15-minute wander and that wander's weekly memory), Gaussian nights of 20 or 45 minutes, and heavy tails (15% or 40% of nights with sd 150 or 240), across a weekly level of sd 20, 45 or 90 minutes with a memory of 0.2, 0.6 or 0.97. A name says it: `t40-240-l45-r0.6` is 40% of nights with sd 240, a level of sd 45, memory 0.6; `g45` is Gaussian nights of 45 minutes. None is a person's export. **Checked against a real Health export (n=1, private):** the generator was fitted to that export's aggregates for two kinds of Health source, D104's rule on the fitted nights gave what a replay of the export gave, and D108's rule held the 5% mark on those profiles too. #173's amendments were measured on the public profiles only. The export's numbers stay off this repo.

## What "false" means

Each profile runs as:
- **still:** its nights' noise, and the level never moves. This is the 5% mark: no change in level.
- **shuffled:** its nights with their wander, in a random order. The level's moves become night noise and nothing changes over time; this is what a replay of a shuffled export tests. Also held to 5%.
- **wander:** the level moves as the profile says. A change against the first nights is then a true description of a level that moved, not a false one. The study counts the claims made the wrong way, or about a level that moved less than half the floor. For How steady, the night noise doesn't change, so since #173 a How steady line under wander is counted as false too.
- **steadier:** half the night's noise from week 3, the level still. For Asleep by it is a null (no change in level); for How steady it is a real change.
- **shift:** a real step of 30 or 60 minutes earlier: from night 8, from week 6, or on the first Monday at least a week in (the day the lock moves, D97 and D107). For How steady these are nulls (the noise doesn't change).

**Why the baseline stays the first nights.** The line says "than your first 7 nights", and the founder chose facts against the person's own start (D104). Comparing with a recent baseline instead would turn the line into "than the weeks before", which is a different sentence and would need different words. With the first nights kept, the honest null is "the level is where it started": when the level has wandered, saying so is true. The error is the noise within weeks, because a moved level is the person's level, not noise. What wander does cost is lines that come and go as the level does, which judging weekly and keeping a said change hold down (below).

## Results (`trends-final.json`, 3,000 people a cell)

People ever shown a change that isn't there, % (the mark is 5):

| Profile | Asleep by / Time asleep: still, 12 wk / 26 wk | shuffled, 26 wk | How steady: still / shuffled, 26 wk | Asleep by, half the noise from week 3, 26 wk | D104's rule, still, 12 wk (level / How steady) |
|---|---|---|---|---|---|
| g20-l45-r0.97 | 2.8 / 2.9 | 3.7 | 2.4 / 3.1 | 3.9 | 50.7 / 16.4 |
| g45-l20-r0.2 | 3.2 / 3.3 | 3.5 | 2.4 / 2.5 | 4.0 | 54.3 / 26.9 |
| g45-l90-r0.6 | 3.2 / 3.3 | 3.6 | 2.5 / 3.7 | 3.6 | 54.6 / 25.5 |
| t15-150-l90-r0.2 | 2.5 / 2.7 | 3.2 | 2.1 / 2.9 | 3.3 | 40.8 / 18.3 |
| t40-150-l20-r0.97 | 1.4 / 1.8 | 1.7 | 2.6 / 2.4 | 1.5 | 41.1 / 27.4 |
| t40-240-l45-r0.6 | 1.6 / 2.0 | 2.3 | 2.8 / 3.0 | 1.2 | 38.5 / 27.9 |
| sim | 3.1 / 3.2 | 3.4 | 3.0 / 3.4 | 3.8 | 50.9 / 24.3 |

Three more runs with 4,000 people each (`trends-seeds-*.json`) give 1.4–4.1% for the level, 2.2–3.7% for How steady and 1.4–4.2% for the level with half the noise from week 3, in every cell. In the 1,000-person sweep the worst cells are 5.0% (level) and 4.0% (How steady), within its sampling error (about ±1.4 points).

People told of a real change the right way, %:

| Profile | 30 min from week 2: by wk 4 / 12 | 60 min from week 2: by wk 4 / 12 | 30 min from week 6: by wk 12 | 60 min from week 6: by wk 12 | differ: right / wrong way, 12 wk | Half the noise from week 3: How steady by wk 12 |
|---|---|---|---|---|---|---|
| g20-l45-r0.97 | 53.7 / 60.5 | 96.3 / 97.2 | 35.7 | 94.0 | 15.0 / 1.2 | 8.9 |
| g45-l20-r0.2 | 12.2 / 13.8 | 40.2 / 47.7 | 4.2 | 25.2 | 4.0 / 1.3 | 9.3 |
| g45-l90-r0.6 | 11.3 / 13.4 | 39.3 / 45.3 | 4.1 | 27.0 | 4.7 / 1.8 | 10.9 |
| t15-150-l90-r0.2 | 16.3 / 18.0 | 52.1 / 58.1 | 5.1 | 35.8 | 3.7 / 1.0 | 7.2 |
| t40-150-l20-r0.97 | 7.9 / 8.8 | 29.2 / 31.9 | 1.5 | 8.8 | 1.8 / 0.4 | 2.7 |
| t40-240-l45-r0.6 | 3.1 / 3.5 | 12.7 / 14.5 | 0.7 | 2.5 | 1.6 / 0.5 | 2.8 |
| sim | 27.0 / 31.6 | 79.5 / 85.5 | 10.8 | 68.2 | 6.9 / 1.7 | 11.5 |

"differ" is the simulator's effect of a 30-minute earlier lock (N(8, 15) minutes) from week 3: mostly smaller than the floor, so rarely said. A change that starts late is caught less often than one that starts early, because by then the test has grown; a change caught early is kept.

When the level wanders (not a null for the level):

| Profile | Told of a change by wk 12 | the wrong way | about a move under half the floor | Lines changing per person in 12 wk: weekly / D104's nightly | How steady, any line by wk 26 |
|---|---|---|---|---|---|
| g20-l45-r0.97 | 43.2 | 0.5 | 2.5 | 0.67 / 5.02 | 2.4 |
| g45-l20-r0.2 | 12.9 | 0.8 | 1.0 | 0.23 / 4.56 | 3.0 |
| g45-l90-r0.6 | 84.3 | 0.1 | 0.2 | 1.86 / 5.27 | 3.5 |
| t15-150-l90-r0.2 | 81.2 | 0.1 | 0.2 | 2.16 / 6.31 | 2.5 |
| t40-150-l20-r0.97 | 1.3 | 0.3 | 0.5 | 0.02 / 1.86 | 2.5 |
| t40-240-l45-r0.6 | 10.6 | 0.3 | 0.1 | 0.19 / 3.22 | 2.9 |
| sim | 12.0 | 0.8 | 1.4 | 0.20 / 4.49 | 3.1 |

A level of sd 90 that moves week to week is a level that really moves, so its lines change about twice in 12 weeks even when judged weekly.

## #173: the three things D108 left (`trends-173.json`, 3,000 people a cell; `trends-late.json`, 2,000)

### How steady after a shift in level

D108's How steady read each night's distance from the middle of its whole 14-night window. A shift in level inside the first 14 nights then made those nights look unsteady, and How steady later said "steadier"; a usual time that moved from week to week read as unsteady nights. Neither is a change in how steady the person is.

People ever shown a How steady line, by 26 weeks, %, with no change in the night's noise:

| Profile | 60 min at night 8: D108 / now | 60 min on the first Monday a week in: D108 / now | 60 min from week 6: D108 / now | wander: D108 / now |
|---|---|---|---|---|
| g20-l45-r0.97 | 42.0 / 2.6 | 17.0 / 2.7 | 7.3 / 2.9 | 1.7 / 2.4 |
| g45-l20-r0.2 | 3.1 / 2.9 | 3.0 / 2.9 | 2.0 / 2.8 | 1.9 / 3.0 |
| g45-l90-r0.6 | 3.2 / 2.6 | 2.5 / 3.0 | 1.9 / 3.5 | 16.8 / 3.5 |
| t15-150-l90-r0.2 | 4.9 / 2.0 | 3.8 / 1.7 | 1.7 / 2.4 | 43.2 / 2.5 |
| t40-150-l20-r0.97 | 4.4 / 2.9 | 2.7 / 2.9 | 2.1 / 2.5 | 1.1 / 2.5 |
| t40-240-l45-r0.6 | 1.8 / 2.9 | 1.5 / 2.8 | 1.6 / 2.9 | 1.8 / 2.9 |
| sim | 9.1 / 3.0 | 5.2 / 3.1 | 2.5 / 3.3 | 2.1 / 3.1 |

- **Measured against the days around each night** (chosen): every one of these is at the null's level, 1.7–3.5%. The costs: the still and shuffled nulls rise from 1.2–2.5% to 2.1–3.7% (neighbouring nights share a middle, so their distances aren't quite independent), power for a real halving of the noise falls from 8.0–13.8% to 6.0–11.9% by 12 weeks (heavy-tailed nights stay at 1–3%), and the value reads about a tenth smaller for a person whose time doesn't move (± 18 against ± 20 for 30-minute nights), since a middle of seven nights sits nearer each of them.
- **Measured against each week's middle** (the window's two halves, `steady-halves`): also removes the shift (0.6–2.4% at nights 4, 8 and 11 and on the Monday) with lower nulls (0.6–1.9%), but finds a real halving of the noise less often (1.3–7.7%), and its halves don't sit on calendar weeks for the first nights.
- **Kept as D108** (`steady-window`): a true description of those 14 nights, not of the person; 42% of people with 20-minute nights told "steadier" after a 60-minute shift, and up to 43% told of a change under a level of sd 90.

**Decided:** change the measure to the days around each night. How steady is meant to say how far a night strays from the person's usual time, and the level's move is Asleep by's to say; counting it twice, as a flattering "steadier", is the kind of line D108 was written to stop. The words ("Around your usual time, last 14 nights") stay true: the usual time is now the one around each night.

### A change in the noise alone

With half the noise from week 3 and the level still, D108's pooled error let the level's line through for 3.3–6.1% by 26 weeks (worst: g45, 6.1%), over D99's 5%. The pooled noise is mostly the calm weeks, so it takes the first week's noisy level as surer than it is. Asleep by, by 26 weeks, %:

| Rule | Half the noise from week 3 (null) | Still, worst | sim: 30 min from week 2, by wk 12 | sim: 60 min from week 6, by wk 12 | g45-l20-r0.2: 60 min from week 2, by wk 12 | t40-150-l20-r0.97: 60 min from week 6, by wk 12 |
|---|---|---|---|---|---|---|
| D108, pooled | 3.3–6.1 | 3.6 | 33.1 | 71.4 | 50.1 | 11.2 |
| **own noise past 1.5× (chosen)** | 1.4–4.6 | 3.3 | 30.1 | 67.3 | 45.3 | 8.6 |
| own noise past 2× | 1.6–5.4 | 3.4 | 31.9 | 70.9 | 48.3 | 10.1 |
| always each side's own (Yuen's test) | 1.2–3.4 | 2.9 | 26.4 | 52.1 | 39.8 | 13.5 |

**Decided:** the guard at 1.5×. It brings the noise-change null under 5% in every cell and seed (1.4–4.6%; 1.4–4.2% over three 4,000-person seeds) for 3–5 points of power on Gaussian nights (up to a tenth of it) and up to 2.6 points on heavy-tailed ones. Always using each side's own noise costs over a quarter of the power for late shifts; at 2× the null still reaches 5.4%. A person who calms down is what Dusk is for, so this case will happen.

### Health's late nights after Monday noon

The line is worked out from the night log each time it is read (D108: nothing is stored). Health's sleep reaches the log as a correction when the app opens after the watch has synced (D92's `rev`). If someone reads Your sleep after Monday noon and before Sunday night's sleep is in, the line they see can change once it arrives. Of judged Mondays where either reading shows a line, % (`trends-late.json`, 12 weeks):

| Nights not in at noon | Profile kind | A line appears later (the week had 4 nights) | "About the same" ↔ a change | The same way, other minutes |
|---|---|---|---|---|
| Sunday's | no change (still), every profile | 1.5–11.3 | 0.1–0.3 | 0.1–0.2 |
| Sunday's | a real 30-minute shift | 1.4–10.9 | 0.3–5.9 | 0.3–14.3 |
| Sunday's | wander | 1.2–11.1 | 0.2–4.4 | 0.1–29.0 |
| Friday to Sunday's | every profile and kind | 100 for the level (no line until they arrive) | 0 | 0 |
| Sunday's, How steady | every profile and kind | 1.5–4.5 | 0.2–0.4 | (no minutes) |

- A way changes only when a real change sits at the edge of the test (up to 5.9%, g20, the 30-minute shift); with no change it's 0.1–0.3%.
- Most changes are a line appearing where there was none, or the minutes moving by five as the week gets its last night. Either way it's toward the line every later reading shows.
- **Freezing at Monday noon** would need what the log doesn't keep: when each correction was written, or the judgement itself (a new field or state, D92's migrations). It would then show, for the whole week, a line that leaves out a night Dusk already has, and a week whose fifth night arrived late would show no line until the next Monday.

**Decided:** accept it. The line can change once after Monday noon, only when Health's sleep arrives late and the person has read Your sleep in between, and the change is to the fuller week's answer. How often Health's sleep reaches the log after Monday noon isn't known; it needs real nights (#183, #159).

## Choosing the numbers (`trends-sweep.json`, 1,000 people a cell)

Every row carries #173's two amendments unless it says otherwise. The worst null over the seven profiles at 26 weeks, and power at 12 weeks, %:

| Rule | Level, worst null | How steady, worst null | sim: 30 min from week 2 | sim: 60 min from week 6 | t15-150-l90-r0.2: 60 min from week 2 |
|---|---|---|---|---|---|
| **winsor, 0.02, k^−2 (chosen)** | 5.0 | 4.0 | 31 | 67 | 58 |
| D108 (window middle, pooled error) | 5.6 | 2.2 | 33 | 71 | 63 |
| winsor, 0.02, k^−1.5 | 6.2 | 5.3 | 37 | 79 | 63 |
| winsor, 0.03, k^−2 | 6.6 | 5.8 | 37 | 72 | 63 |
| winsor, 0.04, k^−2 | 8.3 | 6.7 | 43 | 75 | 68 |
| winsor, 0.02, k^−1 | 8.0 | 7.6 | 46 | 88 | 69 |
| winsor, 0.04, k^−1.5 | 9.8 | 8.5 | 49 | 85 | 73 |
| winsor, 0.06, k^−1 | 18.2 | 15.8 | 67 | 94 | 83 |
| MAD-based error, 0.02, k^−2 | 23.3 | 32.9 | 37 | 74 | 67 |
| first 14 nights, 0.04, k^−1.5 | 13.3 | 8.5 | 24 | 99 | 32 |

- **A MAD-based error lets heavy-tailed nights through.** A MAD sees only the middle of the nights; a trimmed mean's error also depends on its shoulders, which a MAD misses when many of the nights are far out. The winsorized error tracks both.
- **Student's t, not the normal.** The first look has two weeks of noise to go on, so its error is itself uncertain; with the normal's quantile most false claims came at the first look (an early sweep). Yuen's degrees of freedom fix it and cost little later, when the pooled weeks are many.
- **The first 14 nights** would see a change that starts in week 2 less often, and at 26 weeks hold no better.
- Only the chosen spending keeps every null near 5% at 26 weeks (5.0% in this 1,000-person sweep, at most 4.1% over three 4,000-person seeds), and its spending bounds every look after that too.

## Doubts

- **Power is low for noisy nights.** With heavy-tailed nights, a real 30-minute shift is said for 4–18% of people within 12 weeks. That's the price of not telling a twentieth of everyone something false; "About the same" is the honest line for them.
- **How steady's middle is the days around each night,** so its value is no longer the spread of the 14 nights: a usual time that moves from week to week no longer widens it, and the value reads about a tenth smaller than D108's for a person whose time doesn't move. The first and the judged nights are measured the same way, so the line compares like with like.
- **The noise guard is a switch.** A first week just under 1.5 times as noisy as the weeks since is still pooled. In the study that leaves at most 4.6% at 26 weeks; a smaller change in noise does less.
- **Health's late nights** can change a week's line once after Monday noon (above); how often they arrive late needs real nights.
- **The stand-ins** (Phone down by, D104) use the same rule; how the last reach relates to Health's sleep onset is still unmeasured (#174), since it needs real nights with both.
