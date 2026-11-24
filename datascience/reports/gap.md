# The growing gap with personal timing

D76 makes the lock start a gap before bed: 15 minutes at first, growing by 15 a week toward 60 while weeks go smoothly, easing by 15 after a hard week. For people who opt in, personal timing (D66) still tries −30, 0 or +30 minutes around that plan, held for a week. D76 stands only if D66's marks still hold with the gap moving under them; if not, personal timing waits until the gap settles. This report checks both, and what the gap itself costs and buys (#114). It is exploration in the simulator, not a new artifact. `artifacts/`, `export/` and the Swift package are unchanged.

```
uv run python -m sim.gap_sweep marks --people 1000 --out reports/gap-sweep.json                     # every variant, about 2 min
uv run python -m sim.gap_sweep marks --people 2000 --seed 20261124 \
  --only d66,B,B-comfortable,B-comfort30,B-comfort60,B-bed,C,D --out reports/gap-final.json
uv run python -m sim.gap_sweep marks --people 2000 --seed 20261124 --nights 84 --only d66,B,C,D --out reports/gap-final-12wk.json
for s in 101 202 303 404 505; do uv run python -m sim.gap_sweep marks --people 2000 --seed $s --only d66,B,C,D \
  --scenarios differ,differ+drift,null,null+drift --out seed$s.json; done
uv run python -m sim.gap_sweep pool reports/gap-final.json seed101.json seed202.json seed303.json seed404.json seed505.json \
  --out reports/gap-seeds.json
uv run python -m sim.gap_sweep tradeoffs --people 1000 --out reports/gap-tradeoffs-sweep.json
uv run python -m sim.gap_sweep tradeoffs --people 2000 --seed 20261124 --only "*/base,*/saturating" \
  --scenarios differ,same,null --out reports/gap-tradeoffs.json
```

The code is in `sim/gap_rule.py` (the weekly rule and the tolerance), `sim/gap.py` (the nights) and `sim/gap_sweep.py` (the variants and what is measured). With no gap, `sim.gap` gives exactly the numbers of D66's policy in `sim.dampen` (a test checks it), so every difference below comes from the gap.

## What was assumed

The rule is D76's. Everything about how people meet it is an assumption: nothing has measured how people take a lock that starts before bed, or what it does to their sleep.

**The rule, as simulated.** Each Monday the week before is judged. Smooth (the lock ran on 4 nights or more, at most 1 pause started inside the gap, Screen Time never off): +15, up to 60. Hard (2 or more pauses inside the gap): −15. Screen Time switched off: −15 and no growth at the next 2 Mondays. After an ease, two smooth weeks in a row are needed to grow. Anything else holds. New installs start at 15. The gap never goes below 0 or above 60; nobody sets one by hand, and nobody taps "keep the old one" on Monday. Personal timing's held week starts the same Monday.

**The link to personal timing (D76).** If the insight says earlier helps, the gap keeps growing. If the start settles at the plan (the ±15 test), growth stops. If later helps, the gap eases a step once and stops.

**Sleep.** Sleep onset is measured from bed, which never moves. Each person's effect of an earlier start (c1 minutes per 30, from the scenarios in `dampening.md`) applies to the gap exactly as to personal timing's moves, in a straight line out to 90 minutes before bed. A 60-minute gap is then worth twice what a 30-minute move is. This is the assumption that matters most for the sleep numbers. Part 2 also tries a version where each minute past 30 counts half. In the non-linear scenario the bend stays around the plan, so the start's effect, the number the insight reports, is still c1.

**The model** is v0's and sees only the start's offset from the plan (−30, 0 or +30), as today's artifact would. Two changes that would need a new artifact were tried: the model sees the start from bed, gap included (`B-bed`), and the model allows that a person's usual onset moved whenever the gap changes (`loosen`).

**Tolerance (assumed).** Each person has a comfort: the minutes before bed they can go without their apps, drawn from a normal with mean 45 and sd 20 (at least 0). While the lock starts within comfort, the nightly chance of a pause inside the gap is 3%. Past it, the chance rises toward 50%: about 28% at 15 minutes past, 40% at 30 past. With 6 nights at home, a week at comfort is hard 1% of the time, and a week 15 minutes past it about half the time. The lead counts personal timing's offset too: a −30 week on a 45-minute gap is a lock 75 minutes before bed. Pauses are capped at 3 a week (D67). Comfort is unrelated to the person's effect. Part 2 tries means of 30 and 60.

