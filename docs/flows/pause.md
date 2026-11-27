# The pause

**What it's for:** the one way out while apps are locked. A 60-second wait that costs nothing to cancel, then every block's shield lifts for 10 minutes and comes back by itself. Three a week, shared by every block, back to three when Monday's night starts at noon. "Lock again" in the first 2 minutes gives the pause back. The code keeps the spec's names (`Door`, `Unlock`); people see "Pause".

**Implements:** D67 and D70 (the pause), D-3 (a free wait), D-4 (the 2-minute regret), D-7 (one at a time), D31 (the DeviceActivity warning is the timer), D32 and D84 (the block screen's buttons and words), D47 (no dead ends), D75 (the sheet can be swiped away; Tonight shows the paused state), D76 (a pause asked for before bed counts against the gap's week), D87 (the sheet keeps one height).

**Code:** `TollCore/App/DoorRules.swift`, `Domain/Door.swift` (`Door`, `UnlockSupply`), `App/ShieldText.swift`; `ios/ShieldAction/ShieldActionExtension.swift`, `ios/ShieldConfig/ShieldConfigurationExtension.swift`, `ios/Monitor/DeviceActivityMonitorExtension.swift`; `TollScreenTime/ScheduleAdapter.swift` (`startDoor`); `TollFeatures/Door/DoorSheet.swift`, `DoorParts.swift`; `AppModel+Intents.swift` (`showsDoor`, `doorPending`, `askDoor`, `startDoor`, `cancelDoor`, `lockDoor`, `dismissDoor`); `RootView.LiveHome` (the sheet).

```mermaid
flowchart TD
  shieldScreen{{"The block screen (ShieldConfig): Blocked until …,<br/>N of 3 pauses left, Never mind, Open Dusk to pause<br/>render: none (device only)"}}
  shieldScreen -->|"Never mind"| tap[("ShieldAction: transitions.jsonl blockScreen; the screen closes")]
  shieldScreen -->|"Open Dusk to pause (only while pauses are left)"| asked[("ShieldAction: state.json doorAskedAt")]
  asked -.->|"iOS opens Dusk"| recent{"In Dusk: a block on and asked under 2 min ago?"}
  recent -->|"yes"| sheet
  recent -->|"no"| tonightOnly(["Tonight, no sheet"])

  tonightLocked["Tonight: Apps locked until …, dots, Pause<br/>render: home-blocked"]
  dayLine["Tonight: Study on until 5:00 pm, Pause<br/>render: home-day"]
  tonightLocked -->|"Pause (hidden with none left)"| askedHere[("state.json: doorAskedAt")]
  dayLine -->|"Pause (when no pause is open and some are left)"| askedHere
  askedHere --> sheet

  sheet{"The sheet: a pause under way? pauses left?"}
  sheet -->|"none under way, some left"| choosing["Pause blocking for 10 minutes? the dots, one dashed: This uses 1 of 2 left this week; the 60 s wait<br/>render: door-choosing"]
  sheet -->|"none under way, none left"| noneLeft["No pauses left · back Monday; the week's nights as dots, those to come dashed<br/>render: door-none"]
  sheet -->|"waiting"| waiting
  sheet -->|"open"| openPause
  noneLeft -->|"OK"| closedAsk[("state.json: doorAskedAt cleared; the sheet closes")]
  choosing -->|"Not now, or swipe down"| closedAsk
  choosing -->|"Pause for 10 min"| startCheck{"A block on, no pause open, some left?"}
  startCheck -->|"no: refused"| choosing
  startCheck -->|"yes"| waitStore[("state.json: the pause, waiting until now + 60 s<br/>DeviceActivity 'door': 15 min from the wait's end, warning at 10")]
  waitStore --> waiting["The wait: a bar fills over 60 s; Cancel<br/>render: door-waiting"]
  waiting -->|"Cancel"| cancelled[("state.json: the pause removed; nothing spent")]
  cancelled --> tonightLocked
  waiting -.->|"the wait ends: the monitor's 'door' start, or the sheet's own timer"| opens[("reconcile: one pause spent; shield off for every block;<br/>counted in the gap's week if asked before bed")]
  opens --> openPause["10:00 left, a draining bar with a tick; Lock again before 11:43 pm and you keep the pause<br/>render: door-open"]
  openPause -->|"Lock again, within 2 min"| returned[("state.json: the pause ends and is given back")]
  openPause -.->|"2 minutes pass"| usedPause["This pause is used. Locking ends it early. Lock again<br/>render: door-open-used"]
  usedPause -->|"Lock again"| ended[("state.json: the pause ends")]
  openPause -.->|"10 minutes: the monitor's 'door' warning, or the sheet's own timer"| ended
  openPause -.->|"every block ends while paused"| ended
  returned --> relocked["Shield back on; Tonight: Apps locked until …<br/>render: home-blocked"]
  ended --> relocked
  openPause -->|"swipe down"| heroPaused["Tonight: Paused until …, then locked until 7:00 am; Lock again<br/>render: home-pause-open"]
  heroPaused -->|"Lock again"| returned
  waiting -->|"swipe down"| tonightWaiting["Tonight: Apps locked until …; Pause reopens the sheet on the wait<br/>render: home-pause-waiting"]
  tonightWaiting -->|"Pause"| sheet

  monday(["Monday noon (the night key): spent goes back to 0"]) -.-> tonightLocked

  classDef system stroke-dasharray: 5 3
  class shieldScreen system
```

The sheet closes by itself when nothing is pending any more: the block ends, or the pause ends with no new ask (`AppModel.doorPending`).

## Doubts
- **When `door-none` is reached in practice** (intended, #141): Tonight hides Pause with none left and the block screen drops its button at 0 (D47), so the "No pauses left" sheet shows only when an ask arrives with none left, for example a block screen drawn before the last pause was spent. It stays as the answer to that stale ask. Worth a device check.
- **Swiping the sheet away during the wait** leaves the wait running; Tonight's state shows "Apps locked until" (the pause isn't open yet), with Pause to reopen (`home-pause-waiting`). The pause is spent only when the wait ends (`DoorRules.advance`), so Pause stays while the wait runs, even if it is to spend the week's last (#124).
- **Every bar of the sheet keeps one line** (#135): choosing's "Not now" has an empty room under Cancel and Lock again (`LinkRoom`, TollUI). The bar steps with its countdown once a second, with no motion of its own (design §2.5, #151).
- **Two timers end a pause:** the monitor's DeviceActivity warning and the sheet's own `Task.sleep`. Each sends a reconcile, and reconcile reads the stored times, so both are safe; the transition log can show two lines for one end.
- **The block screen can't be rendered** (Family Controls in the simulator), so its node has no scenario; its words are tested in `ShieldTextTests` and checked in `docs/device-protocol.md`.
