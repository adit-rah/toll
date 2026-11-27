# One-time flow #1: Fit Dusk to your sleep

**What it's for:** people set up before #144 have a night but no buffer after waking, no target of their own for the buffer before sleep, and were never asked about Apple Health. Schema 4's migration step keeps their night exactly as it was; this flow offers them, once, onboarding's steps 2 to 4 (Fit Dusk to your sleep, Your sleep, The time around your sleep) in a sheet, starting from their own night and gap.

**Implements:** #144 (the flow), #140 and D92 (the registry, its calm moments and "Not now"), D86, D91 and D94 (Tonight's band, `TonightBand`), D76 (the weekly rule, now both sides).

**Code:** `TollCore/App/Flows.swift` (`Flows.fitSleep`, `due`, `calm`, `record`), `Persist/Migration.swift` (`v3to4`), `App/Fit.swift` (`Fit.existing`, `Fit.apply`), `Domain/BufferSuggestion.swift`, `Domain/BufferNight.swift`, `Persist/NightHistory.swift` (`NightLog.buffers`); `TollFeatures/Setup/FitFlowSheet.swift`, `FitView.swift` (`FitChoice`), `SleepTimesView.swift`, `AroundView.swift`, `FitDraft.swift`; `Home/HomeView.swift` (`HomeNote.flow`), `Home/TonightCardView.swift` (`BandCard`); `App/RootView.swift`, `AppModel.foreground` (`dueFlow`), `AppModel+Intents.swift` (`flow`).

**Applies** (`applies`): `setupFinishedAt` is set and `after.offered` is true. The 3 → 4 step sets `after.offered` for every file it migrates (and `Migration.fromV1` for schema 1); a new install's `finishSetup` never does. Version 1.

```mermaid
flowchart TD
  migrate[("state.json read at schema 3 or older: step 3 → 4<br/>gap.target 60, after = 0 fixed and offered, health false")] --> fg(["Dusk comes to the foreground"])
  fg --> applies{"Flows.fitSleep.applies:<br/>set up, after.offered?"}
  applies -->|"no"| none(["No card; Tonight as usual"])
  applies -->|"yes"| shownToday{"Flows.shownToday: this flow shown today,<br/>not answered or put off?"}
  shownToday -->|"yes: it stays offered all day"| calmToday{"Flows.calm, besides its own record:<br/>no night, buffer or pause; not in the hour before the lock"}
  calmToday -->|"yes"| slot
  calmToday -->|"no"| none
  shownToday -->|"no"| calm{"Flows.calm: after setup; no night, gap or buffer on;<br/>no pause; not in the hour before the lock (band.nightMinutes);<br/>no flow recorded today (one flow a day)"}
  calm -->|"no"| none
  calm -->|"yes"| done{"state.flows['fit-sleep'] answered or defaulted at version 1?"}
  done -->|"yes"| none
  done -->|"no: Flows.due = fit-sleep, read with the clock (RootView → HomeSnapshot flow:)"| slot{"TonightBand (tonight.md): a problem or a night card wins;<br/>else this, before any offer; last night's row may sit under it"}
  slot -->|"a problem or a night card holds it"| none
  slot -->|"its turn"| card["Card: moon · Fit Dusk to your sleep · Start › · Not now<br/>render: home-fit-card, home-morning-flow"]
  card -.->|"appears"| shown[("flows['fit-sleep'] = shown, today: offered again at every foreground today")]
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
  sleepAsk -->|"Continue"| around["3 of 3 · The time around your sleep:<br/>before 30 growing to 60, or their gap where it is already 30 or more; after 15, growing to 30;<br/>'Recommended to start.'<br/>with 4 or more judged weeks on a side (BufferSuggestion, #145): that side's target fitted from them,<br/>a fitted target holds over a longer gap; 'Fitted to your nights so far.'<br/>render: fit-sheet-around, fit-sheet-around-fitted"]
  around -->|"Save"| answered[(".fit: the night's hours (held if the night is on, B-3), both buffers growing from their starts to their targets, health;<br/>flows['fit-sleep'] = answered; after.offered false")]
  answered --> tonight(["Tonight: Apps lock at …, the strip before · sleep · after"])

  classDef system stroke-dasharray: 5 3
  class hk system
```

**The defaults** leave the person's night exactly as it was: sleep is the hours they set, the buffer before is their gap (still growing or fixed, with D76's 60 as the target), and there is no buffer after. After the third "Not now" the flow never shows again; Settings › Sleep still offers everything it did.

## Doubts
- **One flow a day, offered all day** (fixed in this branch): `Flows.due` keeps a flow shown today offered at every calm foreground that day, until it is answered or put off; `calm` still lets no second flow start that day (`FlowTests.theFlowOfferedTodayStaysAllDay`).
- **The gap offer and this flow overlap** for a person from before D76: both are about the buffer before sleep. The flow comes first in the band; answering it sets the gap and clears the offer, and putting it off for good leaves the offer for later.
- **No render shows Health found inside the sheet.** The onboarding renders (`setup-sleep-found`, `setup-sleep-weekends`) show the same screen.
