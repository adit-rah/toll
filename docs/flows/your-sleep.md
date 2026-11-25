# Your sleep, the sky and landmarks

**What it's for:** the second tab. It opens onto the person's sky, where each night the lock ran is one star, in a fixed order that completes real constellations. Under it, this week as seven dots, a personal best when there is one, and the hours locked over 7 days, 30 days or all time. At 7, 30, 100 and 365 nights a landmark morning offers the sky as a picture to share; nothing leaves the phone otherwise.

**Implements:** D63 (the tab), D65 (true numbers, no shortfall), D69 (the week, "A new week", personal bests), D79 and D81 (the sky, landmarks, sharing only at landmarks), D82 (the free nights frozen after the trial), D84 (every range reads the night records), D88 (the full-bleed sky, its light by the phone's hour, a star's night in a popover, the newest star's arrival).

**Code:** `TollCore/App/YourSleep.swift`, `PastNight.swift` (`merged`, `NightsRan`), `InsightsSnapshot.swift`, `Sky.swift`, `SkyCatalogue.swift`, `SkyStars.swift`, `SkyLayout.swift`, `SkyArt.swift`; `TollFeatures/Insights/` (`InsightsView`, `SkyHeader`, `SkyScene`, `SkyStarsLayer`, `SkyBackdrop`, `SkyPoster`, `SleepCards`); `Home/LandmarkLine.swift`; `AppModel.recordNights`.

> **Being reworked:** the sky's names are being changed on another branch at the time of writing. The chart is `main`'s; the flow should not change, only the words.

```mermaid
flowchart TD
  foreground(["Each foreground"]) --> record[("nights.jsonl: one line per ended night not yet recorded<br/>(built from transitions.jsonl)")]
  record --> merge["Nights: the records, plus the log's nights not recorded yet; a record wins"]
  tab(["The Your sleep tab"]) --> merge
  merge --> anyRan{"Any night the lock ran?"}
  anyRan -->|"no"| emptySky["Your sky, empty: dust, the Milky Way, the moon, the land;<br/>Your first star comes with your first locked night.<br/>render: sleep-sky-0"]
  anyRan -->|"yes"| sky["Your sky: one star per night locked, completed figures named;<br/>N nights locked on the land<br/>render: sleep-sky-5, sleep-sky-30, sleep-sky-100"]
  sky --> light{"The phone's hour when the tab opens?"}
  light -->|"from 4 pm"| evening(["Evening light<br/>render: sleep-sky-evening"])
  light -->|"from 9 pm"| night(["Night light<br/>render: sleep-sky-night"])
  light -->|"from 5 am"| morningLight(["Morning light<br/>render: sleep-sky-morning"])
  sky --> newest{"More nights than this phone last showed?<br/>(UserDefaults dusk.sky.seen)"}
  newest -->|"yes"| arrives["The newest star brightens, then its lines draw, once;<br/>a 200 ms crossfade with Reduce Motion"]
  arrives --> seen[("UserDefaults: dusk.sky.seen = nights")]
  newest -->|"no"| still(["Drawn as it was"])
  sky -->|"tap within 22 pt of a lit star"| starNight["A popover (a sheet at accessibility sizes): the night's date,<br/>Locked 10:15 pm – 7:00 am<br/>render: sleep-sky-star"]
  sky -.->|"past 150 nights: the stars light again, brighter"| secondPass["render: sleep-sky-180"]
  sky --> landmarkCheck{"The newest night was a landmark (7, 30, 100, 365),<br/>and the next night hasn't started?"}
  landmarkCheck -->|"yes"| shareButton["Share beside the count<br/>render: sleep-sky-30"]
  shareButton -->|"Share"| shareSheet{{"iOS share sheet: the 1080 × 1920 poster, made on the phone<br/>render: sky-share"}}

  merge --> week{"Where in the week?"}
  week -->|"Monday night to Sunday night"| thisWeek["This week: seven dots<br/>render: insights"]
  week -->|"Sunday's night ended, Monday's not started"| newWeek["A new week: N nights last week over seven empty dots<br/>render: sleep-monday"]
  week -->|"the free nights over, not bought"| freeNights["Your free nights: two rows of seven<br/>render: none"]
  thisWeek --> best{"This week beats every earlier week?"}
  best -->|"yes"| bestCard["N nights this week · Your most in a week<br/>render: sleep-best"]
  merge --> ranges["Over time: 7 days, 30 days, All time; hours locked;<br/>when you chose sleep, by hour, if any taps<br/>render: insights"]
  ranges -->|"segmented control"| ranges

  tonightMorning["Last night's card on Tonight on a landmark: the completed shape,<br/>30 nights. Orion is in your sky., Share<br/>render: home-morning-landmark"]
  tonightMorning -->|"Share"| shareSheet

  classDef system stroke-dasharray: 5 3
  class shareSheet system
```

## What the sky is made of
Nothing about the sky is stored. It is worked out each time from the nights the lock ran (`NightsRan`: the night records, the transition log and the state together) and the fixed order in `SkyCatalogue`. The only thing kept is how many nights this phone last showed (`dusk.sky.seen`), so the newest star arrives once. See `data.md`.

## Doubts
- **Nights reach the records only on foreground.** Until Dusk is opened, the log's nights fill in; if Dusk isn't opened for long enough that the log is trimmed past a night before it's recorded, that night's star never comes. See `data.md`, risk 3.
- **Changing the catalogue's order, or the rule for a night that ran, redraws every person's sky** and moves which star belongs to which night (`YourSleep.starNight` is positional). Nothing records the order a person's stars were lit in.
- **A landmark's Share on Tonight and on Your sleep both last until the next night starts:** Your sleep while the newest star is new (`Sky.isNew`), Tonight in last night's card, which floats until noon and then opens from the strip's start.
- **The free nights' frozen dots** have no render.
