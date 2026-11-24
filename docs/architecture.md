# Architecture

Dusk has no server, but it is built like it has one: a domain that knows nothing about iOS, an application layer that decides and describes effects, adapters that talk to Apple's frameworks, and screens that only read and send intents. Each layer depends only on the ones below it.

```
 Presentation   TollFeatures      Views and view models. Read snapshots, send intents. No rules, no frameworks below SwiftUI.
      │
 Application    TollCore/App      Commands, Reconcile, snapshots. Pure: state + command + clock → new state + Effects.
      │
 Domain         TollCore/Domain   Block, Schedule, Place, Presence, Door, Unlocks, Trial and their rules. Pure values.
      │
 Ports          TollCore/Ports    Protocols the application needs done: store, shield, schedules, log, regions, purchases.
      ▲
 Adapters       TollScreenTime    ManagedSettings, DeviceActivity, FamilyControls (shared with extensions)
                TollData          CoreLocation, StoreKit, Keychain (app only)
                TollCore/Persist  The App Group state file and transition log
      ▲
 Hosts          App, Monitor,     Composition roots: wire adapters into the application layer. One line of logic at most.
                ShieldAction,
                ShieldConfig
```

Rules that keep it that way:
- **Domain and Application are pure and Linux-tested.** No `Date()`, no singletons, no frameworks beyond Foundation value types. Time comes in as an argument.
- **Every change is a `Command`.** Screens, extensions and region events all send commands. `Engine.apply(command:)` changes state, then `Engine.reconcile` decides what must be true now and returns `Effects`. Only adapters perform effects.
- **Effects are data.** For example: "shield these selections", "monitor these windows", "watch these places", "append these log lines". The coordinator (`Coordinator`, shared by the app and every extension) loads state, runs the engine, saves, then hands the effects to ports. Tests run the coordinator with fake ports.
- **Screens read snapshots, not state.** `HomeSnapshot`, `DoorSnapshot`, `WeekStats` and the like are built in TollCore from state and the log, and tested. Views lay them out.
- **Extensions use the same coordinator** with the adapters they are allowed: Monitor and ShieldAction write; ShieldConfig only reads snapshots.

## The model

```
DuskState (schema 2, one coordinated JSON file in the App Group)
├── blocks:   [Block]                     ≤ blocks.max, exactly one of kind .sleep
├── places:   [Place]                     shared by blocks; one is Home
├── presence: [PlaceID: Presence]         last word from region monitoring
├── location: .places | .scheduleOnly     decisions D8: without Always + Precise, places are ignored
├── pending:  [BlockID: BlockEdit]        an edit to an active block waits until it ends (B-3)
├── door:     Door?                       one at a time, across all blocks (D-7)
├── unlocks:  UnlockSupply                the week's pauses, shared by all blocks (D67)
├── trial:    Trial (start, purchased)
├── gap:      Gap                         minutes the night locks before bed, growing or fixed (D76)
└── runtime:  per-block active night and last end (B-4), clock anchor, scheduled windows
```

- **Block:** an id, a name, a kind (sleep, study, work, gym, other: icon and default name), an optional place, a weekly schedule, the apps it blocks (an opaque selection only the Screen Time adapter can read), and whether it is on.
- **Weekly schedule:** rules, each a set of days and one time window. A rule's window *starts* on its days and may cross midnight. The Sleep block's "different on weekends" is simply two rules.
- **Place:** a name, a centre and a radius. Blocks refer to places by id, so moving Home moves every block at Home.
- **Night:** one occurrence of the Sleep block. The trial counts nights (P-2); the pauses' week starts with Monday's night (D67). Other blocks have occurrences but no nights.

## The rules, generalised from the spec

- **Active block (B-1):** entitled, on, inside one of its schedule's occurrences, at its place (or it has none, or location is `.scheduleOnly`), and that occurrence started after the block's last end (B-4).
- **Shield:** the union of active blocks' apps, sites and categories, or nothing while a pause is open (D67). One ManagedSettings store, so a pause lifts every block at once.
- **The gap before bed (D76):** the night's stored hours are bed to wake; it runs, and is scheduled, from bed minus the gap. Each Monday at noon (the pauses' week) the week before is judged from a tally kept as it happens: nights the lock ran, pauses started before bed, Screen Time off. A change while the night is on waits until it ends, like an edit.
- **Edits (B-3):** edits to an active block, or to a place an active block uses, wait until that block ends. Everything else applies at once.
- **Door, shown as "Pause" (D67):** every block's shield. 60 s wait, then 10 minutes on the clock (D31). It ends when its time is up, on "Lock again", or when no block is active. 3 a week, shared by all blocks, back to 3 when Monday's night starts (noon), none carried over.
- **Limits:** iOS shields at most 50 apps and sites by name, so at most `blocks.maxApps` (40) across all blocks, as designed. At most 20 places (CLMonitor's limit). At most `schedule.maxWindows` distinct time windows, so window, sweep and door schedules stay under DeviceActivity's 20 activities.

## Scheduling

DeviceActivity only wakes the monitor; reconcile decides.
- **Window schedules:** one repeating daily schedule per distinct time window across all blocks, plus a sweep after each. On days a rule does not cover, its wakes change nothing.
- **Door schedule:** one 15-minute interval from the end of the wait, with its warning set so it fires at the door's minutes. That is the closest thing iOS offers to a timer that runs while the app is closed.

## Migration

Schema 1 is step 2's `SleepState`: one window, one home, one blocklist. On first load it becomes a Sleep block at a Home place with that window and those apps; presence, door, unlocks, trial and purchase carry over. Tested.

## Where things live

| Layer | Folder |
|---|---|
| Domain | `ios/Packages/TollCore/Sources/TollCore/Domain/` |
| Application | `…/TollCore/App/` (Engine, Command, Effects, Coordinator, snapshots) |
| Ports | `…/TollCore/Ports/` |
| Persistence adapter | `…/TollCore/Persist/` |
| Screen Time adapters | `…/TollCore/Sources/TollScreenTime/` |
| App-only adapters | `ios/Packages/TollData/` |
| Presentation | `ios/Packages/TollFeatures/<Screen>/`, components and tokens in `TollUI` |

Package names keep the Toll prefix until the product name is final; a rename is mechanical.
