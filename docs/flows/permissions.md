# Permission loss and recovery

**What it's for:** what happens when a permission Dusk relies on is taken away in iOS Settings, how Dusk notices, what it says, and the way back. Screen Time is the one loss that stops everything, so it's the one warning that's red. Location short of Always only means the night keeps its set times anywhere. Notifications off only stops the heads-up.

**Implements:** #45 and D48 (Screen Time off is said, and Settings' row is a button), #60 (the state records whether Screen Time was allowed, so the log and night records say a night couldn't block), D8, D10 and D37 (without Always and Precise, places are ignored and blocks run on their hours), #63 (a day block can wait for Always instead), D72 (after iOS says no, Settings leaves for iOS Settings), D76 (Screen Time switched off eases the gap and holds it for 2 weeks).

**Code:** `TollFeatures/App/AppModel.swift` (`readPermissions`, `locationMode`), `AppModel+Intents.swift` (`turnOnScreenTime`), `AppModel+HeadsUp.swift`; `TollScreenTime/ScreenTimeAuthorization.swift`; `TollData/Location/LocationAccess.swift`, `PlaceMonitor.swift`; `TollData/Notifications/NotificationAdapter.swift`; `Engine.apply(.screenTime, .location)`, `Engine.isAtPlace`; `HomeSnapshot` (`screenTimeOff`, `locationBanner`).

## How Dusk notices

```mermaid
flowchart TD
  change{{"The person changes Dusk in iOS Settings, or iOS revokes it"}}
  change -.->|"Dusk next comes to the foreground"| read["AppModel.readPermissions"]
  change -.->|"location: CLLocationManager tells Dusk at once, if it's running"| read
  read --> st{"Screen Time allowed, compared with state.json?"}
  st -->|"changed"| stCmd[("state.json: screenTimeAllowed; transitions.jsonl line;<br/>off: the gap's week counts Screen Time off")]
  read --> loc{"Location now?"}
  loc -->|"Always (precise)"| places[("state.json: location places")]
  loc -->|"While Using, Approximate or Off"| scheduleOnly[("state.json: location scheduleOnly")]
  loc -->|"not asked yet"| unchanged(["No change"])
  read --> notif{"Notifications now?"}
  notif --> plan[("iOS pending heads-ups replaced by the new plan;<br/>none unless allowed (kept in memory, not stored)")]
```

The extensions can't read Screen Time's authorization or StoreKit; they log what the app last stored. Until the app runs again, a night with Screen Time off is still recorded by them as on, and the app's next `screenTime(false)` line marks it.

## Screen Time off

```mermaid
flowchart TD
  stOff(["Screen Time off for Dusk, after setup"]) --> tonight["Tonight: Screen Time is off (the state) and the note:<br/>Screen Time is off for Dusk. Nothing can be blocked. Turn on<br/>render: home-screen-time-off"]
  stOff --> settingsRow["Settings: Screen Time · Off, Turn on<br/>render: none"]
  stOff --> quiet(["No heads-up; no offers in Tonight's band;<br/>night records say screen_time_off; last night's card says so if it's back on by morning"])
  tonight -->|"Turn on"| request{{"iOS: Family Controls prompt"}}
  settingsRow -->|"Turn on"| request
  request -.->|"allowed"| back[("state.json: screenTimeAllowed; the next wake shields again")]
  request -.->|"not allowed, or iOS won't ask again"| iosSettings{{"iOS Settings"}}
  iosSettings -.->|"allowed there; back in Dusk"| back
  back --> normal["Tonight as before<br/>render: home-evening"]
```

## Location short of Always

```mermaid
flowchart TD
  downgraded(["Location set to While Using, Approximate or Off"]) --> hasPlace{"The night has a place (home set)?"}
  hasPlace -->|"no"| nothing(["Nothing changes: the night already runs anywhere"])
  hasPlace -->|"yes"| note["Tonight: Anywhere · starts in …, and the location note: Change in Settings<br/>render: home-location"]
  downgraded --> settingsLoc["Settings: Location · While Using, leaves for iOS Settings<br/>render: settings-while-using"]
  downgraded --> dayBlocks{"Another block at a place?"}
  dayBlocks -->|"set to wait for Always"| waits(["It stays off until Always; its editor says so"])
  dayBlocks -->|"otherwise"| runsAnywhere(["It runs on its hours anywhere; its editor says so under Place<br/>render: none"])
  note -->|"Change in Settings"| iosLoc{{"iOS Settings: Dusk › Location › Always, Precise"}}
  settingsLoc -->|"tap"| iosLoc
  iosLoc -.->|"Always and Precise"| places[("state.json: location places;<br/>CLMonitor events relaunch Dusk again")]
  places --> home["Tonight: At home · starts in …<br/>render: home-evening"]

  classDef system stroke-dasharray: 5 3
  class iosLoc system
```

## Notifications off

```mermaid
flowchart TD
  notifOff(["Notifications for Dusk off in iOS Settings"]) -.->|"next foreground"| cleared{{"iOS pending heads-ups: all removed"}}
  notifOff --> row["Settings: Heads-up · Off in iOS Settings, Open Settings<br/>render: settings-heads-up-denied"]
  row -->|"Open Settings"| iosN{{"iOS Settings: Dusk › Notifications"}}
  iosN -.->|"allowed; back in Dusk"| rescheduled{{"iOS pending heads-ups: the next 7 nights"}}
  notifOff --> noCard(["Tonight's heads-up card never shows after iOS has answered"])

  classDef system stroke-dasharray: 5 3
  class cleared,iosN,rescheduled system
```

## Doubts
- **What iOS does to the shield and the DeviceActivity schedules when Screen Time is revoked** isn't in the code; the engine keeps its blocks "on" and the snapshot says nothing can block. `docs/device-protocol.md` is where the device answer belongs.
- **Screen Time off with the free nights over:** the Off state wins over the Screen Time state, but the red note still shows (see [tonight.md](tonight.md)).
- **Nothing asks for location at launch.** The place watch and its Always session open only once Dusk has Always (D98); opened earlier, iOS shows the location prompt over Welcome.
- **Location changed while Dusk isn't running** is only seen at the next foreground; until then the monitor still decides with the stored mode. With Always gone, region events no longer relaunch Dusk, so presence goes stale rather than wrong.
- **Precise off with Always on** reads as `approximate` (`LocationAccess.state`), which is `scheduleOnly`: places are ignored, as D8 says.