**Dropout (assumed).** A hard week ends with Screen Time switched off 20% of the time. Half of those people leave it off for good (10% per hard week), and the others are back on Monday, where the rule's switched-off branch applies. A person who leaves it off has no lock and gives the model no more nights. Part 2 tries 5% and 20% per hard week.

**What isn't modelled.** A pause doesn't change that night's sleep, which flatters long gaps. Losing the lock costs a dropout only the gap's benefit in "sleep against a lock at bed" below; the cost of losing the whole night's lock is not priced, so the real cost of dropout is larger. People already on Dusk (gap 0, one card) are not simulated.

Everything else is as in `dampening.md`: the same synthetic people, six scenarios, limits, drift ("null + drift" and "differ + drift": the usual onset wanders by 2 minutes a night) and fade.

## How to read the tables

- **Δ** is personal timing's own gain against always using the plan, as in `dampening.md` (differ / same / nonlinear; below zero is asleep earlier). The plan is now bed minus the gap.
- **Sleep against a lock at bed** is the whole change from the gap and personal timing together, against a lock at bed with no personal timing, per night at home in "differ". Nights after someone leaves for good count 0.
- **Coverage**, **null**, **by 28 / by 56** and **≥15 by 56** are D66's marks: 90% ranges hold the truth for 85–95% of people at night 56 in each of the six scenarios; at most 5% of null people ever shown an insight; at least half of "differ" people with an effect of 15 minutes or more get one by night 56. Everyone counts, including people who left.
- **Dropout** is the share who switched Screen Time off for good by night 56. **Hard weeks** is the share of judged weeks that were hard.
- **Lock changes** is the number of nights a week the lock's time differs from the last night it ran, from the gap and personal timing together.

## 1. D66's marks with the gap as the plan

Finalists: 2,000 people per scenario, seed 20261124, 9 scenarios. **B** is D76's plan. **C** is an order not in the issue: for people who opt in, the gap holds at 15 until personal timing settles, and grows only if earlier helps. **D** is D76's fallback: personal timing waits until the gap settles (reaches 60, or eases once), then starts on the next Monday.

| | D66, no gap | **B: D76's plan** | B, everyone comfortable | B, comfort mean 60 | C: gap waits for timing | D: timing waits for gap |
|---|---|---|---|---|---|---|
| Δ differ / same / nonlinear (min) | −5.7 / −0.3 / −3.9 | −5.2 / −0.3 / −3.8 | −5.3 / −0.3 / −3.9 | −5.2 / −0.3 / −3.8 | −5.5 / −0.3 / −3.8 | −2.6 / −0.2 / −1.8 |
| Sleep against a lock at bed: 8 weeks / weeks 5–8 | −5.7 / −7.8 | −12.5 / −14.0 | −19.1 / −24.4 | −14.7 / −17.1 | −9.6 / −12.0 | −11.9 / −14.3 |
| Coverage, six scenarios (%) | 89.3–94.5 | 88.2–94.5 | **84.7**–94.5 | 86.9–94.5 | 90.1–94.5 | 86.5–93.8 |
| Coverage with drift / with fade (%) | 88.0 / 89.2 | 86.7 / 88.7 | **82.5** / 88.1 | 85.1 / 88.4 | 88.2 / 89.3 | **82.4** / 92.7 |
| False insights: null / null + drift (%) | 3.2 / 4.9 | 2.9 / 4.3 | 3.2 / 4.9 | 3.0 / 4.5 | 3.1 / 4.7 | 1.8 / 2.5 |
| Differ insight by 28 / by 56 (%) | 16 / 28 | 15 / 27 | 16 / 28 | 15 / 27 | 15 / 27 | **1** / 19 |
| ≥15 by 56: plain / drift (%) | 54 / 52 | **49 / 47** | 50 / **49** | **49 / 47** | 52 / **48** | **37 / 36** |
| ≥15 by 56, people still on (%) | 54 / 52 | 51 / 49 | 50 / 49 | 50 / 47 | 53 / 48 | 41 / 40 |
| Dropout: differ / null (%) | 0 / 0 | 14.1 / 12.2 | 0 / 0 | 10.5 / 8.7 | 6.2 / 4.2 | 15.2 / 14.8 |
| Hard weeks (%) | 0 | 23 | 0 | 16 | 9 | 23 |
| Gap reached 60 / at 60 in week 8 (%) | — | 53 / 27 | 94 / 91 | 71 / 41 | 4 / 3 | 76 / 30 |
| Lock changes a week: all / weeks 7–8 | 0.38 / 0.26 | 0.63 / 0.48 | 0.55 / 0.27 | 0.62 / 0.46 | 0.45 / 0.38 | 0.69 / 0.62 |
| Settled by 56: differ / null (at the plan in null) (%) | 55 / 58 (55) | 52 / 53 (51) | 56 / 58 (55) | 54 / 55 (52) | 54 / 56 (53) | 36 / 37 (35) |
| ≥15-min effects settled at the plan (%) | 4.8 | 5.7 | 8.3 | 6.5 | 5.0 | 4.7 |
| People an earlier start hurts, asleep later than a lock at bed (%) | 37 | 96 | 100 | 98 | 66 | 99 |
| Starts outside limits / gap over 60 / lock over 90 min before bed | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |

