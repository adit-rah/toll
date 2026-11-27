# The buffer suggestion

#145 replaces the buffers' one-size target (D97: before sleep 30 growing to 60, after waking 15 growing to 30) with one fitted from each person's own weeks, and asks the simulator whether it keeps D53 and D66's marks. The rule is `economy/suggest.py`, and the phone's `BufferSuggestion` in TollCore gives the same answer on every fixture (`economy/fixtures.py`, `BufferSuggestionTests`). It is not in the sleep model's artifact: it reads the weekly rule's verdicts, not the model's numbers, and needs no network or Health beyond what the night records already carry.

```
uv run python -m economy.buffers --people 2000 --seed 20261127 --out reports/buffers-final.json
uv run python -m economy.buffers --people 2000 --seed 20261127 --only base-15 --out reports/buffers-final-base15.json
uv run python -m economy.buffers --people 2000 --seed 20261127 --nights 84 --only d66,base,fitted,fitted-raise --out reports/buffers-final-12wk.json
for s in 101 202 303 404 505; do
  uv run python -m economy.buffers --people 2000 --seed $s --only d66,base,fitted --scenarios differ,differ+drift,null,null+drift --out bseed$s.json
  uv run python -m economy.buffers --people 2000 --seed $s --only base-15 --scenarios differ,differ+drift,null,null+drift --out bseed15-$s.json
done
```

`buffers-seeds.json` pools the six runs (the finalist seed and five more) for the marks that sit near their lines.

## The rule

Each side reads its last 12 weeks. A week is the buffer most of its lock nights had, judged as Monday judges it (D76: smooth, hard, Screen Time off, or hold), from the nights the lock ran, the pauses asked in that buffer and Screen Time. Holds and weeks with no buffer don't count.

1. **Too few weeks:** fewer than 4 judged weeks on a side and its target is the baseline, 60 before sleep and 30 after waking. Every new person is here, so onboarding always offers the baseline.
2. **A ceiling:** the person's comfortable level is the highest one that was smooth more often than hard. The lowest level above it that was hard at least as often as smooth is too much. With one, the target is a step (15) below it, never below the comfortable level and never above the baseline.
3. **Past the baseline,** before sleep only: the last 3 judged weeks all smooth at the same level, at least the baseline, with no pause asked in the buffer; and Health's sleep coming at least 20 minutes after planned sleep (median of at least 14 lock nights with Health's sleep). Then one step past that level. The research's one plausible marker that a longer buffer helps more is a late or slow sleep onset, and it is untested; without Health there's no raise.
4. **Otherwise** the baseline.

Always within the founder's bounds: before sleep 30 to 90, after waking 15 to 30. After waking never goes past 30, since no study has tested a lock after waking at all.

The phone reads the weeks from the night records, which now keep where each pause was asked (`dusk.pauses_before`, `dusk.pauses_after`). Records from before this build don't say, so their weeks are left out rather than read as calm; nobody's target is fitted until they have four weeks of new records.

## How it was simulated

`sim.gap` runs unchanged: D66's personal timing around the buffer, the assumed comfort (mean 45, sd 20 minutes), pause chances and dropout of `sim.gap_rule`, and the six scenarios with drift and fade. Only the Monday judgement is swapped: before each one, every person's weeks so far go through `economy.suggest.target`, and the buffer grows toward, and never stays above, that target.

