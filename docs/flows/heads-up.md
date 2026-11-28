# The heads-up before the night

**What it's for:** one quiet local notification 20 minutes before the apps lock, so the lock never comes as a surprise. It is Dusk's only notification. Permission is asked after the first night, from Tonight's card or Settings, never in onboarding.

**Implements:** D68 and D72 (one heads-up, asked after the first night, Settings can switch it off), D83 (it comes 20 minutes before the lock, not before bed), #127 (Monday's change moves it with Dusk closed), D65 (banners only: no sound, no badge).

**Code:** `TollCore/App/HeadsUp.swift` (who gets one and when), `TonightCard.headsUp`, `TollFeatures/App/AppModel+HeadsUp.swift`, `Settings/HeadsUpRow.swift`, `TollData/Notifications/NotificationAdapter.swift` (asks iOS), `TollScreenTime/HeadsUpNotifications.swift` (hands iOS the plan, from the app and the monitor), `TollCore/App/WeekTurn.swift`.

```mermaid
flowchart TD
  firstNight(["A night has ended since setup"]) --> cardCheck{"Tonight's band: no problem, free nights not over, nothing blocking,<br/>more than an hour before the lock, no gap card, flow or home card first,<br/>iOS not asked, card not put away?"}
  cardCheck -->|"yes"| card["Tonight: A heads-up before your night? with a bell and the time it would come<br/>render: home-heads-up"]
  cardCheck -->|"no"| noCard(["No card; Settings still has the switch"])
  card -->|"Not now"| putAway[("state.json: dismissedCards gets headsUp")]
  card -->|"Turn on"| switchOn[("state.json: headsUp on")]
  card -.->|"Turn on, once iOS has answered"| answer{"iOS allows it?"}
  answer -->|"yes"| answerOn["In the card's place, once: Heads-up on, the time it comes, OK<br/>render: home-heads-up-on"]
  answer -->|"no"| answerOff["In the card's place, once: Notifications are off for Dusk, Open Settings, OK<br/>render: home-heads-up-denied"]
  answerOff -->|"Open Settings"| iosSettings
  answerOn -->|"OK, or the app goes to the background"| gone(["Gone for good: it's held in memory only"])
  answerOff -->|"OK, or the app goes to the background"| gone

  settingsRow["Settings: Heads-up switch<br/>render: settings"]
  settingsRow -->|"switch on"| switchOn
  settingsRow -->|"switch off"| switchOff[("state.json: headsUp off")]
  deniedRow["Settings: Heads-up, Off in iOS Settings<br/>render: settings-heads-up-denied"]
  deniedRow -->|"Open Settings"| iosSettings{{"iOS Settings: Dusk › Notifications"}}

  switchOn --> asked{"iOS asked before?"}
  asked -->|"no"| prompt{{"iOS: notifications prompt (alerts only)"}}
  asked -->|"yes"| plan
  prompt -.->|"Allow or Don't Allow"| plan
  switchOff --> plan
  iosSettings -.->|"back in Dusk: foreground reads the answer"| plan

  plan{"For each of the next 7 nights: set up, the night's block on,<br/>Screen Time allowed, free or bought that night,<br/>switch on, iOS allows?"}
  plan -->|"those nights"| pending{{"iOS pending notifications: all replaced<br/>headsUp-epoch, 20 min before each lock"}}
  plan -->|"none"| cleared{{"iOS pending notifications: all removed"}}
  turn(["Monday's turn: the monitor's wake at 12:01 changed a buffer (#127)"]) -.-> turnPlan{"Switch on, and iOS allows notifications?"}
  turnPlan -->|"yes: the same plan, from the monitor"| pending
  turnPlan -->|"no"| turnNothing(["Nothing handed to iOS"])
  pending -.->|"20 min before the lock"| banner{{"Banner: Apps lock in 20 min, with the night's hours"}}
  banner -->|"tap"| tonight["Tonight: Apps lock at …<br/>render: home-evening"]

  classDef system stroke-dasharray: 5 3
  class prompt,iosSettings,pending,cleared,banner system
```

**When the plan is handed to iOS again:** on Monday, by the monitor at the week's turn when a buffer changed, so that night's heads-up moves with the lock while Dusk stays closed (#127); after every command the app sends, at launch and on every foreground (the plan is forgotten first, so it always goes again), and when the app's 20-second refresh sees a state the monitor wrote (a held edit applied at the end of a night). Only a plan that differs from the last one is handed over.

## Doubts
- **A heads-up already handed to iOS still arrives** if Screen Time is switched off, the night's block is switched off by another route, or a refund lands while Dusk stays closed: the extensions can't schedule (D72's open point).
- **The monitor's plan needs iOS's answer within 2 seconds** (`HeadsUpNotifications.replaceIfAllowed`); if iOS is slower, the old plan stays and Monday's heads-up comes at last week's time. A device row checks it.
- **The card's time** comes from `HeadsUp.nights(...).first`, which skips a night whose heads-up time has passed. The card never shows in the hour before the lock (Tonight's band), so it names tonight's whenever it shows on a day with a night.