Bold in a cell marks a value outside its mark; the "people still on" row is not a mark. Each column covers 798,000–856,000 lock nights. The wake time is the lock's end and is never moved by anything simulated. In "differ", a person's effect is drawn from a normal with mean 8 and sd 15 minutes per 30, so about 30% of people sleep later with an earlier start; the 96% row is about them.

**The learning mark over six runs.** The one mark B is close to was rerun with five more seeds (2,000 people each, 12,000 in all; `gap-seeds.json`). The same people meet every policy in a run, so the differences between columns are paired.

| ≥15 by night 56 (%) | D66, no gap | B | C | D |
|---|---|---|---|---|
| differ: mean (lowest–highest run) | 53.2 (49–57) | **50.1** (47–55) | 51.7 (49–56) | **36.5** (33–39) |
| differ + drift | 52.1 (51–54) | **48.1** (46–51) | **49.5** (48–53) | **35.5** (33–38) |
| differ, people still on | 53.2 | 52.6 | 52.4 | 40.6 |
| Coverage, differ / differ + drift | 89.9 / 87.6 | 88.6 / 86.5 | 90.0 / 87.8 | 86.0 / **82.9** |
| False insights, null / null + drift | 3.5 / 4.5 | 3.2 / 4.1 | 3.4 / 4.4 | 2.1 / 3.1 |

**Twelve weeks** (2,000 people, 84 nights; `gap-final-12wk.json`). D needs about 12 weeks to reach the learning mark: 52% of ≥15 effects have an insight by night 84 (55% with drift), and 51% within 56 nights of personal timing starting. Its coverage stays low (85.4% in differ, 83.2% with drift). By night 84, B reaches 60% and D66 alone 67%.

### Every variant (1,000 people per scenario, seed 7)

