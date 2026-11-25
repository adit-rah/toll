# Only when I'm home

**What it's for:** after the first night, letting the night wait until the phone is home. It is the one place Dusk asks for location: While Using on the map, then Always once. Short of Always and Precise, home is still saved and the night keeps its set times wherever the phone is. Once home is set, the same sheet offers the way back, "Use anywhere".

**Implements:** D68 and D71 (offered after the first night, saved once at the end), D84 (one home picker from Tonight, Settings and the night's editor; "Use anywhere"), D8, D10 and D37 (without Always and Precise, the night runs on its hours), B-3 (a change during the night waits until it ends).

**Code:** `TollFeatures/Setup/SetHomeFlow.swift`, `SetHomeModel.swift`, `HomeMapView.swift`, `PermissionsView.swift` (`LocationView`, `AlwaysView`, `LocationOffView`); `Engine+Home.swift` (`setHome`, `useAnywhere`); `TonightCard.home`; `AppModel.readPermissions` and `locationMode`.

```mermaid
flowchart TD
  card["Tonight: Only when I'm home? card<br/>render: home-card"]
  settingsRow["Settings: Only when I'm home row<br/>render: settings-anywhere"]
  nightEditor["Your nights editor: Place row<br/>render: block-night"]
  card -->|"Not now"| dismissed[("state.json: dismissedCards gets home; the card never returns")]
  card -->|"Set home"| sheetOpen
  settingsRow -->|"tap"| sheetOpen
  nightEditor -->|"tap Place"| sheetOpen
  sheetOpen(["The sheet opens on the map"]) --> homeSet{"Home already set<br/>(a held edit counts)?"}
  homeSet -->|"yes: the map opens on it"| mapSet["Where do you sleep? with Use anywhere<br/>render: set-home-set"]
  homeSet -->|"no"| locNow{"Location permission now?"}

  locNow -->|"not asked"| whileUsingPrompt{{"iOS: While Using prompt, over the map"}}
  whileUsingPrompt -.->|"answered"| locNow
  locNow -->|"While Using or Always"| finding["Where do you sleep? Finding where you are…<br/>render: set-home"]
  locNow -->|"off or approximate"| mapOff["Map without a circle: Open Settings, Not now<br/>render: set-home-off"]
  mapOff -->|"Open Settings"| iosSettings{{"iOS Settings: Dusk › Location"}}
  mapOff -->|"Not now"| cancelled(["Sheet closes; nothing saved"])
  finding -.->|"a fix"| map["The map with home drawn as a circle<br/>render: set-home"]
  finding -.->|"no exact fix"| noFix["No exact location yet: Try again<br/>render: none"]
  noFix -->|"Try again"| finding
  map -->|"Move, drag, Done"| map
  map -->|"Cancel"| cancelled
  mapSet -->|"Cancel"| cancelled

  map -->|"This is home"| hasAlways{"Always already?"}
  mapSet -->|"This is home"| hasAlways
  hasAlways -->|"yes"| saveHome
  hasAlways -->|"no"| allowLoc["Allow location<br/>render: set-home-location"]
  allowLoc -->|"Allow, While Using not asked"| whileUsingPrompt2{{"iOS: While Using prompt"}}
  allowLoc -->|"Allow, While Using, Always not asked yet"| alwaysPrompt{{"iOS: Change to Always Allow prompt<br/>(asked once: UserDefaults askedAlways)"}}
  whileUsingPrompt2 -.-> allowLoc
  alwaysPrompt -.-> allowLoc
  allowLoc -->|"Continue, once settled"| afterLoc{"Location now?"}
  afterLoc -->|"Always"| saveHome
  afterLoc -->|"While Using"| chooseAlways["Choose Always<br/>render: set-home-always"]
  afterLoc -->|"approximate, off or not asked"| locOff["Your night keeps its set times<br/>render: set-home-location-off"]
  chooseAlways -->|"Open Settings"| iosSettings2{{"iOS Settings: Dusk › Location"}}
  iosSettings2 --> saveHome
  chooseAlways -->|"Not now. Use the set times."| saveHome
  locOff -->|"Change in Settings"| iosSettings2
  locOff -->|"Continue"| saveHome

  saveHome[("Command.setHome: Home place and the night's place<br/>state.json; held until the night ends if it is on (B-3)")]
  saveHome --> watch[("CLMonitor 'places' watches Home")]
  watch --> mode{"Always and Precise?"}
  mode -->|"yes"| homeNight["Tonight: At home · starts in …, or Night ends at … while away<br/>render: home-evening, home-away"]
  mode -->|"no"| locNote["Tonight: the location note, Change in Settings<br/>render: home-location"]

  mapSet -->|"Use anywhere"| anywhere[("Command.useAnywhere: the night's place cleared; Home kept<br/>held until the night ends if it is on")]
  mapOff -->|"Use anywhere, when home is set"| anywhere
  anywhere --> anywhereNight["Tonight: Anywhere · starts in …<br/>render: home-anywhere"]

  classDef system stroke-dasharray: 5 3
  class whileUsingPrompt,whileUsingPrompt2,alwaysPrompt,iosSettings,iosSettings2 system
```

The night's editor reads the saved place back when the sheet closes (`BlockEditorModel.homeChanged`), so its own Save doesn't undo the sheet's change. Settings' row reads "On from 7:00 am" or "Off from 7:00 am" while a change is held (`DuskState.homeChangeAt`).

## When the card shows
The home card is one of Tonight's offers ([tonight.md](tonight.md), Tonight's band): no problem showing, the free nights not over, nothing blocking, not in the hour before the lock, a night ended since setup, no gap card or flow due, home not set and the card not put away. Last night's row may sit under it in the morning.

## Doubts
- **"Open Settings" on Choose Always saves home at once** and closes the sheet while the person is still in iOS Settings. That is the code (`AlwaysView` calls `openSystemSettings()` then `finish()`), and it means the result of the Settings visit is only seen as Tonight's location note or its absence.
- **No render shows the map without a fix** ("No exact location yet") or the Allow screen after While Using was given.
- **"Not now" on the blocked map** shows only when home isn't set; with home set, the blocked map offers "Use anywhere" instead, so the only way out without changing anything is the toolbar's Cancel.
