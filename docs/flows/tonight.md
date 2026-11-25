# Tonight through a day

**What it's for:** Tonight is the glance: what the night is doing now, what to do about it if anything, and the whole day as a strip. This chart covers what the state shows and in which order the code decides it, the one card slot, what each part opens, and how a day moves through the states.

**Implements:** D63 and D64 (Tonight is a tab and a composition), D69 (last night's card, a review since the founder's call of 25 Nov), D73 (one quiet line for another block), D75 (eyebrows say what the time means; the strip is the whole day; only what's tappable looks tappable), D76 and D83 (the lock before bed), D80 and D85 (Before bed), D86 (the card floats and never moves the state), D33 (no selling at night), D48 (Screen Time off is said), D67 and D70 (the pause), D79 and D81 (landmark mornings).

**Code:** `TollCore/App/HomeSnapshot.swift` (the hero, the pill, the eyebrow), `TonightCard.swift` (the slot), `Morning.swift` (last night, and its folded row's status), `DayTimeline*.swift`, `GapSnapshot.swift`; `TollFeatures/Home/` (`HomeView`, `HomeHero`, `LastNightBand` (the row in the slot), `LastNightCard`, `TonightCardView`, `DayStrip`, `StripSnippet`, `OtherBlockLine`, `PillView`, `HomeParts`); `App/RootView.swift` (`LiveHome`: what each tap opens; a 20-second refresh and a per-minute clock).

## What the state shows

The checks run in this order (`HomeSnapshot.hero`, then the Screen Time override). The night's times are the lock's: bed minus the gap. Last night never takes the state's place: it is a card in the slot each morning and a segment at the strip's start all day (below).

```mermaid
flowchart TD
  open(["Tonight appears, every minute, or after any change"]) --> entitled{"Free nights left, or bought?"}
  entitled -->|"no"| off["Dusk is off, this morning or since; Turn Dusk back on card<br/>render: home-paused"]
  entitled -->|"yes"| nightOn{"The night's block on now?"}
  nightOn -->|"yes"| pauseOpen{"A pause open?"}
  pauseOpen -->|"yes"| paused["Paused until …, then locked until 7:00 am; Lock again<br/>render: home-pause-open"]
  pauseOpen -->|"no"| locked["Apps locked until …; the pauses as dots; Pause<br/>render: home-blocked"]
  nightOn -->|"no"| hasNight{"A night block with a next start?"}
  hasNight -->|"no"| noNight["Your night: Set your night<br/>render: home-no-blocks"]
  hasNight -->|"yes"| awayCheck{"Home set, location Always,<br/>inside the lock's hours, not home?"}
  awayCheck -->|"yes"| away["Night ends at …: Apps lock when you're home<br/>render: home-away"]
  awayCheck -->|"no"| placeCheck{"Home set and location Always?"}
  placeCheck -->|"no: Anywhere"| anywhere["Apps lock at … · N min before bed; Anywhere · starts in …<br/>render: home-anywhere"]
  placeCheck -->|"yes"| evening["Apps lock at … · N min before bed; At home · starts in …<br/>render: home-evening"]

  off --> stCheck
  paused --> stCheck
  locked --> stCheck
  noNight --> stCheck
  away --> stCheck
  anywhere --> stCheck
  evening --> stCheck
  stCheck{"Set up, Screen Time not allowed,<br/>and free or bought?"}
  stCheck -->|"yes"| stOff["Screen Time is off (the state and the note)<br/>render: home-screen-time-off"]
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
  facts -->|"yes"| morningCheck{"Before noon, not put away for this night,<br/>no Screen Time or location note?"}
  morningCheck -->|"yes"| row["Folded to one row in the slot, every time Tonight appears:<br/>moon, Last night, the outcome's glyph and words, chevron down<br/>render: home-morning, home-morning-gap, home-day"]
  morningCheck -->|"no"| strip
  row --> status{"The row's status (Morning.status)"}
  status -->|"a landmark: the 7th, 30th, 100th or 365th night that ran"| statusLandmark["30 nights. Orion is in your sky.<br/>render: home-morning-landmark"]
  status -->|"it ran, with or without a break"| statusRan["lock: Locked 8 h 45 m"]
  status -->|"away"| statusAway["figure.walk: Away, nothing locked"]
  status -->|"Screen Time off"| statusOff["hourglass: Screen Time was off"]
  row -->|"tap the row"| card["The card, grown up from its row: Last night, OK, chevron up;<br/>Apps locked from … to …; the bar; Apps open from … to …;<br/>You chose sleep over a locked app N times; Last 7 nights<br/>render: home-morning-open"]
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

## The card slot

One note or card at a time, the first that applies. It floats where it fits and never moves the state (D86).

```mermaid
flowchart TD
  slot(["Tonight's slot"]) --> stOff{"Screen Time off after setup?"}
  stOff -->|"yes"| stNote["Screen Time is off for Dusk. Nothing can be blocked. Turn on<br/>render: home-screen-time-off"]
  stOff -->|"no"| locNote{"The night has a place and location is short of Always?"}
  locNote -->|"yes"| locationNote["The location note: Change in Settings<br/>render: home-location"]
  locNote -->|"no"| lastNight{"Last night's card is due<br/>(before noon, not put away)?"}
  lastNight -->|"yes"| lastNightCard["Last night's row, folded; open, its card with OK<br/>render: home-morning, home-morning-open, home-morning-card"]
  lastNight -->|"no"| entitled{"Free nights left, or bought?"}
  entitled -->|"no"| empty(["No card"])
  entitled -->|"yes"| blocking{"Any block on now?"}
  blocking -->|"yes"| inGap{"In the gap before bed, helpers on,<br/>Before bed's card not answered?"}
  inGap -->|"yes"| beforeBed["Something for the next N minutes?<br/>render: home-before-bed-card"]
  inGap -->|"no"| empty
  blocking -->|"no"| nightEnded{"A night has ended since setup?"}
  nightEnded -->|"no"| empty
  nightEnded -->|"yes"| gapWeek{"The gap changed this week, unseen,<br/>and it's still Monday's night?"}
  gapWeek -->|"yes"| gapWeekCard["This week, apps lock 30 min before bed<br/>render: home-gap-week"]
  gapWeek -->|"no"| homeCard{"Home not set, card not put away?"}
  homeCard -->|"yes"| homeOffer["Only when I'm home?<br/>render: home-card"]
  homeCard -->|"no"| headsUp{"iOS not asked about notifications,<br/>card not put away?"}
  headsUp -->|"yes"| headsUpOffer["A heads-up before your night?<br/>render: home-heads-up"]
  headsUp -->|"no"| gapOffer{"An install from before the gap, offer not answered?"}
  gapOffer -->|"yes"| gapOfferCard["Lock apps 15 min before bed?<br/>render: home-gap-offer"]
  gapOffer -->|"no"| empty
```

What each opens: Turn on, [permissions.md](permissions.md); Change in Settings, iOS Settings; Before bed and the gap cards, [before-bed.md](before-bed.md); home, [set-home.md](set-home.md); the heads-up, [heads-up.md](heads-up.md). "Not now" puts an offer away for good; Monday's "OK" puts away only this week's; last night's "OK" puts away only that night's card, and the strip still opens it.

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
  wake(["The night ends at wake: the monitor's window end and sweep reconcile"]) --> morning["Apps lock at …, with last night's row in the slot until noon or OK<br/>render: home-morning"]
  morning -.->|"noon, or OK"| afternoon["Apps lock at …; last night at the strip's start<br/>render: home-evening"]
  wake -.->|"last night was due and didn't run"| afternoon
  afternoon -.->|"a day block starts (e.g. Study 9–5 on weekdays)"| dayLine["Apps lock at … with Study on until 5:00 pm, Pause<br/>render: home-day"]
  dayLine -.->|"the day block ends"| afternoon
  afternoon -.->|"Monday noon: three pauses again, last week's gap judged"| afternoon
  afternoon -.->|"20 min before the lock: the heads-up, if on"| afternoon
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
- **"Your night" with Set your night** (`home-no-blocks`) is reachable only when the night's block has no rule that starts again; onboarding can't produce that, and the editor refuses an empty schedule, so it may be unreachable outside a damaged state file.
- **Screen Time off replaces the state, but not while the free nights are over:** the Off state wins then (`if screenTimeOff, state.trial.entitled`). The note still shows (the note checks only `screenTimeOff`). Intended by #45 as far as the code says.
- **Last night's card beside another block:** the card is a review, not an offer, so it floats while Study is on in the morning, with Study's line under the state (`render: home-day`). Offers still wait while any block is on.
- **The pill and the card slot both hide for any block,** not only the night: `state.isBlocking` is true while Study is on, so on a weekday at 11 am there is no pill and no offer (D33 says "no selling at night"). Matches the code.
- **A night with Screen Time off shows last night's card only if Screen Time is back on**; while it's still off, the Screen Time state replaces everything, so that night's facts aren't shown.
- **The card floats only until noon,** as the morning card did; after that, and after OK, the strip's start is the way back to it until the next lock.
- **The row is folded each time Tonight appears** (a tab switch, or the app coming back from the background), so an open card never greets the person. OK is only in the open card: the folded row stays until noon.
- **Where the open card goes:** it grows up from its row while its bottom edge stays 20 pt above the strip. Where it no longer fits there, it goes under the state and the screen scrolls (D86's last place), never under the bar, so it never jumps away from its row.