| Tried | Δ differ / same / nonlinear | Sleep against bed | Coverage six / drift (%) | Null / + drift (%) | By 28 / by 56 / ≥15 / ≥15 drift (%) | Dropout · reached 60 (%) · lock changes |
|---|---|---|---|---|---|---|
| D66, no gap | −5.6 / −0.4 / −3.9 | −5.6 | 90.1–95.2 / 88.0 | 3.4 / 4.3 | 16 / 27 / 53 / 56 | 0 · 0 · 0.38 |
| D66, no gap, with tolerance | −5.5 / −0.3 / −3.9 | −5.4 | 90.0–95.3 / 88.3 | 3.4 / 4.3 | 15 / 26 / 52 / 55 | 3 · 0 · 0.38 |
| **B: D76's plan** | −5.3 / −0.3 / −3.7 | −11.9 | 89.7–94.3 / 87.7 | 3.0 / 3.9 | 16 / 25 / **48** / 50 | 17 · 58 · 0.63 |
| B, everyone comfortable | −5.4 / −0.4 / −3.9 | −18.1 | **84.6**–94.4 / **81.5** | 3.4 / 4.3 | 16 / 27 / 51 / 52 | 0 · 95 · 0.55 |
| B, comfort mean 30 | −5.3 / −0.3 / −3.8 | −9.8 | 90.1–94.6 / 88.9 | 3.0 / 3.8 | 16 / 25 / **47** / **49** | 22 · 38 · 0.61 |
| B, comfort mean 60 | −5.3 / −0.3 / −3.7 | −13.9 | 88.5–94.3 / 85.0 | 3.2 / 4.1 | 16 / 26 / **49** / 50 | 11 · 72 · 0.62 |
| B, model sees the start from bed | −5.8 / −0.1 / −3.9 | −12.2 | 87.5–94.3 / **83.0** | 4.4 / **5.3** | 25 / 39 / 73 / 72 | 17 · 57 · 0.60 |
| B, gap ignores personal timing | −5.3 / −0.3 / −3.8 | −11.7 | 89.5–94.3 / 87.7 | 3.0 / 3.9 | 16 / 25 / **48** / 50 | 17 · 66 · 0.66 |
| B, intercept loosened at each change (sd 10) | −5.1 / −0.3 / −3.5 | −11.8 | 91.8–**96.4** / 92.9 | 1.3 / 1.4 | 8 / 19 / **38** / **39** | 18 · 61 · 0.65 |
| Same, sd 5 | −5.2 / −0.3 / −3.7 | −11.9 | 90.6–**95.2** / 90.9 | 2.3 / 2.6 | 14 / 23 / **44** / **48** | 17 · 59 · 0.64 |
| Same, sd 10, everyone comfortable | −5.2 / −0.4 / −3.7 | −17.9 | 89.4–**95.8** / 89.8 | 1.6 / 2.0 | 7 / 21 / **44** / **45** | 0 · 98 · 0.58 |
| Same, sd 5, everyone comfortable | −5.4 / −0.4 / −3.9 | −18.1 | 87.6–94.9 / 85.7 | 2.6 / 3.2 | 14 / 25 / **49** / 51 | 0 · 96 · 0.56 |
| Same, sd 10, comfort mean 60 | −5.1 / −0.3 / −3.5 | −13.7 | 91.6–**96.3** / 91.7 | 1.3 / 1.5 | 8 / 20 / **42** / **41** | 12 · 76 · 0.65 |
| **C: gap waits for timing** | −5.4 / −0.3 / −3.8 | −9.2 | 89.2–94.4 / 87.8 | 3.3 / 4.2 | 15 / 26 / 50 / 52 | 7 · 4 · 0.45 |
| **D: timing waits for gap** | −2.6 / −0.2 / −1.6 | −11.1 | 86.6–94.2 / **80.8** | 2.3 / 3.1 | 1 / 18 / **36** / **35** | 18 · 78 · 0.68 |
| D, everyone comfortable | −2.6 / −0.2 / −1.7 | −15.2 | **83.5**–93.9 / **77.7** | 2.6 / 3.4 | 0 / 21 / **42** / **39** | 0 · 100 · 0.62 |
| D, intercept loosened (sd 10) | −2.5 / −0.2 / −1.4 | −11.0 | 90.1–**95.8** / 88.2 | 1.5 / 1.6 | 0 / 15 / **31** / **29** | 18 · 78 · 0.68 |
| D, loosened, everyone comfortable | −2.6 / −0.2 / −1.6 | −15.2 | 87.0–95.0 / **84.8** | 2.7 / 3.1 | 0 / 17 / **33** / **33** | 0 · 100 · 0.63 |

The raw numbers, per scenario, are in `gap-sweep.json`.

## 2. The gap's own trade-offs

No personal timing here: everyone's lock starts at bed minus the gap. 2,000 people, seed 20261124, the assumptions above.

| | Fixed 15 | Fixed 30 | Fixed 45 | Fixed 60 | **Grows (D76)** |
|---|---|---|---|---|---|
| Sleep against a lock at bed, differ: 8 weeks / weeks 5–8 (min) | −4.2 / −4.1 | −8.2 / −8.1 | −11.8 / −11.3 | −14.7 / −13.5 | **−10.9 / −12.3** |
| Same, everyone's effect 3 min per 30 | −1.5 | −2.9 | −4.2 | −5.2 | **−3.8** |
| Differ, if each minute past 30 counts half | −4.2 | −8.2 | −9.8 | −11.1 | **−9.1** |
| Dropout by night 56 (%) | 2.2 | 5.3 | 13.7 | 25.1 | **11.8** |
| Hard weeks / weeks with Screen Time switched off (%) | 2.7 / 0.6 | 7.5 / 1.4 | 20.5 / 4.1 | 41.4 / 8.3 | **16.7 / 3.4** |
| Nights a week with a pause inside the gap | 0.22 | 0.35 | 0.66 | 1.10 | **0.60** |
| Mean gap on lock nights (min) | 15 | 30 | 45 | 60 | **41** |
| Reached 60 / at 60 in week 8, of people still on (%) | — | — | — | 100 / 100 | **82 / 53** |
| Gap in week 8, people still on: 0 / 15 / 30 / 45 / 60 (%) | | | | | **1 / 4 / 17 / 25 / 53** |
| Lock changes a week | 0 | 0 | 0 | 0 | **0.53** |

