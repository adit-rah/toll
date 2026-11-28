# Tuning the v0 starting values

The model spec asks to tune σ, Σ₀, the 10% floor and the ±90 min clip in the simulator until the pass criteria hold, and to write down what was tried. `uv run python -m sim.tune` reruns all of it (1,000 people per scenario, 300 draws for the policy's probabilities, seed 7); the raw numbers are in `tuning.json`.

Coverage is the share of people whose 90% range holds their true start effect after 8 weeks, in scenario order: same, differ, nonresponders, worse, nonlinear, null. "By 28" is the share of "differ" people with an insight by night 28. "Null" is the share of people in the null scenario ever shown an insight. "Δ" is minutes of sleep onset against always using the plan (below zero is earlier), for differ / same / nonlinear.

| Tried | Coverage (%) | Fade | By 28 | Null | Δ differ / same / nonlinear |
|---|---|---|---|---|---|
| As specced: σ 30, effect sd 15, floor 0.10, clip 90, zero test = the 90% range | 90 · **84** · 89 · 89 · 85 · 90 | 85 | 31% | **22%** | −5.5 / −0.4 / −3.7 |
| σ 35 | **95.3** · 87 · 94 · 94 · 91 · **95.6** | 92 | 21% | **10%** | −5.2 / −0.4 / −3.5 |
| σ 40 | **98** · 90 · **96** · **96** · 93 · **99** | 96 | 12% | 3% | −4.9 / −0.4 / −3.3 |
| Effect prior sd 10 | 93 · **75** · 88 · 86 · **81** · 94 | 90 | 27% | **15%** | −5.3 / −0.4 / −3.6 |
| Effect prior sd 20 | 89 · 86 · 88 · 89 · 86 · 89 | **84** | 30% | **21%** | −5.6 / −0.4 / −3.8 |
| Floor 0.20 | 91 · **84** · 89 · 89 · 85 · 90 | 86 | 31% | **21%** | −3.4 / −0.3 / −2.3 |
| Floor 0.33 (every start equally) | 90 · 85 · 88 · 88 · 86 · 90 | 88 | 28% | **21%** | −0.6 / −0.1 / −0.4 |
| Clip 60 | 94 · **82** · 90 · 88 · 85 · 94 | 89 | 26% | **15%** | −5.4 / −0.4 / −3.6 |
| Clip 45 | **95.5** · **77** · 92 · 86 · **84** · **97** | 95 | 20% | **8%** | −5.1 / −0.4 / −3.4 |
| Forgetting 0.98 | **95.6** · 89 · 93 · 93 · 90 · **95.7** | 95 | 26% | **14%** | −5.3 / −0.4 / −3.5 |
| Zero test 95% | as specced | 85 | 23% | **10%** | as specced |
| Zero test 98% | as specced | 85 | 15% | 3.6% | as specced |
| Zero test 99% | as specced | 85 | 12% | 2.1% | as specced |
| σ 32.5, zero test 98% | 93 · 86 · 91 · 92 · 88 · 94 | 89 | 12% | 1.7% | −5.4 / −0.4 / −3.6 |
| σ 32.5, effect sd 20, zero test 98% | 92 · 88 · 91 · 91 · 88 · 92 | 86 | 11% | 2.4% | −5.5 / −0.4 / −3.7 |
| σ 35, zero test 95% | **95.3** · 87 · 94 · 94 · 91 · **95.6** | 92 | 14% | 3% | −5.2 / −0.4 / −3.5 |
| σ 32.5, forgetting 0.99, zero test 98% | **95.8** · 88 · 93 · 93 · 91 · **95.9** | 93 | 10% | 1% | −5.3 / −0.4 / −3.5 |
| **Chosen: σ 30, effect sd 20, forgetting 0.99, zero test 98%** | 92 · 89 · 92 · 92 · 89 · 93 | 89 | 13% | 2.8% | −5.5 / −0.4 / −3.8 |

Bold marks a value outside its pass mark.

## What we learned

- **No σ is right for every scenario on its own.** Where people really do differ, the prior pulls estimates toward zero and σ 30 under-covers (84%). Where everyone is alike, σ 35 over-covers (95.6%). A wider prior on the start effect (sd 20) fixes the first without hurting the second. A slight forgetting factor (0.99: a night's weight halves in about 10 weeks) lifts the rest into the band, and keeps the range honest when the effect fades.
- **The spec's insight rule can't meet its own false-insight mark.** A 90% range excludes zero for about 10% of people whose true effect is zero, and checking every night pushes that to 22%. No σ, prior or clip fixes this without breaking coverage; σ 40 gets to 3% only by over-covering everything. The fix is a stricter test for zero than for the range shown: show the 90% range, but only once a 98% range is clear of zero. That gives 2.8%. A rule that waits for the range to clear zero on 3 or 7 nights in a row was also tried: for the same protection it learns more slowly (at σ 30, waiting 7 nights with the 95% range gave 5.1% false and 12% by night 28; the 98% test alone gives 3.6% and 16%).
- **"Median person gets an insight by night 28" is out of reach for any setting.** Night-to-night noise in sleep onset is about 30 minutes. Even with every start chosen equally often (floor 0.33), 28 nights hold about 20 usable ones, and that only resolves effects larger than about 15 minutes. More exploration costs sleep without speeding learning (floor 0.33 gives up nearly all the benefit and is no faster). Who gets an insight is shown by effect size in `figures/insights-by-effect.png`. This needs the founders; see `docs/decisions.md` D53.
- **The floor and the clip are fine where the spec put them.** A higher floor only gives up benefit. A tighter clip biases estimates when outliers are one-sided (illness and parties only make sleep later).
- **The non-linear scenario costs little.** A linear model of a curved response still moves people toward the better side (−3.8 min a night). Its coverage is the lowest in the band (89%), as expected when the base is wrong.

## sleep-model.v1 (D66, #98, #117)

v1 keeps every number above. What changed, and why:
- **The start policy** is D66's held, settling week, from `dampening.md`: `hold_nights` 7, settle at the insight (`settle_at_insight`), settle at the plan once the 90% range is inside ±15 (`settle_plan_within_min`), and about one settled week in 14 draws again (`settled_explore_share` 0.07).
- **The zero test tightens after 30 usable nights** (`zero_test_spend_after` 30, `zero_test_spend_power` 2), from `longrun.md`. With the 98% test alone, D66's policy tells about 10% of null people about an effect within a year. Tightening keeps that at 3.8% on average over six runs, and the D66 learning mark at 52%.
- **An insight already showing keeps the 98% test**, so it isn't withdrawn only because time passed (`longrun.md`, section 4).

## sleep-model.v2 (#154)

v2 keeps v1's numbers, except where named. What changed, and why (`longrun.md`, section 7):
- **Each person's noise has a scale** (`noise_scale_prior_nights` 5), learned from week sums of residuals with one week's lag, and every range is drawn from the scaled covariance. With v1, a usual time that moved from week to week read as an effect of that week's held start: up to 86% of null people saw a false insight within a year in the simulator's widest profile.
- **The zero tests are a Student t's**, with the weeks the scale rests on as degrees of freedom, since early on it rests on few.
- **The base zero test is 95%** (`zero_test_interval`, was 98%): with honest ranges, 98% was stricter than the 5% mark needs. The shown range is still the 90% one, and an insight showing still keeps the untightened test.
- **The intercept can wander between weeks** (`intercept_week_sd`), in both models, but v2 sets it to 0: it cost more learning than the scale for the same safety.
- The cost: the D66 learning mark falls from 52.6% to 42.9% (pass criteria), and is reported but not enforced until the founders set a new one.
