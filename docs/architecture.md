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
DuskState (schema 5, one coordinated JSON file in the App Group)
├── blocks:   [Block]                     ≤ blocks.max, exactly one of kind .sleep
├── places:   [Place]                     shared by blocks; one is Home
├── presence: [PlaceID: Presence]         last word from region monitoring
├── location: .places | .scheduleOnly     decisions D8: without Always + Precise, places are ignored
├── pending:  [BlockID: BlockEdit]        an edit to an active block waits until it ends (B-3)
├── door:     Door?                       one at a time, across all blocks (D-7)
├── unlocks:  UnlockSupply                the week's pauses, shared by all blocks (D67)
├── trial:    Trial (start, purchased)
├── gap:      Gap                         minutes the night locks before bed, growing or fixed (D76)
├── flows:    [id: FlowRecord]            how each one-time flow last went (#140)
├── timing:   Timing                      personal timing: chosen or not, the week's start in force (D99)
└── runtime:  per-block active night and last end (B-4), clock anchor, scheduled windows
```

- **Block:** an id, a name, a kind (sleep, study, work, gym, other: icon and default name), an optional place, a weekly schedule, the apps it blocks (an opaque selection only the Screen Time adapter can read), and whether it is on.
- **Weekly schedule:** rules, each a set of days and one time window. A rule's window *starts* on its days and may cross midnight. The Sleep block's "different on weekends" is simply two rules.
- **Place:** a name, a centre and a radius. Blocks refer to places by id, so moving Home moves every block at Home.
- **Night:** one occurrence of the Sleep block. The trial counts nights (P-2); the pauses' week starts with Monday's night (D67). Other blocks have occurrences but no nights.

## The rules, generalised from the spec

- **Active block (B-1):** entitled, on, inside one of its schedule's occurrences, at its place (or it has none, or location is `.scheduleOnly`), and that occurrence started after the block's last end (B-4).
- **Shield:** the union of active blocks' apps, sites and categories, or nothing while a pause is open (D67). One ManagedSettings store, so a pause lifts every block at once.
- **The gap before bed (D76):** the night's stored hours are bed to wake; it runs, and is scheduled, from bed minus the gap. Each Monday at noon (the pauses' week) the week before is judged from a tally kept as it happens, at the monitor's daily noon wake if nothing reconciled earlier, so the new lock and heads-up apply that night with Dusk closed (#127): nights the lock ran, pauses started before bed, Screen Time off. A change while the night is on waits until it ends, like an edit.
- **Personal timing (D66, D99):** for a person who chose it, the app draws a start with the sleep model (−30, 0 or +30 minutes from the plan, inside the buffer before sleep) and the engine holds it Monday to Sunday by the night's date, putting it in force or taking it out only between nights. Every process locks with it; the monitor never links the model.
- **Edits (B-3):** edits to an active block, or to a place an active block uses, wait until that block ends. Everything else applies at once.
- **Door, shown as "Pause" (D67):** every block's shield. 60 s wait, then 10 minutes on the clock (D31). It ends when its time is up, on "Lock again", or when no block is active. 3 a week, shared by all blocks, back to 3 when Monday's night starts (noon), none carried over.
- **Limits:** iOS shields at most 50 apps and sites by name, so at most `blocks.maxApps` (40) across all blocks, as designed. At most 20 places (CLMonitor's limit). At most `schedule.maxWindows` distinct time windows, so window, sweep, door and turn schedules stay under DeviceActivity's 20 activities (8 × 2 + 2).

## Scheduling

DeviceActivity only wakes the monitor; reconcile decides.
- **Window schedules:** one repeating daily schedule per distinct time window across all blocks, plus a sweep after each. On days a rule does not cover, its wakes change nothing.
- **Turn schedule (#127):** one repeating daily interval from 12:01, while either buffer grows, so Monday's judgement runs at noon even with Dusk closed; the monitor then hands iOS the heads-ups at the new lock. Other days' wakes change nothing.
- **Door schedule:** one 15-minute interval from the end of the wait, with its warning set so it fires at the door's minutes. That is the closest thing iOS offers to a timer that runs while the app is closed.

## Migration

Schema 1 is step 2's `SleepState`: one window, one home, one blocklist. On first load it becomes a Sleep block at a Home place with that window and those apps; presence, door, unlocks, trial and purchase carry over. Schema 2 is the blocks (D29), with fields added later without a raise, `lastNightSeen` (D91) the last; 3 adds `minReader`, `writtenBy` , `flows` and `recoveredAt`, and moves "a file without a gap is from before D76" out of a decoder default into its step (#140). Tested, from a sample of every past format.

## Data and its evolution

There's no server, so every change to what Dusk keeps happens on the phone, in four processes that ship together and read the same files (`docs/flows/data.md` lists them). A build can meet a file from any earlier build, and, on TestFlight, from a later one. The rules every change follows:

- **Never lose a person.** Reading is lossy (`Persist/Lossy.swift`, `Decoding.swift`): a missing key takes its default, an unknown enum value its safe fallback (a block kind is `.other`, a location mode `.scheduleOnly`, a gap mode `.fixed`), and an element that can't be read is dropped alone. Only what identifies a thing is required. A new stored type gets a decoder written with these helpers, never a synthesized one.
- **Never write over what wasn't read.** A file that's there but can't be opened (before the first unlock) is left alone, and no effect runs. A file that can't be parsed is kept as `state.unreadable-<time>.json`; one read in part, as `state.partial-<time>.json`; one at another schema, once, as `state.v<n>.json`; then the new state is written atomically. The night comes back from the latest night record (`Recovery`); the free nights' start comes back from the Keychain at the next launch. Setup shows again only when there's no record.
- **Expand, then contract.** A build that adds a field, an enum case or a key first ships readers that tolerate it; only a later build writes it. A field's meaning never changes in place: it gets a new key.
- **Bump the schema** for every change of shape or meaning, additive or not (`DuskState.schema`). Set `DuskState.minReader` to the new schema when an older build would misread what this one writes, or drop it to harm (a new enum case; a field whose loss changes behaviour). A build below a file's `minReader` reads it and never writes it: it applies no command (`CommandError.readOnly`), the shield follows the file as read, nothing is logged, schedules are left as they are, and Tonight says changes can't be saved. A file without `minReader` came from a build before #140, which writes back whatever `schema` it read: it's read as schema 2, so every step it needs still runs.
- **Add a migration step** (`Migration.steps`) for the new schema, on the JSON as written, never through today's types. A default that carries a decision belongs in a step, keyed by the schema it applies to, not in a decoder.
- **Add a fixture.** Put a file in the new format, written by the build's own encoder, in `Tests/TollCoreTests/Fixtures/state/`, list it, and move the previous newest into `past`. `StateFixtureTests` migrates every fixture to the current shape, checks what each held and round-trips it, and fails when today's encoder writes a key path the newest fixture doesn't have. Fixtures are kept forever.
- **Night records are append-only.** A line is never rewritten. Each carries `record` (its format) and `rev`; a correction is a new line for the same night with a higher `rev`, and every reader takes the highest (the app's `NightLog`, `SleepModel.ModelCache`, `datascience`'s `latest`). `model_version` comes from the bundled artifact (the monitor's from `BundledModel`, generated from it by `sync-model.sh`). Readers accept every past shape. Nights are recorded before the transition log is trimmed (`NightKeeper`), by the monitor at each sweep and by the app on opening.
- **The model state is a cache.** `model.json` holds the person's state and the artifact it was built with; when the bundled artifact differs, the app rebuilds it from the night log, so a new model needs no migration in either direction. A rebuild fixture keeps Swift and Python equal.
- **The Keychain trial start's format never changes.** An older build on another phone of the same Apple ID reads it. Anything more goes in a new account beside it. A value that can't be read is never written over and never read as "no start"; a Keychain answer other than "not found" is unknown, and nothing is written that pass.
- **Platform names are formats too.** A renamed ManagedSettings store, DeviceActivity name or CLMonitor id strands the old one unless the change clears it, as `TollLeftovers` does.
- **Add a one-time flow only when a person must decide** (`docs/flows/README.md`). Everything else is a migration step.
- **Nothing leaves the phone** at any step: no network, no analytics. Kept copies and caches live in the App Group beside what they copy.

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
