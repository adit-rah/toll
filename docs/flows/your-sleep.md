# Your sleep, the sky and landmarks

**What it's for:** the second tab. It opens onto the person's sky, where each night the lock ran is one star, in a fixed order that completes real constellations. Under it, how the person's nights are changing (#88): when they fell asleep, how long, how steady, and how often they reached for a locked app, each against their own first nights, from Health's sleep or, without it, Dusk's own nights. Then Apple's own count of screen time after bed last night (#65), then this week as seven dots, a personal best when there is one, and the hours locked over 7 days, 30 days or all time. At 7, 30, 100 and 365 nights a landmark morning offers the sky as a picture to share; nothing leaves the phone otherwise.

**Implements:** D63 (the tab), D65 (true numbers, no shortfall), D69 (the week, "A new week", personal bests), D79 and D81 (the sky, landmarks, sharing only at landmarks), D82 (the free nights frozen after the trial), D84 (every range reads the night records), D88 (the full-bleed sky, its light by the phone's hour, a star's night in a popover, the newest star's arrival), #87 and #88 (the measures and their trends), #65 (Apple's screen time after bed, its own row).

**Code:** `TollCore/App/YourSleep.swift`, `SleepTrends.swift` (the measures, `TollConfig.trends`), `PastNight.swift` (`merged`, `NightsRan`), `InsightsSnapshot.swift`, `Sky.swift`, `SkyCatalogue.swift`, `SkyStars.swift`, `SkyLayout.swift`, `SkyArt.swift`; `TollFeatures/Insights/` (`InsightsView`, `TrendCards`, `TrendChart`, `SkyHeader`, `SkyScene`, `SkyStarsLayer`, `SkyBackdrop`, `SkyPoster`, `SleepCards`); `Home/LandmarkLine.swift`; `AfterBed/AfterBedRow.swift` and `TollCore/App/AfterBed.swift` (last night for Apple's report), `ios/Report/` (the report extension); `AppModel.recordNights`.

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

  merge --> source{"Health's sleep on 3 or more of the last 7 nights?"}
  source -->|"yes"| healthMeasures["Night by night: Asleep by, Time asleep, How steady, Reaching for your phone<br/>render: sleep-health-improving, sleep-health-flat, sleep-health-noisy"]
  source -->|"no, Health chosen"| healthEmpty["Dusk's stand-ins: Phone down by, Nights locked, How steady, Reaching for your phone;<br/>Health has no sleep for these nights. A watch adds real sleep times.<br/>render: none"]
  source -->|"no, Health not chosen"| duskMeasures["The same stand-ins; From Dusk's own nights, not measured sleep;<br/>Add your sleep from Apple Health<br/>render: sleep-dusk"]
  duskMeasures -->|"Add your sleep from Apple Health"| healthSheet{{"iOS: Health's read access, sleep only"}}
  healthSheet -.->|"whatever iOS answers"| healthChosen[("state.json: health = true; recent records corrected")]
  healthMeasures --> enough{"For each measure: 3 or more values in the last 7 nights<br/>(How steady: 7 in the last 14)?"}
  healthEmpty --> enough
  duskMeasures --> enough
  enough -->|"no measure has"| noMeasures["How your nights change shows here after a few nights."]
  enough -->|"yes"| measureCard["Its value, the last 14 nights as dots or bars"]
  measureCard --> compare{"7 first nights (14 for How steady) and 5 recent ones after them?"}
  compare -->|"no"| noCompare(["No comparison: render: sleep-few"])
  compare -->|"yes"| clears{"The change clears the floor and 2.2 standard errors?"}
  clears -->|"yes, the way it improves"| toward["arrow.up.right: 25 min earlier than your first 7 nights"]
  clears -->|"yes, the other way"| awayWay["arrow.down.right: 20 min later than your first 7 nights"]
  clears -->|"no"| same["equal: About the same as your first 7 nights"]
  measureCard -.-> afterBed["Under the measures, with Screen Time on and a night ended: Screen time after bed,<br/>Last night, from Screen Time, and Apple's number, drawn by the report extension; Dusk never reads it<br/>render: insights (a placeholder bar where the number goes)"]
  noMeasures -.-> afterBed
  merge --> week{"Where in the week?"}
  week -->|"Monday night to Sunday night"| thisWeek["This week: seven dots<br/>render: insights"]
  week -->|"Sunday's night ended, Monday's not started"| newWeek["A new week: N nights last week over seven empty dots<br/>render: sleep-monday"]
  week -->|"the free nights over, not bought"| freeNights["Your free nights: two rows of seven<br/>render: none"]
  thisWeek --> best{"This week beats every earlier week?"}
  best -->|"yes"| bestCard["N nights this week · Your most in a week<br/>render: sleep-best"]
  merge --> ranges["Over time: 7 days, 30 days, All time; hours locked;<br/>when you chose sleep, by hour, if any taps<br/>render: insights"]
  ranges -->|"segmented control"| ranges

  tonightMorning["Last night's card on Tonight on a landmark: the completed shape under last night's moon,<br/>30 nights. Orion is in your sky., Share<br/>render: home-morning-landmark"]
  tonightMorning -->|"Share"| shareSheet

  classDef system stroke-dasharray: 5 3
  class shareSheet,healthSheet system
```

## What the sky is made of
Nothing about the sky is stored. It is worked out each time from the nights the lock ran (`NightsRan`: the night records, the transition log and the state together) and the fixed order in `SkyCatalogue`. The only thing kept is how many nights this phone last showed (`dusk.sky.seen`), so the newest star arrives once. See `data.md`.

## Doubts
- **The measures are only as true as their nights.** Without Health, "Phone down by" is the last reach for a locked app, which says nothing on a night with no reach and hasn't been checked against measured sleep; it is named as Dusk's own and never as sleep. The first nights are the first seven with a value since setup, not Health's history before Dusk.
- **The sleep model's one causal line** ("when the lock started earlier, you were asleep N minutes sooner", D66) isn't shown: no model chooses the start yet, so it never fires. It belongs beside these measures once personal timing is on.
- **Nights reach the records only on foreground.** Until Dusk is opened, the log's nights fill in; if Dusk isn't opened for long enough that the log is trimmed past a night before it's recorded, that night's star never comes. See `data.md`, risk 3.
- **Changing the catalogue's order, or the rule for a night that ran, redraws every person's sky** and moves which star belongs to which night (`YourSleep.starNight` is positional). Nothing records the order a person's stars were lit in.
- **A landmark's Share on Tonight and on Your sleep both last until the next night starts:** Your sleep while the newest star is new (`Sky.isNew`), Tonight in last night's card, which floats until noon and then opens from the strip's start.
- **The free nights' frozen dots:** `sleep-after-trial` (#129).
