# Before bed: the gap and its helpers

**What it's for:** the apps lock a little before bed, and that gap grows with the person, week by week, unless they fix it. During the gap Tonight offers three small helpers for the minutes until bed. This chart covers how the gap is set (a new install, the one offer to an install from before it, Monday's card, Settings) and the helpers.

**Implements:** D76, D77 and D83 (the gap, its weekly rule, Monday's card, the offer to older installs), D80 and D85 (the helpers, their card and capsule, Settings' switch), B-3 (a gap changed during the night waits until it ends; the helpers' switch applies at once).

**Code:** `TollCore/App/GapRules.swift`, `GapSnapshot.swift`, `Domain/Gap.swift`, `TonightCard` (`gapWeek`, `gapOffer`, `beforeBed`), `HomeSnapshot.untilBed`; `TollFeatures/App/AppModel+Gap.swift`, `AppModel+Helpers.swift`, `Settings/BeforeBedRow.swift`, `BeforeBed/HelpersSheet.swift`, `TollData/Audio/BreathTone.swift`.

## The gap

```mermaid
flowchart TD
  newInstall(["Onboarding's Done"]) --> grows15[("state.json: gap 15 min, grows")]
  olderInstall(["A state file from before the gap"]) --> existing[("state.json: gap 0, fixed, offered")]
  existing --> offerCheck{"Tonight's band free for an offer<br/>(see tonight.md)?"}
  offerCheck -->|"yes"| offerCard["Tonight: Lock apps 15 min before bed? with the lock and wake times<br/>render: home-gap-offer"]
  offerCard -->|"Turn on"| setGap
  offerCard -->|"Not now"| offerGone[("state.json: offered off; the card never returns")]

  monday(["The first wake on or after Monday noon:<br/>the app, the monitor or the block screen"]) --> judge{"Grows, and last week's tally says?"}
  judge -->|"smooth week: +15, up to 60"| changed[("state.json: gap.change for this week")]
  judge -->|"hard week, or Screen Time switched off: −15"| changed
  judge -->|"anything else, or a fixed gap"| hold(["No change; no card"])
  changed --> weekCard{"Still Monday's night (until Tuesday noon),<br/>nothing blocking, no warning, free nights not over?"}
  weekCard -->|"yes"| gapWeek["Tonight: This week, apps lock 30 min before bed · Up from 15<br/>render: home-gap-week"]
  gapWeek -->|"Keep 15 (only after a rise)"| setGap
  gapWeek -->|"OK"| seen[("state.json: change seen")]

  settings["Settings: Before bed row<br/>render: settings"]
  settings -->|"tap"| sheet["Before bed sheet: Grows with you, or a fixed gap 0–90 min;<br/>the helpers' switch and the breath's length<br/>render: settings-before-bed"]
  sheet -->|"swipe down"| unchanged(["Nothing changes"])
  sheet -->|"Done"| setGap
  sheet -->|"Done"| helpersNow[("state.json: helpers on or off, breath minutes; at once")]

  setGap{"The night's block on now?"}
  setGap -->|"no"| applyNow[("state.json: gap in force now")]
  setGap -->|"yes"| held[("state.json: gap.pending; applied when the night ends (B-3)")]
  applyNow --> lockMoves["Tonight: Apps lock at … · N min before bed;<br/>the strip's lower step before the moon; heads-up moves<br/>render: home-evening"]
  held -.->|"the night ends: the monitor or the app reconciles"| applyNow
```

## The helpers in the gap

```mermaid
flowchart TD
  lock(["The lock starts: bed minus the gap"]) --> inGap{"The night locked, not paused, before bed,<br/>helpers on?"}
  inGap -->|"no"| plain["Tonight: Apps locked until …<br/>render: home-blocked"]
  inGap -->|"yes"| capsule["Tonight: a grey Before bed capsule under the pauses<br/>render: home-before-bed"]
  capsule --> cardCheck{"No warning, and the card not answered before?"}
  cardCheck -->|"yes"| card["Tonight: Something for the next N minutes?<br/>render: home-before-bed-card"]
  card -->|"Not now"| answered[("state.json: dismissedCards gets beforeBed")]
  card -->|"Show me"| answeredOpen[("state.json: dismissedCards gets beforeBed")]
  answeredOpen --> choices
  capsule -->|"Before bed"| choices
  choices["Pick one. Each ends with the phone down.<br/>render: before-bed"]
  choices -->|"Not now"| closed(["Sheet closes"])
  choices -->|"Write tomorrow's list"| listPage["The list, on paper<br/>render: before-bed-list"]
  choices -->|"Breathe for 3 minutes"| breathePage["Breathe: the tone plays, Stop<br/>render: before-bed-breathe"]
  choices -->|"Try this in bed"| wordsPage["The word game<br/>render: before-bed-words"]
  listPage --> logged[("transitions.jsonl: helperList, helperBreathe or helperWords;<br/>the night record's private helper field")]
  breathePage --> logged
  wordsPage --> logged
  breathePage -.->|"the tone: AVAudioEngine, keeps playing when locked, fades at the end;<br/>a call, an alarm or headphones out stop it"| tone{{"iOS audio session"}}
  listPage -->|"Something else"| choices
  breathePage -->|"Something else"| choices
  wordsPage -->|"Something else"| choices
  listPage -->|"Done"| closed
  breathePage -->|"Done"| closed
  wordsPage -->|"Done"| closed
  plain -.->|"bed comes: the capsule goes"| plain

  classDef system stroke-dasharray: 5 3
  class tone system
```

## Doubts
- **Monday's card can be missed.** It shows only between Monday noon and Tuesday noon, and only while nothing blocks, so a person who opens Dusk only inside a long Study block that day never sees it; the change still applies. That matches D76's "this week's gap" but isn't stated anywhere.
- **The offer to older installs** has no "seen" flag beyond `offered`; "Turn on" and "Not now" both clear it (`GapRules.set` clears it too), so changing the gap in Settings also removes the offer. Matches the code; D83 doesn't say.
- **Settings' Done sends the gap even when unchanged.** `setBeforeBed` always sends `.gap(...)`; during the night that stores a pending gap equal to the current one. Harmless, but it makes Settings say a change is waiting when nothing changed (worth a check on device).
- **A pause in the gap** shows "Paused until"; the capsule hides while paused (`untilBed` needs the blocked hero) and returns if the pause ends before bed.
