# The pause economy

#61 asks whether the escape's numbers are right. The issue predates D67, so today's numbers are the pause's (`TollConfig.unlocks`, `TollConfig.door`): **3 pauses a week**, shared by every block, back to 3 at noon each Monday and none carried over; a **60-second wait** that costs nothing to cancel; **10 minutes** open; "Lock again" within 2 minutes gives it back. The issue asked for night records to tune them from. There are none yet from real people, so this is a simulator study: what today's numbers do across simulated people, which of the unknowns decide whether to change them, and what data would settle it.

```
uv run python -m economy.pauses grid --people 4000 --out reports/pauses-grid.json
uv run python -m economy.pauses sensitivity --people 4000 --out reports/pauses-sensitivity.json
uv run python -m economy.pauses power --people 4000 --out reports/pauses-power.json
```

The code is `economy/pauses.py`. It is separate from the sleep model and changes nothing in `sim/`, `artifacts/` or the Swift packages.

## What was assumed

Everything about how people meet the pause is made up, and written down in `Behaviour`:

- **Wants.** On a lock night (9 h 45 min: 8 h 30 min of sleep with D97's 30 minutes before and 15 after; at home 9 nights in 10), a person wants a pause at random moments. The median person wants one 0.3 times a night (about 2 a week); people differ, so a quarter want one at least twice as often as the median.
- **The wait.** With a pause left, they start the 60-second wait and see it through with chance exp(−wait / patience). The median patience is 120 s, so the median person sees a 60 s wait through 61% of the time and cancels the rest, at no cost (D-3).
- **The pause.** It opens every block for its minutes. A want during an open pause is met by it.
- **None left.** The want is refused. 10% of refusals end with Screen Time switched off for the rest of that night, and 30% of those people leave it off for good. Separately, 0.5% of lock nights are switched off for other reasons (about 3% of weeks, near what `reports/gap.md` assumed for hard weeks).
- **Not modelled:** day blocks (they share the pool, so the cap would bind sooner); what a pause costs that night's sleep beyond its open minutes; "Lock again" (it returns a pause only in its first 2 minutes); the gap's own weekly rule (`reports/gap.md` covers pauses inside the gap).

**Measured,** per person-week unless named: pauses used, waits cancelled, weeks the pauses ran out, wants refused, weeks with Screen Time switched off, people gone by night 56, minutes a pause was open per lock night, and **minutes unshielded per lock night**: open pauses, the rest of a night after a switch-off, and whole nights once someone has left. The last is the one number that prices both directions: a looser escape opens more minutes, a tighter one loses more nights.

## Today's numbers and their neighbours

4,000 people, 8 weeks, base assumptions (`pauses-sensitivity.json`, "base"). One number changes at a time.

| | Used | Cancelled | Weeks ran out | People ever ran out | Refused | Weeks Screen Time off | Gone by night 56 | Paused min a night | Unshielded min a night |
|---|---|---|---|---|---|---|---|---|---|
| **Today: 3 a week, 60 s, 10 min, back Monday** | 1.13 | 0.85 | 20% | 56% | 0.49 | 7% | 12% | 1.8 | 43 |
| 2 a week | 0.87 | 0.67 | 32% | 77% | 0.72 | 9% | 18% | 1.4 | 65 |
| 4 a week | 1.30 | 0.97 | 13% | 39% | 0.34 | 6% | 9% | 2.0 | 33 |
| 5 a week | 1.43 | 1.04 | 9% | 27% | 0.24 | 5% | 6% | 2.3 | 23 |
| 30 s wait | 1.31 | 0.42 | 26% | 66% | 0.61 | 8% | 15% | 2.1 | 55 |
| 120 s wait | 0.82 | 1.57 | 12% | 38% | 0.30 | 5% | 7% | 1.3 | 26 |
| 5 min open | 1.13 | 0.85 | 20% | 56% | 0.50 | 7% | 12% | 0.9 | 43 |
| 15 min open | 1.13 | 0.85 | 20% | 56% | 0.49 | 7% | 12% | 2.7 | 44 |
| At most 1 a night, 3 a week | 1.05 | 0.78 | 15% | 47% | 0.60 | 8% | 14% | 1.6 | 50 |

The full grid (2–5 a week × 30/60/120 s × 5/10/15 min × weekly or at most 1 a night, 72 rows) is in `pauses-grid.json`.

## Which unknowns decide it

Minutes unshielded per lock night · share gone by night 56, for each candidate under each assumption (one assumption changed at a time from the base).

| Assumption | today | 2 a week | 4 a week | 5 a week | 30 s wait | 120 s wait | 5 min | 15 min | 1 a night |
|---|---|---|---|---|---|---|---|---|---|
| Base | 43 · 12% | 65 · 18% | 33 · 9% | 23 · 6% | 55 · 15% | 26 · 7% | 43 · 12% | 44 · 12% | 50 · 14% |
| Fewer wants (median 0.15 a night) | 14 · 4% | 22 · 6% | 10 · 2% | 7 · 1% | 17 · 4% | 10 · 2% | 14 · 4% | 15 · 4% | 19 · 5% |
| More wants (0.6) | 106 · 28% | 136 · 36% | 84 · 22% | 67 · 17% | 124 · 33% | 74 · 20% | 106 · 28% | 106 · 28% | 113 · 30% |
| Wider spread between people (sd 1.4) | 72 · 18% | 92 · 24% | 59 · 15% | 49 · 12% | 83 · 21% | 53 · 14% | 72 · 18% | 73 · 18% | 81 · 20% |
| Impatient (median 60 s) | 26 · 7% | 42 · 12% | 19 · 5% | 12 · 3% | 43 · 12% | 11 · 3% | 26 · 7% | 26 · 7% | 36 · 10% |
| Patient (median 300 s) | 58 · 16% | 79 · 22% | 42 · 11% | 34 · 9% | 64 · 17% | 48 · 13% | 57 · 16% | 59 · 16% | 61 · 17% |
| Refusals rarely end it (3%) | 19 · 5% | 30 · 8% | 14 · 3% | 11 · 2% | 25 · 7% | 11 · 3% | 19 · 5% | 20 · 5% | 21 · 6% |
| Refusals often end it (30%) | 81 · 21% | 119 · 32% | 55 · 14% | 37 · 10% | 100 · 26% | 49 · 13% | 79 · 21% | 79 · 20% | 100 · 26% |
| More pauses, more wants (wants ∝ supply) | 43 · 12% | **38 · 10%** | 48 · 13% | 53 · 14% | 55 · 15% | 26 · 7% | 43 · 12% | 44 · 12% | 50 · 14% |
| A cancelled wait sometimes ends it (5% a minute waited) | 46 · 12% | 66 · 18% | 33 · 8% | 25 · 6% | 56 · 15% | 32 · 7% | 46 · 12% | 47 · 12% | 51 · 14% |

## What we learned

- **The cost that matters is losing the night, not the open minutes.** A pause opens at most 2–3 minutes a lock night on average. A switch-off or a person leaving costs whole nights. So in this model every number is judged by what it does to switch-offs after running out, and that link (`off_per_refusal`) is a pure assumption. Between 3% and 30% per refusal, today's numbers leave 5% or 21% of people gone by week 8.
- **The supply's direction depends on one unmeasured question: do more pauses make more wants?** If wants don't grow with supply, 4 or 5 a week beats 3 under every other assumption tried (fewer people run out, fewer leave). If wants grow in proportion to supply, the order reverses and 2 a week is best. Nothing in the evidence opened for this work measures either, and the simulator can't tell them apart.
- **A longer wait looks better in every row, which says more about the model than about people.** Cancels are free here, so a longer wait only removes pauses and the refusals that follow. The one cost tried, a cancelled wait sometimes ending in a switch-off, doesn't change the order. What the model can't price is the wait's annoyance felt as Dusk being hostile, which is D67's stated reason for keeping the escape simple.
- **The pause's length barely matters.** 5, 10 or 15 minutes change the unshielded minutes by about 1 a night and nothing else, because nothing here makes a short pause bring the want back sooner. D84's "A pause opens blocked apps for 10 minutes" stays true and costs little.
- **Capping pauses at 1 a night is worse under every assumption.** It refuses wants that a weekly pool would have met on a hard night, and refusals are what cost nights.
- **Under the base assumptions about half of people run out at least once in 8 weeks** (56%), and 20% of weeks run out. That is the number the pilot can check first and most cheaply.

## Answer: wait for real data

**No change to `TollConfig`.** The study supports no change: the only robust findings are that the length barely matters and that a nightly cap is worse, and neither argues for moving today's numbers. Whether 3 a week and 60 s are right turns on three things nobody has measured: how often people want a pause, how many see the wait through, and what they do when none are left.

## The data, and how much

The night records can now carry what's needed. This branch adds `dusk.pauses_before`, `dusk.pauses_after` (where each pause was asked, #145), `dusk.waits` and `dusk.waits_cancelled` (waits started and let go). Already there: `unlocks_used`, `unlocks_returned`, `door_asks` ("Open Dusk to pause" taps), `stops` ("Never mind"), `dusk.screen_time_off`.

| Question | From the records | Needed (base rates, `pauses-power.json`) |
|---|---|---|
| How often people want a pause | `door_asks` + `waits` per lock night; `stops` as a ceiling (every shield tap) | Not sized: every lock night adds to it, so far fewer people than the rows below |
| How many see the 60 s wait through | `waits_cancelled` / `waits` | Not sized: every wait adds to it |
| How often the pauses run out | weeks with `unlocks_used` summing to 3 | ±5 points: about 900 person-weeks, about 75 people for 12 weeks (each person's weeks are alike: design effect 3.9) |
| Whether running out leads to Screen Time off | `screen_time_off` in weeks that ran out against the rest | To see a doubling from about 3% of weeks: about 17,000 person-weeks, about 1,450 people for 12 weeks. Out of a pilot's reach |

**Plan.**
1. Ship the record fields (this branch) so every pilot night has them.
2. After 4 weeks of the pilot, fit `urges_median`, `urges_sd` and `patience_median_s` to the records and rerun `economy.pauses` with them. If the median person wants fewer than about 0.15 a night, the numbers rarely bind and can stay.
3. After 12 weeks with 75 or more people, read the share of weeks that ran out. If it's above about 20%, and the founders want to test a change, randomise people to 3 or 4 a week (one person, one supply) rather than reading the link from observation, which would need ten times the people; the outcome is Screen Time switched off for good by week 8.
4. Don't tune the length.
