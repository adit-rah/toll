# One-time flow #1: Fit Dusk to your sleep

**What it's for:** people set up before #144 have a night but no buffer after waking, no target of their own for the buffer before sleep, and were never asked about Apple Health. Schema 4's migration step keeps their night exactly as it was; this flow offers them, once, onboarding's steps 2 to 4 (Fit Dusk to your sleep, Your sleep, The time around your sleep) in a sheet, starting from their own night and gap.

**Implements:** #144 (the flow), #140 and D92 (the registry, its calm moments and "Not now"), D86 and D91 (Tonight's band), D76 (the weekly rule, now both sides).

**Code:** `TollCore/App/Flows.swift` (`Flows.fitSleep`, `due`, `calm`, `record`), `Persist/Migration.swift` (`v3to4`), `App/Fit.swift` (`Fit.existing`, `Fit.apply`); `TollFeatures/Setup/FitFlowSheet.swift`, `FitView.swift` (`FitChoice`), `SleepTimesView.swift`, `AroundView.swift`, `FitDraft.swift`; `Home/HomeView.swift` (`HomeNote.flow`), `Home/TonightCardView.swift` (`BandCard`); `App/RootView.swift`, `AppModel.foreground` (`dueFlow`), `AppModel+Intents.swift` (`flow`).

**Applies** (`applies`): `setupFinishedAt` is set and `after.offered` is true. The 3 → 4 step sets `after.offered` for every file it migrates (and `Migration.fromV1` for schema 1); a new install's `finishSetup` never does. Version 1.

```mermaid
flowchart TD
  migrate[("state.json read at schema 3 or older: step 3 → 4<br/>gap.target 60, after = 0 fixed and offered, health false")] --> fg(["Dusk comes to the foreground"])
  fg --> applies{"Flows.fitSleep.applies:<br/>set up, after.offered?"}
  applies -->|"no"| none(["No card; Tonight as usual"])
  applies -->|"yes"| calm{"Flows.calm: after setup; no night, gap or buffer on;<br/>no pause; not in the 20 min before the lock;<br/>no flow recorded today"}
  calm -->|"no"| none
  calm -->|"yes"| done{"state.flows['fit-sleep'] answered or defaulted at version 1?"}
  done -->|"yes"| none
  done -->|"no: AppModel.dueFlow = fit-sleep"| slot{"Tonight's band, in order: Screen Time off, read-only, recovered, location,<br/>last night's card (until noon), then this, then the offers"}
  slot -->|"an earlier note holds it"| none
  slot -->|"the hero says Apps lock at"| card["Card: moon · Fit Dusk to your sleep · Start › · Not now<br/>render: home-fit-card"]
  card -.->|"appears"| shown[("flows['fit-sleep'] = shown, today")]
  card -->|"Not now"| notNow{"Third Not now? (flows.offers = 3)"}
  notNow -->|"no"| recNotNow[("flows['fit-sleep'] = notNow, notNow + 1")]
  notNow -->|"yes"| defaulted[("flows['fit-sleep'] = defaulted;<br/>defaults: .buffer(after, fixed 0): offered false, nothing else changes")]
  recNotNow --> later(["Back on a later day"])
  card -->|"Start"| sheet1["Sheet 1 of 3 · Fit Dusk to your sleep<br/>render: fit-sheet"]
  sheet1 -->|"Cancel, or swiped away"| later
  sheet1 -->|"Use Apple Health"| hk{{"iOS: Health access sheet (read: Sleep only)"}}
  hk -.->|"7 nights or more"| sleepFound["2 of 3 · Your sleep: found in Health"]
  hk -.->|"fewer, or refused"| sleepAsk
  sheet1 -->|"Set my hours myself"| sleepAsk["2 of 3 · Your sleep: asked, their night's hours filled in<br/>render: fit-sheet-sleep"]
  sleepFound -->|"Continue"| around
  sleepAsk -->|"Continue"| around["3 of 3 · The time around your sleep:<br/>before 30 growing to 60, or their gap where it is already 30 or more; after 15, growing to 30<br/>render: fit-sheet-around"]
  around -->|"Save"| answered[(".fit: the night's hours (held if the night is on, B-3), both buffers growing from their starts to their targets, health;<br/>flows['fit-sleep'] = answered; after.offered false")]
  answered --> tonight(["Tonight: Apps lock at …, the strip before · sleep · after"])

  classDef system stroke-dasharray: 5 3
  class hk system
```

**The defaults** leave the person's night exactly as it was: sleep is the hours they set, the buffer before is their gap (still growing or fixed, with D76's 60 as the target), and there is no buffer after. After the third "Not now" the flow never shows again; Settings › Sleep still offers everything it did.

## Doubts
- **A shown card goes at the next foreground that day.** `Flows.calm` allows one flow record a day, and showing the card records `shown`, so reopening Dusk the same afternoon hides it until tomorrow. That's #140's rule as built ("it comes back on a later day"); it may read as the card vanishing.
- **The gap offer and this flow overlap** for a person from before D76: both are about the buffer before sleep. The flow comes first in the band; answering it sets the gap and clears the offer, and putting it off for good leaves the offer for later.
- **No render shows Health found inside the sheet.** The onboarding renders (`setup-sleep-found`, `setup-sleep-weekends`) show the same screen.
