# Tonight through a day

**What it's for:** Tonight is the glance: what the night is doing now, what to do about it if anything, and the whole day as a strip. This chart covers what the state shows and in which order the code decides it, Tonight's band (which card, and last night's row, when), what each part opens, and how a day moves through the states.

**Implements:** D63 and D64 (Tonight is a tab and a composition), D69 (last night's card, a review since the founder's call of 25 Nov), D73 (one quiet line for another block), D75 (eyebrows say what the time means; the strip is the whole day; only what's tappable looks tappable), D76 and D83 (the lock before bed), D80 and D85 (Before bed), D86 (the card floats and never moves the state), the band system (one rule for the band, amending D86, D91 and D93), D33 (no selling at night), D48 (Screen Time off is said), D67 and D70 (the pause), D79 and D81 (landmark mornings).

**Code:** `TollCore/App/HomeSnapshot.swift` (the hero, the pill, the eyebrow), `TonightBand.swift` (the band's rule), `TonightCard.swift` (each card's own facts), `Morning.swift` (last night, and its folded row's status), `DayTimeline*.swift`, `GapSnapshot.swift`; `TollFeatures/Home/` (`HomeView`, `HomeHero`, `TonightBandView` (the band), `LastNightBand` (last night's row), `LastNightCard`, `TonightCardView`, `DayStrip`, `StripSnippet`, `OtherBlockLine`, `PillView`, `HomeParts`); `App/RootView.swift` (`LiveHome`: what each tap opens; a 20-second refresh and a per-minute clock).

## What the state shows

The checks run in this order (`HomeSnapshot.hero`, then the Screen Time override). Each state leads with its glyph over the eyebrow (`StateMark`, named first in each box), so the states tell apart with every word wiped (#74). The night's times are the lock's: bed minus the gap. Last night never takes the state's place: it is a row in Tonight's band each morning and a segment at the strip's start all day (below).

```mermaid
flowchart TD
  open(["Tonight appears, every minute, or after any change"]) --> entitled{"Free nights left, or bought?"}
  entitled -->|"no"| off["power at 64 pt: Dusk is off, this morning or since; Turn Dusk back on card<br/>render: home-paused"]
  entitled -->|"yes"| nightOn{"The night's block on now?"}
  nightOn -->|"yes"| pauseOpen{"A pause open?"}
  pauseOpen -->|"yes"| paused["pause: Paused until …, then lock: locked until 7:00 am; Lock again<br/>render: home-pause-open"]
  pauseOpen -->|"no"| locked["lock: Apps locked until …; You're home (or nothing with home not set); the pauses as dots; Pause<br/>render: home-blocked, home-blocked-anywhere, home-pause-waiting"]
  locked -.->|"Only when I'm home changed tonight (held, B-3)"| lockedHeld["… · Anywhere from the next night (or Only at home from the next night)<br/>render: home-held-home"]
  nightOn -->|"no"| hasNight{"A night block with a next start?"}
  hasNight -->|"no"| noNight["moon: Your night: Set your night<br/>render: home-no-blocks"]
  hasNight -->|"yes"| awayCheck{"Home set, location Always,<br/>inside the lock's hours, not home?"}
  awayCheck -->|"yes"| away["figure.walk: Night ends at …: house: Apps lock when you're home<br/>render: home-away"]
  awayCheck -->|"no"| placeCheck{"Home set and location Always?"}
  placeCheck -->|"no: Anywhere"| anywhere["clock: Apps lock at … · N min before bed; Anywhere · starts in …<br/>render: home-anywhere"]
  placeCheck -->|"yes"| evening["clock: Apps lock at … · N min before bed; At home · starts in …<br/>render: home-evening"]

  off --> stCheck
  paused --> stCheck
  locked --> stCheck
  noNight --> stCheck
  away --> stCheck
  anywhere --> stCheck
  evening --> stCheck
  stCheck{"Set up, Screen Time not allowed,<br/>and free or bought?"}
  stCheck -->|"yes"| stOff["warning triangle at 64 pt: Screen Time is off (the state and the note)<br/>render: home-screen-time-off"]
  stCheck -->|"no"| shown(["The state as decided above"])
```

Around the state, independent of it:
- **The free-night pill** in the bar ("Night 5 of 14 free", "Last free night tonight") shows while the free nights run, nothing is blocking, and the state isn't away or Set your night (`render: home-first-week`, `home-last-night`). It opens the purchase sheet (`render: home-pill-purchase`, [purchase.md](purchase.md)).
- **Another block on** (Study, Work, Gym, Other) is one quiet line under the state, "Study on until 5:00 pm", with Pause when the state doesn't already offer it (`render: home-day`).
- **The strip** is the day from wake to wake, every block on it (`render: home-evening`, `home-day`). While the state is "Apps lock at" and last night ended within the day (it ran, was away, or had Screen Time off), last night sits at the strip's start as a faint amber stub with its moon; a tap opens last night's card in the popover (`render: home-strip-last-night`).

## Last night's card

```mermaid
flowchart TD
  ended(["The night ended at wake"]) --> facts{"It ran, was away, or had Screen Time off<br/>(not due-and-didn't-run, not after the trial)?"}
  facts -->|"no"| none(["No card, no segment: Tonight looks ahead"])
  facts -->|"yes"| strip["Last night at the strip's start, until the next lock<br/>render: home-strip-last-night"]
  facts -->|"yes"| morningCheck{"Before noon, not put away for this night,<br/>not the hour before the lock (Tonight's band)?"}
  morningCheck -->|"yes"| row["Folded to one row in the band, under any card, every time Tonight appears:<br/>moon, Last night, the outcome's glyph and words, chevron up<br/>render: home-morning, home-morning-gap, home-day"]
  morningCheck -->|"no"| strip
  row --> status{"The row's status (Morning.status)"}
  status -->|"a landmark: the 7th, 30th, 100th or 365th night that ran"| statusLandmark["30 nights. Orion is in your sky.<br/>render: home-morning-landmark"]
  status -->|"it ran, with or without a break"| statusRan["lock: Locked 8 h 45 m"]
  status -->|"away"| statusAway["figure.walk: Away, nothing locked"]
  status -->|"Screen Time off"| statusOff["hourglass: Screen Time was off"]
  row -->|"tap the row"| card["The card, grown up from its row: Last night, OK, chevron down;<br/>Apps locked from … to …; the bar, a pause's break marked with the pause glyph; Apps open from … to …;<br/>You chose sleep over a locked app N times; Last 7 nights<br/>render: home-morning-open"]
  card -->|"tap its header"| row
  card -->|"OK"| seen[("state.json: lastNightSeen = the night")]
  seen --> strip
  strip -->|"tap"| popover["The same card, open, in a popover<br/>render: home-strip-last-night"]
  card --> landmark{"A landmark?"}
  landmark -->|"yes"| landmarkLine["Inside the card: the completed shape, 30 nights. Orion is in your sky., Share<br/>render: home-morning-landmark-open"]
  landmarkLine -->|"Share"| share{{"iOS share sheet: the sky poster<br/>render: sky-share"}}

  classDef system stroke-dasharray: 5 3
  class share system
```

## Tonight's band

What floats between the state and the strip (`TonightBand`). Every item has a kind, and each kind has its part of the day, so kinds rarely meet. When more than one is due, one full card shows, picked by kind, and last night's folded row may sit under it, nearest the strip. Never more than two items. The band goes where it fits without moving the state (D86): 20 pt above the strip, else under the bar (not when it holds last night's row), else under the state, where the screen scrolls.

| Kind | Items | When it may show | When it competes |
|---|---|---|---|
| 1. Problem | Screen Time off, a build that can't save, a night without its apps, location short of Always | Any time, until fixed | Takes the card. Last night's row may sit under it |
| 2. Night | Before bed's card; Monday's gap card | Before bed's: in the gap only. Monday's: from Monday noon until Tuesday noon, while nothing is locked, the hour before the lock included | Loses only to a problem. On Tuesday morning, last night's row sits under Monday's card |
| 3. Flow | A one-time flow's card (D92) | At a calm time: nothing locked, free nights left or bought, not in the hour before the lock, not during the night | Loses to a problem or a night card, and waits a day. Last night's row may sit under it |
| 4. Setup | Home, then the heads-up, then the gap offer (one at a time) | At a calm time, and only after a night has ended since setup | Loses to all of the above and waits for a calm time. Last night's row may sit under it |
| 5. Review | Last night's folded row | From the night's end until noon, until OK, never in the hour before the lock | Always the row, never the card: it sits under whichever card shows |

From 60 minutes before the lock (`TollConfig.band.nightMinutes`) until the night ends, the band belongs to the night. Before the gap, it shows at most one card about the night (Monday's). In the gap, it shows Before bed's card, or nothing. Setup offers and flows wait for tomorrow. A problem still shows: it stays until fixed.

```mermaid
flowchart TD
  band(["Tonight's band: Tonight appears, every minute, or after any change"]) --> problem{"A problem?<br/>Screen Time off, then a build that can't save,<br/>then a night without its apps, then location"}
  problem -->|"yes: the first"| problemCard["Its note<br/>render: home-screen-time-off, home-read-only, home-recovered, home-location"]
  problem -->|"no"| entitled{"Free nights left, or bought?"}
  entitled -->|"no"| noCard(["No card"])
  entitled -->|"yes"| gap{"In the gap: the night locked, before bed,<br/>helpers on, Before bed's card not answered?"}
  gap -->|"yes"| beforeBed["Something for the next N minutes?<br/>render: home-before-bed-card"]
  gap -->|"no"| monday{"Monday's card: the gap changed this week, unseen,<br/>still Monday's night, nothing locked?"}
  monday -->|"yes"| mondayCard["This week, apps lock 30 min before bed<br/>render: home-gap-week, home-night-hour-monday"]
  monday -->|"no"| calm{"A calm time: nothing locked, not the night,<br/>more than 60 min before the lock?"}
  calm -->|"no"| noCard
  calm -->|"yes"| flow{"A one-time flow due today?"}
  flow -->|"yes"| flowCard["The flow's card: Fit Dusk to your sleep, see once-fit-sleep.md<br/>render: home-morning-flow, home-fit-card"]
  flow -->|"no"| setup{"A night ended since setup, and an offer due:<br/>home, then the heads-up, then the gap offer?"}
  setup -->|"yes"| setupCard["Only when I'm home? · A heads-up before your night? · Lock apps 15 min before bed?<br/>render: home-card, home-heads-up, home-gap-offer"]
  setup -->|"no"| noCard

  problemCard --> review
  beforeBed --> review
  mondayCard --> review
  flowCard --> review
  setupCard --> review
  noCard --> review
  review{"Last night to review: before noon, not OK'd,<br/>not in the hour before the lock?"}
  review -->|"yes"| row["Last night's row, under the card, nearest the strip<br/>render: home-morning, home-morning-card, home-morning-location, home-morning-gap-week"]
  review -->|"no"| done(["The card alone, or nothing<br/>render: home-night-hour"])
  row -->|"tap the row"| open["Last night opens upward; the card above fades out (200 ms) while it's open,<br/>and fades back when it folds<br/>render: home-morning-open, home-morning-card-open"]
  open -->|"tap its header"| row
```

What each opens: Turn on, [permissions.md](permissions.md); Change in Settings, iOS Settings; Before bed and the gap cards, [before-bed.md](before-bed.md); home, [set-home.md](set-home.md); the heads-up, [heads-up.md](heads-up.md). "Not now" puts an offer away for good; Monday's "OK" puts away only this week's; last night's "OK" puts away only that night's row, and the strip still opens it.

### Who owns the band through a day

For a night from 10:30 pm to 7:00 am with a 30-minute gap, so the lock is at 10:00 pm. A problem can show in every stretch.

```mermaid
flowchart LR
  wake(["7:00 am<br/>the night ends"]) --> morning["7:00 am to noon<br/>Review: last night's row,<br/>under one card if one is due"]
  morning --> calm["Noon to 9:00 pm<br/>Calm: a flow or an offer;<br/>Monday's card from Monday noon"]
  calm --> hour["9:00 pm to 10:00 pm<br/>The night's hour: Monday's card only;<br/>offers wait for tomorrow"]
  hour --> gapStretch["10:00 pm to 10:30 pm<br/>The gap: Before bed's card, or nothing"]
  gapStretch --> night["10:30 pm to 7:00 am<br/>The night: nothing but a problem"]
  night --> wake2(["7:00 am"])
```

## What Tonight opens

```mermaid
flowchart LR
  tonight["Tonight<br/>render: home-evening"]
  tonight -->|"gear"| settings["Settings<br/>render: settings"]
  tonight -->|"the pill"| purchase["The purchase sheet<br/>render: home-pill-purchase"]
  tonight -->|"Dusk is off: Turn Dusk back on"| purchase
  tonight -->|"Pause (state or the other block's line)"| pause["The pause sheet<br/>render: door-choosing"]
  tonight -->|"Lock again, while paused"| relock[("state.json: the pause ends")]
  tonight -->|"Before bed capsule"| helpers["Before bed's sheet<br/>render: before-bed"]
  tonight -->|"Set your night"| nightEditor["Your nights editor<br/>render: block-night"]
  tonight -->|"last night, at the strip's start"| lastNightPopover["Last night's card in a popover<br/>render: home-strip-last-night"]
  tonight -->|"a segment of the strip"| snippet["A popover: name, state, hours, apps, place, Edit<br/>render: home-strip-night, home-strip-day"]
  snippet -->|"Edit"| editor["The block's editor, pushed on Tonight; Back returns to the strip<br/>render: block-edit"]
  tonight -->|"tabs"| tabs["Your sleep, Blocks<br/>render: insights, blocks"]
```

## A day through Tonight

```mermaid
flowchart TD
  wake(["The night ends at wake: the monitor's window end and sweep reconcile"]) --> morning["Apps lock at …, with last night's row in the band until noon or OK<br/>render: home-morning"]
  morning -.->|"noon, or OK"| afternoon["Apps lock at …; last night at the strip's start<br/>render: home-evening"]
  wake -.->|"last night was due and didn't run"| afternoon
  afternoon -.->|"a day block starts (e.g. Study 9–5 on weekdays)"| dayLine["Apps lock at … with Study on until 5:00 pm, Pause<br/>render: home-day"]
  dayLine -.->|"the day block ends"| afternoon
  afternoon -.->|"Monday noon: three pauses again, last week's gap judged"| afternoon
  afternoon -.->|"60 min before the lock: the band is the night's; offers wait"| nightHour["Apps lock at …; Monday's card or nothing<br/>render: home-night-hour, home-night-hour-monday"]
  nightHour -.->|"20 min before the lock: the heads-up, if on"| nightHour
  nightHour -.->|"the lock"| atHome
  afternoon -.->|"the lock: bed minus the gap, monitor's window start"| atHome{"Home set and away?"}
  atHome -->|"away"| awayState["Night ends at …<br/>render: home-away"]
  awayState -.->|"arrives home: region event relaunches the app"| gap
  atHome -->|"home, or anywhere"| gap["Locked, in the gap: Before bed capsule, its card once<br/>render: home-before-bed, home-before-bed-card"]
  gap -.->|"bed"| night["Apps locked until 7:00 am<br/>render: home-blocked"]
  gap -->|"Pause"| pausedState["Paused until …<br/>render: home-pause-open"]
  night -->|"Pause"| pausedState
  pausedState -.->|"10 minutes, or Lock again"| night
  night -.->|"wake"| wake
  night -.->|"the last free night ends, not bought"| offState["Dusk is off this morning<br/>render: home-paused"]
```

## Doubts
- **"Your night" with Set your night** (`home-no-blocks`) is reachable only when the night's block has no rule that starts again; onboarding can't produce that, and the editor refuses an empty schedule, so it may be unreachable outside a damaged state file. With no night block at all, the button isn't drawn (`setNight` is nil): state files always hold one (`DuskState`, D73), and a lost file comes back from the night record (#140), so that state isn't reached (#124).
- **Screen Time off replaces the state, but not while the free nights are over:** the Off state wins then (`if screenTimeOff, state.trial.entitled`). The note still shows (the note checks only `screenTimeOff`). Intended (#141): the state says the larger fact (nothing blocks until it's bought), and the note is a problem that holds until fixed (the band's rule), since after buying nothing could block with Screen Time still off.
- **Last night's card beside another block:** the card is a review, not an offer, so it floats while Study is on in the morning, with Study's line under the state (`render: home-day`). Offers still wait while any block is on.
- **The pill and the band's offers both hide for any block,** not only the night: `state.isBlocking` is true while Study is on, so on a weekday at 11 am there is no pill and no offer. Intended (#141): the band's calm times say "nothing is locked", and D85 keeps every offer away while apps are locked.
- **A night with Screen Time off shows last night's card only if Screen Time is back on**; while it's still off, the Screen Time state replaces everything, so that night's facts aren't shown.
- **The card floats only until noon,** as the morning card did; after that, and after OK, the strip's start is the way back to it until the next lock.
- **The row is folded each time Tonight appears** (a tab switch, or the app coming back from the background), so an open card never greets the person. OK is only in the open card: the folded row stays until noon.
- **Where the open card goes:** it grows up from its row while its bottom edge stays 20 pt above the strip. Where it no longer fits there, it goes under the state and the screen scrolls (D86's last place), never under the bar, so it never jumps away from its row. A card above the row fades out while last night is open, so the open card never pushes it into the state or covers it.
- **A problem and last night's row together:** the location note, a lost night's apps or a build that can't save sit above last night's row each morning. Screen Time off is the exception: the state says so and last night isn't shown at all.
- **Monday's card on Tuesday morning:** it shows until Tuesday noon, as before, so a person who didn't open Dusk on Monday still sees it; that morning it sits over last night's row.
- **A flow's calm and the band's calm differ:** `Flows.calm` keeps the last 20 minutes before the lock quiet, the band the last 60. The band is the stricter, so a flow is never shown inside the hour; `Flows.due` may still call one due there.
