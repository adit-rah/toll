# One-time flow #2: Personal timing

**What it's for:** personal timing (D66, D99, D107) moves the week's lock start up to 30 minutes either way so the sleep model can learn what helps a person fall asleep, and it is off for everyone until they choose it. D65 says it's offered once, in plain words, after the first week, only with Apple Health (the model learns only from Health's sleep), and can be turned off at any time. This flow is that offer: a card in Tonight's band, and a sheet saying what it does, what it never does, and where it's turned off.

**Implements:** #171, D65 (offered once after the first week, needs Health, can be turned off), D92 (the registry, its calm moments and "Not now"), D94 (Tonight's band, the flow kind), D105 (Tonight's reason never outshouts or moves the time), D107 (`Command.timing`, `TimingRules`, `DuskState.timing`).

**Code:** `TollCore/App/Flows+Timing.swift` (`Flows.timing`, `nightsEnded`), `App/Flows.swift` (`ready`, `due`, `calm`, `record`), `App/TimingLine.swift` (`HeldStart`, `TimingSetting`), `Copy/Copy+Timing.swift`, `TollConfig.timing.offerAfterNights`; `TollFeatures/Home/TonightBandView.swift` (`.flow`), `Home/TimingOfferSheet.swift`, `Home/HomeHero.swift` (`held`), `Settings/TimingRow.swift`, `Settings/BeforeBedRow.swift` (`SleepSettingsView`), `App/AppModel+Timing.swift` (`answerTiming`, `setTiming`), `App/RootView.swift`.

**Applies** (`applies`): `setupFinishedAt` is set, `health` is true, and `timing.on` is false. **Ready** (`ready`): at least `timing.offerAfterNights` (7) of the night's hours have ended since setup, however each went (`Flows.nightsEnded`). Version 1. It comes after flow #1 in the registry, so someone from before #144 is fitted first, and asked this another day.

```mermaid
flowchart TD
  fg(["Dusk comes to the foreground, or Tonight's minute ticks"]) --> applies{"Flows.timing.applies:<br/>set up, Health chosen, timing off?"}
  applies -->|"no"| none(["No card; Tonight as usual"])
  applies -->|"yes"| ready{"Flows.timing.ready: 7 nights ended since setup?"}
  ready -->|"no"| none
  ready -->|"yes"| first{"Flow #1 (fit-sleep) due, or another flow shown today?"}
  first -->|"yes"| none
  first -->|"no"| calm{"Flows.calm: no night, gap or buffer on; no pause;<br/>not in the hour before the lock; no other flow recorded today"}
  calm -->|"no"| none
  calm -->|"yes"| done{"state.flows['personal-timing'] answered or defaulted at version 1?"}
  done -->|"yes"| none
  done -->|"no: Flows.due = personal-timing"| slot{"TonightBand (tonight.md): a problem, a night card or the heads-up's answer wins;<br/>else this, before any offer; last night's row may sit under it"}
  slot -->|"held by another kind"| none
  slot -->|"its turn"| card["Card: timing glyph · Learn what helps your sleep ·<br/>Some weeks, apps could lock up to 30 min earlier or later. · See how › · Not now<br/>render: home-timing-card"]
  card -.->|"appears"| shown[("flows['personal-timing'] = shown, today: offered again at every calm moment today")]
  card -->|"Not now"| notNow{"Third Not now? (flows.offers = 3)"}
  notNow -->|"no"| recNotNow[("flows['personal-timing'] = notNow, notNow + 1")]
  notNow -->|"yes"| defaulted[("flows['personal-timing'] = defaulted;<br/>defaults: none, timing stays off")]
  recNotNow --> later(["Back on a later day"])
  card -->|"See how"| sheet["Sheet: Learn what helps your sleep; a line on trying a start and comparing Health's sleep, on this phone;<br/>rows: up to 30 min earlier or later, one start Monday to Sunday ·<br/>your wake-up time never moves · never more than 90 min before sleep, never after ·<br/>turn it off any time in Settings › Sleep; Turn on · Keep my own time<br/>render: timing-sheet"]
  sheet -->|"Cancel, or swiped away"| later
  sheet -->|"Keep my own time"| kept[("flows['personal-timing'] = answered; timing stays off")]
  sheet -->|"Turn on"| on[(".timing(true); flows['personal-timing'] = answered")]
  on -.->|"at once, and at every opening"| draw(["The week's start is drawn (TimingRules.ask → SleepModel.chooseStart), see before-bed.md"])
  draw --> held{"This week's start isn't the person's own?"}
  held -->|"yes, settled on the insight, which still shows (#182)"| foundReason["Tonight: the same place: timing glyph · 30 min earlier this week, from what Dusk found<br/>(Your sleep's insight is headed What Dusk found)<br/>render: home-timing-settled"]
  held -->|"yes"| reason["Tonight: Apps lock at 9:30 pm; under it, in the minutes-before-sleep line's place,<br/>timing glyph · 30 min earlier this week, to learn what helps (label2, quieter than the line it replaces)<br/>render: home-timing-held"]
  held -->|"no"| own(["Tonight as usual: Apps lock at … · N min before sleep<br/>render: home-evening"])
  kept --> own
```

**The defaults** change nothing: after the third "Not now" the offer never shows again and timing stays off. Settings › Sleep keeps the switch either way ([settings.md](settings.md)); turned on there, the offer no longer applies. Turned off after answering, it isn't offered again.

## Doubts
- **The settled reason** (#182). A week whose start settled on the insight (`Hold.settled`, on the side it supports) reads "from what Dusk found" while the insight still shows on Your sleep. A week drawn to learn keeps "to learn what helps" even if the insight appears mid-week, and so does a settled week whose insight stops holding, or a settled person's week of exploring the other side. The line names where the insight is rather than its minutes, so it never reads as a promise for tonight.
- **Nights, not Health nights.** The first week is 7 of the night's hours ended since setup, however each went (away, paused, Screen Time off), not 7 nights with Health's sleep. The model learns from whatever Health has; a person without a watch gets the offer and learns little, which their Health choice already allows.
- **The reason takes the minutes-before-sleep line** rather than adding one, so the time doesn't move (D105). In a held week Tonight doesn't say "90 min before sleep"; the strip still draws the longer buffer.
