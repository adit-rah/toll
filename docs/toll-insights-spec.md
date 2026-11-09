# Toll — Insights & Sharing Spec (v0.1)

Companion to `toll-mvp-spec.md`. Requirement IDs here are `I-n` (insights) and `S-n` (share). Config keys are `insights.*` and `share.*`; defaults in §9.

## 1. Purpose

Toll records facts at the gate. Insights turns those facts into the handful of views a person would actually want to see about themselves, their friends and their school, and a share card they would actually send. Nothing here judges; it shows distributions, trends and comparisons, and the user draws the conclusion.

Rules that bind everything in this doc:

- Every number is derived from gate events (`toll-mvp-spec.md` §4). No screen-time minutes exist; never imply them.
- Facts, numbers, questions. No adjectives about the user. A chart title is a fact ("Passes by hour"), never a verdict ("Your worst hours").
- Small numbers are suppressed, not shown as noise (§7).
- Friends' names never appear on anything that leaves Toll (§6).
- Insights is one tap from Home and one tap back. It is a place to look, not a place to live: no infinite history, no notifications, no badges.

## 2. Data

Per person, from events:

| Metric | Derivation |
|---|---|
| `hits` | count of `block_hit` |
| `passes` | count of `pass`; split `free` / `waited` |
| `held` | hits followed by neither a `wait_started` nor a free `pass` within `gate.resumeWindow` (the user walked away) |
| `heldPct` | held ÷ hits |
| `abandoned` | count of `wait_abandoned` (started a wait, cancelled) |
| `waitMinutes` | sum of wait durations on `pass(waited)` |
| `cleanDays` | days in range with `passes == 0` and blocks on |
| `tollOpens` | Toll foreground opens |
| `byTag` | any metric grouped by tag |
| `byHour` | any metric bucketed into 24 local hours (day boundary per `gate.dayResetHour`) |
| `byWeekday` | any metric by local weekday |
| `lateShare` | passes between `insights.lateStart` and `gate.dayResetHour` ÷ passes |
| `trend` | this week ÷ last week − 1, for passes (negative is improvement) |
| `sessionChoice` | distribution of chosen session lengths |

Ranges: today, yesterday, this week, last week, last 8 weeks, term (since account creation or `insights.termStart`).

Where computed:

- **Me**: on device from the local event store. Works in solo mode. No server needed.
- **Friends**: server computes per-friend weekly rollups (the same rollups Home already needs) plus the per-hour histogram for the week. Client fetches `GET /insights/friends?week=`.
- **School**: server computes school rollups nightly (cron): distribution of passes/week, heldPct, byHour curve, tag share. Only served when `network.schoolMinMembers` is met. Client fetches `GET /insights/school?week=`; the current week's numbers are as of the last nightly run, and the card says so ("as of 4 a.m.").

## 3. Views

Insights is a single vertically scrolling screen with three segments at the top: **Me · Friends · School**. Default segment: Me. Each segment is a short stack of cards; every card answers one question and has one chart or one number row. Cards are ordered by how often people will want them; nothing collapses or reorders.

### 3.1 Me

**I-1 This week vs last.** Hero: passes this week and last week as two numbers; beneath, held %, wait minutes, clean days, Toll opens, each with last week's value small beside it. (The Home "you" block shows a subset; this is the full set.)

**I-2 Day by day.** 14 bars: last week in neutral, this week in accent, one per day, passes. Today's bar is outlined. Tap a bar: that day's number and its passes list (tag, time, wait).

**I-3 Passes by hour.** 24-bar histogram for the selected range (week default; toggle 8 weeks). Late hours (`insights.lateStart`→reset) are shaded lightly under the bars. Caption: "42% of your passes are after 11 p.m." (only if `passes ≥ insights.minN`).

**I-4 Weekday pattern.** 7 bars, average passes per weekday over the last 8 weeks. Caption with the highest and lowest weekday as a fact.