**How much depends on the assumptions** (1,000 people, seed 7; sleep against a lock at bed in "differ", then dropout by night 56):

| Assumption | Fixed 15 | Fixed 30 | Fixed 45 | Fixed 60 | Grows |
|---|---|---|---|---|---|
| As above (comfort mean 45; 10% leave per hard week) | −3.8 · 2% | −7.4 · 7% | −10.5 · 15% | −12.7 · 27% | −9.5 · 13% |
| Comfort mean 30 | −3.7 · 6% | −7.0 · 15% | −9.5 · 27% | −12.0 · 35% | −7.9 · 17% |
| Comfort mean 60 | −3.8 · 1% | −7.5 · 2% | −11.0 · 7% | −14.0 · 15% | −11.1 · 7% |
| 5% leave per hard week | −3.8 · 1% | −7.5 · 3% | −10.9 · 8% | −13.9 · 15% | −10.0 · 6% |
| 20% leave per hard week | −3.8 · 4% | −7.2 · 12% | −10.0 · 24% | −11.1 · 44% | −9.0 · 23% |
| Each minute past 30 counts half | −3.8 · 2% | −7.4 · 7% | −8.8 · 15% | −9.5 · 27% | −7.9 · 13% |

The 1,000-person runs draw different people from the 2,000-person ones, so their "differ" means differ by about a minute; compare within a table. The raw numbers are in `gap-tradeoffs.json` and `gap-tradeoffs-sweep.json`.

## What we learned