The app offers the fitted target once, in the one-time flow (#144's "Fit Dusk to your sleep"). The simulator refits it every Monday, which is the most it could move the plan. A mark that holds here holds for the flow.

- **base:** D97: 30 growing to 60 for everyone.
- **base-15:** D76's start of 15, as `gap.md` ran it, to tell D97's start apart from the fit.
- **fitted:** the rule, with no one showing Health's sign, so never past 60.
- **fitted-raise:** the rule with Health's sign for everyone: everyone who sails through 60 for three weeks is offered 75, then 90. The raise's upper bound.
- **fitted-min3 / fitted-min6:** 3 or 6 judged weeks instead of 4.

## D66's marks with the fitted target

2,000 people per scenario, seed 20261127, 8 weeks (`buffers-final.json`, `buffers-final-base15.json`).

| | D66, no buffer | base-15 (D76 start) | **base (D97)** | **fitted** | fitted-raise | fitted-min6 |
|---|---|---|---|---|---|---|
| Δ differ / same / nonlinear (min) | −5.4 / −0.4 / −3.7 | −5.0 / −0.3 / −3.5 | −4.9 / −0.3 / −3.4 | −4.9 / −0.3 / −3.5 | −4.9 / −0.3 / −3.5 | −4.9 / −0.3 / −3.4 |
| Sleep against a lock at bed: 8 weeks / weeks 5–8 | −5.4 / −7.5 | −11.8 / −13.7 | −12.8 / −13.5 | −12.5 / −12.9 | −12.5 / −13.0 | −12.6 / −13.2 |
| Coverage, six scenarios (%) | 89.4–94.8 | 88.4–93.9 | 89.2–94.1 | 89.3–94.2 | 89.3–94.2 | 89.3–94.2 |
| Coverage with drift / with fade (%) | 87.1 / 89.8 | 86.8 / 88.4 | 87.0 / 90.0 | 87.0 / 89.8 | 87.0 / 89.8 | 86.8 / 90.0 |
| False insights: null / null + drift (%) | 3.5 / 3.9 | 3.0 / 3.5 | 3.0 / 3.2 | 3.0 / 3.4 | 3.0 / 3.4 | 3.0 / 3.2 |
| ≥15 by 56: plain / drift (%) | 51.0 / 53.2 | 47.1 / 47.0 | **45.4 / 44.1** | **45.3 / 43.9** | **45.4 / 43.9** | **45.4 / 44.0** |
| ≥15 by 56, people still on (%) | 51.0 | 48.9 | 48.6 | 48.8 | 49.0 | 48.6 |
| Dropout: differ / null (%) | 0 / 0 | 14.5 / 12.8 | 17.4 / 15.2 | 16.4 / 14.3 | 16.5 / 14.4 | 17.2 / 15.0 |
| Hard weeks / Screen Time off weeks (%) | 0 / 0 | 22.7 / 4.4 | 26.6 / 5.2 | 24.8 / 4.8 | 25.0 / 4.9 | 26.2 / 5.1 |
| Nights a week with a pause inside the buffer | 0 | 0.70 | 0.77 | 0.72 | 0.72 | 0.75 |
| Buffer in week 8, people still on: 0 / 15 / 30 / 45 / 60 / 75 (%) | | 11 / 15 / 22 / 23 / 29 / 0 | 10 / 15 / 20 / 26 / 28 / 0 | 11 / 18 / 33 / 21 / 18 / 0 | 11 / 18 / 32 / 21 / 18 / 1 | 10 / 16 / 30 / 23 / 20 / 0 |
| Buffer changes a person: all / from week 5 | 0 / 0 | 4.24 / 1.17 | 3.79 / 1.14 | 3.30 / 0.80 | 3.43 / 0.92 | 3.68 / 1.03 |
| Ever past 60 (%) | 0 | 0 | 0 | 0 | 7.2 | 0 |
| Starts outside limits / largest buffer / largest lead before bed (min) | 0 / 0 / 30 | 0 / 60 / 90 | 0 / 60 / 90 | 0 / 60 / 90 | **0 / 75 / 105** | 0 / 60 / 90 |

Bold marks a value outside its mark. fitted-min3 gave exactly fitted's numbers: after a first hard week the weekly rule already eases and waits for two smooth weeks, so by the time either version could grow again both have four weeks. Each column covers 782,000–857,000 lock nights.

**The learning mark over six runs** (12,000 people per variant; `buffers-seeds.json`). The same people meet every variant in a run, so the differences are paired.

| | D66, no buffer | base-15 | base (D97) | fitted |
|---|---|---|---|---|
| ≥15 by 56, differ: mean (lowest–highest run) | 52.7 (49–57) | **49.8** (47–55) | **47.1** (45–53) | **47.1** (44–53) |
| Same, differ + drift | 52.4 (51–54) | **48.1** (46–51) | **45.7** (44–50) | **45.6** (44–49) |
| Same, people still on | 52.7 | 52.3 | 50.7 | 50.8 |
| Coverage, differ / differ + drift (%) | 90.0 / 87.4 | 88.8 / 86.5 | 89.1 / 86.9 | 89.2 / 87.0 |
| False insights, null / null + drift (%) | 3.5 / 4.4 | 3.2 / 4.0 | 3.1 / 3.8 | 3.1 / 3.9 |
| Dropout, differ (%) | 0 | 14.8 | 17.1 | 16.1 |
| Hard weeks, differ (%) | 0 | 23.0 | 27.0 | 25.3 |
| Sleep against a lock at bed, differ (min) | −5.6 | −12.1 | −13.0 | −12.7 |

**Twelve weeks** (84 nights; `buffers-final-12wk.json`):

| | D66 | base | fitted | fitted-raise |
|---|---|---|---|---|
| Sleep against a lock at bed, differ: all / weeks 5–12 | −6.4 / −8.0 | −12.7 / −12.9 | −12.4 / −12.5 | −12.4 / −12.5 |
| Coverage six / drift (%) | 90.7–96.2 / 87.4 | 89.5–96.1 / 86.8 | 89.4–96.3 / 86.8 | 89.3–96.4 / 86.8 |
| False insights, null / + drift (%) | 4.6 / **6.5** | 4.1 / **5.5** | 4.1 / **5.7** | 4.0 / **5.6** |
| Dropout by night 84, differ / null (%) | 0 / 0 | 22.1 / 18.5 | 19.7 / 17.3 | 20.0 / 17.7 |
| Hard weeks (%) | 0 | 24.5 | 21.6 | 21.8 |
| Buffer changes a person from week 5 | 0 | 2.27 | 1.63 | 1.84 |
| Ever past 60 (%) | 0 | 0 | 0 | 9.3 |

## What we learned

- **The fitted target keeps every mark the baseline keeps, and moves none of them.** Coverage (89.3–94.2%, 87.0% with drift), false insights (3.0%, 3.4% with drift) and safety are the baseline's within 0.2 points. The learning mark is the same as the baseline's on the same people (47.1% against 47.1% over six runs). The fit acts only from a person's fourth judged week, and only on people who found a level hard.
- **What it buys is fewer hard weeks, and so fewer people leaving.** By week 8, 1 point fewer leave (17.1% to 16.1% over six runs) and hard weeks fall from 27.0% to 25.3%. By week 12 it's 2.4 points (22.1% to 19.7%), and the buffer moves about a quarter less after week 4 (2.27 to 1.63 changes a person). It costs 0.3 minutes a night of sleep against a lock at bed (−13.0 to −12.7), because people who kept finding 60 hard stay at 45 instead of reaching it now and then. All of this rests on the assumed tolerance and on 10% of people leaving after each hard week, as in `gap.md`.
- **The learning mark is below its line, and that is D97's start, not the fit.** With the buffer starting at 30 (D97) instead of 15 (D76), 47.1% of people with an effect of 15 minutes or more get an insight by night 56 (45.7% with drift), against 49.8% (48.1%) with a start of 15 on the same people. A start of 30 grows past people's comfort a week sooner: more hard weeks (27.0% against 23.0%), more people leaving (17.1% against 14.8%). Among people still using Screen Time, it's 50.7%. D77 already reads the mark as "about half" and counts people still using Dusk; on that reading it holds.
- **The raise is rare and pushes the lock past 90 minutes before bed.** Even with Health's sign assumed for everyone, 7.2% of people go past 60 in 8 weeks (9.3% in 12), and the marks don't move. But personal timing still tries 30 minutes earlier around a 75-minute buffer, so the lock can start 105 minutes before bed. Nothing else in Dusk starts it more than 90 before. See the founders' questions.
- **More weeks before fitting help little.** Needing 6 judged weeks instead of 4 keeps a fifth of the gain (dropout 17.2% against the baseline's 17.4% and 16.4% with 4, at the finalist seed). 3 weeks is the same as 4 in practice.
- **What the simulator can't say:** whether Health's sign marks people who gain more from a longer buffer. In `sim.gap` a person's comfort and their response to an earlier start are unrelated, and nobody's sleep onset depends on the buffer through anything but the start. The raise is built to be rare and is a test, not a finding.

## Answer

**The rule keeps D66's marks wherever D97's baseline keeps them,** and fails the learning mark only where the baseline fails it, by D97's start rather than the fit. It cuts hard weeks and leaving a little, at a third of a minute of sleep a night, under assumptions nobody has measured. It's safe to ship as the one-time flow's offer.

**`TollConfig` changes:** the v0 rule (`suggestion.before` 60, `suggestion.after` 30) stays as the baseline and the fallback with fewer than 4 judged weeks; the fitted rule's numbers are new (`minWeeks` 4, `lookbackWeeks` 12, `raiseSmoothWeeks` 3, `lateOnsetMinutes` 20, `healthNights` 14, bounds 30–90 and 15–30). No existing default changed.

## For the founders

1. **Should the fitted target also apply at Monday's judgement,** not only when the one-time flow offers it? The simulator refits every Monday and the marks hold, so it can. Today a person's target changes only when they answer the flow or change it in Settings.
2. **Should the raise past 60 stay?** It rests on one untested sign (Health's sleep coming 20 minutes or more after planned sleep) and only reaches people with a watch. If it stays, personal timing should stop trying 30 minutes earlier while the buffer is past 60, so the lock never starts more than 90 minutes before bed.
3. **D97's start of 30 costs the learning mark about 2.7 points** against D76's 15 (47.1% against 49.8%), through more hard weeks and more people leaving. The fitted target doesn't recover it. If the mark must hold as 50% of everyone, the start is the lever, not the fit.