**I-5 By app.** Horizontal bars per tag: passes and wait minutes. Caption: "Instagram cost you 34 minutes of waiting this week."

**I-6 Gates.** Three numbers: block hits, held (walked away), abandoned waits. Caption: "You walked away from 61% of gates this week." This is the number the product exists for; the title stays a noun.

**I-7 Eight weeks.** Line of weekly passes for the last 8 weeks with a thin line for held %. Weeks the user marked as exam weeks (I-9) are shaded.

**I-8 Term heatmap.** Calendar grid (weeks × 7) since term start; cell fill = passes that day (sequential scale, 5 steps); clean days are the lightest cell, empty days (blocks off) are blank. Tap a cell: the day.

**I-9 Exam weeks.** The user can mark any week as an exam week (toggle on the week in I-7 or I-8). Marked weeks get a label and a comparison line: "Exam weeks: 9 passes/week. Other weeks: 15." No automatic detection.

### 3.2 Friends

Shown only with ≥ 1 friend; otherwise one line and an invite button.

**I-10 Distribution.** Histogram of passes this week across friends (including you). Bins auto from `insights.binRule`. Your bin is accent; others neutral. Caption: "You and 2 of 6 friends had under 10 passes this week." No one is named on this chart.

**I-11 Gates held, by friend.** Dot/bar per friend, held % this week, your dot accent. Names shown (this is in-app; friends already see each other's held % in Friend detail). Ordered by held % descending. Caption: the friends number from Home ("Your friends held 83% of gates this week").

**I-12 When your friends reach.** 24-bin curve of all friends' passes by hour (sum), with your own histogram overlaid as outlined bars. Caption: a fact about the peak hour.

**I-13 Week on week, friends.** 8-week line of friends' held % and passes per person (you included). Caption: change vs last week.

**I-14 Same app, same hour.** One line, computed, shown only when true for ≥ 3 friends: "3 of your friends opened TikTok after 11 p.m. this week." (Fact; no names.)

### 3.3 School

Shown only when verified and the school meets `network.schoolMinMembers`; otherwise one line: "Not enough people at your school yet."

**I-15 Distribution.** Histogram of passes this week across the school; your bin accent. Caption: "You're in the group with 5–9 passes. 31% of UofT is there." Not a rank: no percentile wording ("better than 60%") in 0.1.

**I-16 School vs you, held %.** Two numbers and an 8-week two-line chart: school held % and your held %.

**I-17 School by hour.** Normalised curve of school passes by hour with yours overlaid.

**I-18 What the school blocks.** Share of blocks by tag across the school, one horizontal bar with segments. Caption: "TikTok is the most blocked app at Waterloo."

**I-19 Exam weeks, school.** If ≥ `insights.examMarkMin` members marked a week as an exam week, the school charts shade it.

## 4. Charts

- Swift Charts throughout. One accent colour (you), one neutral (others), one sequential ramp (heatmap), one light shade (late hours). Charts never use the three level colours; the status glyph in `toll-design.md` carries level, charts carry counts.
- Bars for counts, lines for trends over weeks, binned bars for distributions, `RectangleMark` grid for the heatmap. No pies, no donuts, no gauges, no 3D.
- Tabular (monospaced-digit) numerals for every number. Axis labels minimal: first and last, plus the hour or weekday ticks that matter. Gridlines light; no chart borders; no legends when colour is explained by the caption.
- Fixed heights per chart type (design doc). Charts never scroll horizontally in 0.1.
- Every chart has an `accessibilityLabel` and an `AXChartDescriptor` (audio graph).
- Tap selection on bars/cells shows the value in a small callout; selection clears on scroll.
- Charts render in light and dark from semantic tokens only.

## 5. Captions

Each card has at most one caption, generated from a template, always a fact with a number. Templates live in one file with the metric that feeds them. If the metric fails the small-n rule, the caption is omitted (not replaced by a cheerful fallback).

## 6. Share cards

**S-1.** Sharing is user-initiated from the Insights share button; nothing is auto-shared and Home has no share affordance. Uses `ShareLink` with a rendered image.

**S-2. Formats.** Story (1080×1920) and square (1080×1080). Rendered with `ImageRenderer` from the same SwiftUI card views at 3× scale. Dark and light variants; the user's current appearance is the default; a toggle on the preview switches.

**S-3. Cards.**

| Card | Contents |
|---|---|
| Week (me) | "11 passes this week · 17 last week". Held %, clean days, wait minutes. Small 14-bar day-by-day chart. |
| Day (me) | "0 passes today" or "3 passes today". Hour marks of passes as ticks on a 24-hour line. |
| Gates | "Walked away from 61% of gates this week". Hits / held / abandoned. |
| Friends (aggregate) | "My friends held 83% of gates this week". Count of friends, passes per person. No names. |
| School | "UofT held 71% of gates this week. I held 80%." Histogram with my bin highlighted. |
| Exam weeks | "Exam weeks: 9 passes/week. Other weeks: 15." Two bars. |

**S-4. Every card** carries: the Toll wordmark (small, one corner), the user's display name (toggle off allowed), the date range, and the user's invite link in short form (`toll.app/i/XXXX`) at the bottom. The invite link is the growth loop; it is never removed.

**S-5.** Friends' names and any per-person friend data MUST NOT appear on a card. School cards show aggregates only. Mutuals never appear.

**S-6.** Cards use the same tokens as the app; large tabular numerals; one accent; high contrast in both variants (≥ 4.5:1 for all text).

**S-7.** A share is recorded as our own instrumentation event (`share_card`, card type, format) — never as a gate event, never visible to friends.

## 7. Small numbers

- A caption or distribution needs `n ≥ insights.minN` underlying events or people, else it is omitted.
- School aggregates need `network.schoolMinMembers` active members; a histogram bin at the school level with fewer than `insights.schoolBinMin` people is merged into its neighbour.
- Friends distribution needs ≥ `insights.friendsMinN` friends; below that, show I-11 (named, per-friend) only, which friends already see on Home.

## 8. Build tasks

1. `MetricsEngine` (iOS, pure Swift, no UI): events in → every §2 metric out, for a range. Unit-tested against fixture event logs (day boundary at 04:00, DST change week, empty ranges, tag grouping).
2. `InsightsView` Me segment: I-1…I-9 with chart components from `toll-design.md`.
3. Hour histogram per user-week and the endpoints `GET /insights/friends`, `GET /insights/school` with suppression. (Per-user and school rollups are built in the MVP spec's E4.23 and E4.26; this task consumes them.)
4. Friends and School segments: I-10…I-19.
5. Exam-week marking (local + synced flag per user-week).
6. Share cards: `ShareCardView` variants, `ImageRenderer` pipeline, preview sheet with appearance toggle, `ShareLink`.
7. Accessibility pass: labels, audio graphs, Dynamic Type at the largest standard size without clipping.
8. Fixture generator for screenshots and the review account: the MVP spec's E10.46 seeding script, extended with an 8-week history shaped to exercise every card.

## 9. Configuration

| Key | Default |
|---|---|
| `insights.lateStart` | 23 (local hour) |
| `insights.minN` | 5 |
| `insights.friendsMinN` | 3 |
| `insights.schoolBinMin` | 5 |
| `insights.examMarkMin` | 10 |
| `insights.binRule` | Sturges, capped at 8 bins |
| `insights.termStart` | date of the first recorded event on the device (user may set) |
| `share.formats` | story, square |

## 10. Not in 0.1

Percentile or rank wording at school. Comparison between two named friends. Streak counters of any kind (clean days are a count, not a streak mechanic). Predictions ("at this rate…"). Any insight that requires screen-time minutes. Scheduled or automatic sharing. Widgets.