- **B keeps every D66 mark but learning, and learning sits on the line.** Under the assumptions, B's coverage (88.2–94.5%), false insights (2.9%, 4.3% with drift) and safety hold. Half of people with an effect of 15 minutes or more get an insight by night 56 only on average and without drift: 50.1% over six runs (47–55% per run), 48.1% with drift, against D66's 53.2% and 52.1% on the same people. D66 met the mark with 2–4 points to spare, and the gap uses them up. Among people still using Screen Time at night 56, B reaches 52.6%, close to D66: most of the loss is people who left. When nobody leaves but everyone's gap grows to 60, the moving plan alone costs about as much (50% against 54% at the finalist seed).
- **The moving plan blurs the estimate, and blurs it most when the gap grows smoothly.** If an earlier start helps, every step of the gap shifts the person's usual onset. The model sees only the start's offset from the plan, so it has to absorb the shift in its intercept, and over 8 held weeks part of it is read as the start's effect. With the assumed tolerance the gap stalls for many people and coverage holds (88.2% in differ). If nearly everyone takes the gap to 60 without a hard week, coverage falls to 84.7% in differ and 82.5% with drift, below the mark. With a comfort mean of 60 it is 86.9% and 85.1%, just inside. So the coverage mark holds only while the gap is held back by hard weeks: it fails in the case where the gap works best.
- **D, the fallback, is worse than B on every mark it is meant to protect.** Personal timing starts in week 4 (median), after the gap first reaches 60 or eases. By night 56 only 36.5% of ≥15 effects have an insight (35.5% with drift), and 1% of differ people have one by night 28. Coverage is lower too (86.0% in differ, 82.9% with drift). The model enters personal timing with three weeks of nights at offset 0 and a smaller gap, and the before-and-after contrast probably leaks into the estimate: loosening the intercept at each gap change brings D's coverage with drift back to 88.2%. D gives up half of personal timing's benefit (−2.6 against −5.2), its gap reaches 60 more often (76% against 53%) and its lock time changes more (0.69 a week). It reaches the learning mark only by about week 12.
- **C, the other order, keeps the marks best but gives up most of the gap for people who opt in.** With the gap held at 15 until personal timing settles, the plan barely moves while the model learns. Coverage is 90.1–94.5%, the learning mark is 51.7% (49.5% with drift), and dropout is 6% (the −30 weeks still push some people past comfort). Only 4% reach 60 by week 8, so the sleep against a lock at bed is −9.6 against B's −12.5. It is also the only order that protects people an earlier start hurts (66% of them sleep later, against 96% under B).
- **Fixes to the model trade one mark for another.** Loosening the intercept whenever the gap changes restores coverage (89–96%) but costs learning (38% at sd 10, 44% at sd 5). Letting the model see the start from bed, gap included, learns much faster (75% of ≥15 effects by night 56) because the gap is another source of variation. But the gap's path is not randomized: it rises with time like drift does, so false insights with drift reach 6.6% and coverage 83.5%. The insight's "because" needs randomized moves, so the gap should not enter the start's feature.
- **The link between the gap and personal timing changes little in 8 weeks.** With the gap ignoring personal timing, every mark is within a point of B. Only 52% of people settle by night 56, and growth is stopped for those who settle at the plan, so the link mostly matters later.
- **The gap is worth more sleep than personal timing, if the assumption about it holds.** If a lock an hour before bed works like the ±30 moves, in a straight line, the growing gap gives 10.9 minutes a night sooner in "differ" against personal timing's 5.7. If everyone's effect is the small one in "same", it gives 3.8. If each minute past 30 counts half, 9.1. None of this has been measured. Under the same assumption, the 30% of "differ" people an earlier start hurts sleep later with any gap, and personal timing in B doesn't change that (96%). Personal timing's own benefit under B is about the same as without a gap (−5.2 against −5.7).
- **The growing rule gets a fixed 45's sleep with a fixed 45's dropout, and it is safer when comfort is unknown.** Under the base assumptions it gives −10.9 minutes with 11.8% dropout, against −11.8 and 13.7% for a fixed 45 and −8.2 and 5.3% for a fixed 30. Its value is that it adapts: across comfort means of 30 to 60, its dropout stays within 7–17%, while a fixed 45 ranges 7–27% and a fixed 60 15–35%. 82% of people reach 60 at some point, and 53% are there in week 8.
- **The rule finds each person's edge by crossing it.** One judged week in six is hard (16.7%), and in 3.4% of weeks Screen Time is switched off. How many of those people leave for good is the assumption that moves dropout most: 6% at 5% per hard week, 12% at 10%, 23% at 20%. Every person who leaves loses the whole night's lock, which the sleep numbers here don't count.
- **Side finding about D66 itself.** With 12 weeks instead of 8, D66 with no gap shows a false insight to 5.0% of null people and 6.9% with drift. The checks look every night, and the 98% test was tuned for 56 nights. The mark is set at night 56, but people will use Dusk longer.

## Answer

**Do D66's marks still hold with the gap as the plan? Not cleanly.** Under the assumed tolerance and dropout, B keeps coverage, false insights and safety, but the learning mark sits on the line: 50.1% without drift and 48.1% with it, against 53% for D66 alone. Coverage also fails (84.7%) if nearly everyone takes the gap to 60 without trouble. Read strictly, D76's condition is not met.

**But D, the fallback D76 names, fails the same marks by more.** Its learning mark is 36.5%, its coverage with drift 82.9%, and it halves personal timing's benefit. Falling back to D would not protect the marks. If the marks must hold strictly, the order that does it is C: the gap waits until personal timing settles, for people who opt in. That costs most of the gap's growth for them (4% reach 60 by week 8). Otherwise B is the better of D76's two options, and the learning mark has to be read as "about half".

## For the founders

1. **B or C, not D.** D is worse than B on learning, coverage and benefit. If personal timing must keep D66's marks, the order to choose is C (the gap waits for personal timing). If the gap matters more, choose B and accept that the learning mark is about 50% rather than 53%.
2. **The learning mark is too thin to absorb anything.** D66 met it with 2–4 points to spare. Any dropout or moving plan uses that up. Should the mark count only people still using Screen Time (B: 52.6%)?
3. **Everything about the gap's value is an assumption.** In the simulator, the gap's sleep benefit and its dropout come from two numbers we made up: how a lock an hour before bed changes sleep, and how many people leave after a hard week. The pilot's night records (with the gap, D76) can measure the first only roughly, because the gap isn't randomized. Measuring the second needs Screen Time switch-offs counted after hard weeks.
4. **The gap can't help people an earlier start hurts.** If 30% of people are like that, nearly all of them sleep later under B, and the gap only eases if personal timing finds it. That is a reason to let the insight ease the gap further than one step.
