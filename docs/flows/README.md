# Flows

Every user flow in Dusk, as built on `main`, drawn as a Mermaid flowchart. A UX audit pairs each chart with the renders its nodes name (`docs/renders.md`), and a change to a flow changes its chart in the same pull request. `data.md` lists everything the app keeps on the phone, which a change of format or of the sleep model has to carry forward.

## The charts

| Chart | What it covers | Decisions |
|---|---|---|
| [onboarding.md](onboarding.md) | First launch to the first locked night: Welcome, wake time, Screen Time, the apps, Ready | D68, D71, D76, D78, D82 |
| [set-home.md](set-home.md) | "Only when I'm home": the map, the location prompts, Always, and "Use anywhere" | D68, D71, D84 |
| [heads-up.md](heads-up.md) | The heads-up before the night: Tonight's offer, iOS's prompt, Settings' switch | D68, D72 |
| [before-bed.md](before-bed.md) | The gap before bed (Monday's card, the offer to older installs, Settings) and the helpers in the gap | D76, D80, D83, D85 |
| [tonight.md](tonight.md) | Tonight through a day: what the state shows and when, the card slot's order, the strip | D69, D73, D75, D86 |
| [pause.md](pause.md) | The pause: from Tonight or the block screen, the wait, the open pause, Lock again | D67, D70, D84 |
| [purchase.md](purchase.md) | The free nights, their end, buying, Ask to Buy, restore, refunds | D33, D78, D82, D84 |
| [settings.md](settings.md) | Settings and every sheet or screen it opens | D72, D83, D84, D85 |
| [permissions.md](permissions.md) | Losing and getting back Screen Time, location and notifications | D8, D10, D37, D48, D72 |
| [your-sleep.md](your-sleep.md) | Your sleep: the sky, a star's night, the week, the ranges, landmarks and sharing | D69, D79, D81, D84, D88 |
| [blocks.md](blocks.md) | The Blocks tab and the block editor: new, edit, delete, the night's editor | D29, D45, D73, D84, D87 |
| [data.md](data.md) | Every piece of data that persists: where, its format, who writes and reads it, what a format change does today | D11, D62, D78 |

## Conventions

Each chart is a `flowchart`. Shapes say what a node is, so a chart reads the same in light and dark and without colour:

```mermaid
flowchart LR
  start(["Start or end of the flow"])
  screen["A Dusk screen or sheet<br/>render: scenario-id"]
  check{"A state check"}
  system{{"iOS: a permission prompt, system sheet or the Settings app"}}
  store[("A write to the phone's storage")]
  start --> screen
  screen -->|"what the person does"| check
  check -->|"yes"| system
  check -.->|"a system event"| store
  classDef system stroke-dasharray: 5 3
  class system system
```

- **Screens** are rectangles. The first line names the screen as people see it; the second is `render: <scenario>`, the id in `docs/renders.md` that shows it, or `render: none` when no scenario does. A tap that a render can reach from a scenario is written `render: <scenario> + tap`.
- **Edges** carry what the person does (solid, the button's words in quotes where it has them) or what the system does (dotted: a time passing, a region event, iOS answering, an extension waking).
- **Diamonds** are checks on state, phrased as the code checks them. Where the order of checks matters (Tonight's card slot, the state), the chart keeps the code's order.
- **Hexagons** with a dashed border are iOS's own UI: permission prompts, Apple's apps picker, the payment sheet, the share sheet, the Settings app.
- **Cylinders** mark the moments a flow writes to storage (`data.md` says where).
- Each file starts with what the flow is for and the decisions it implements, and ends with **Doubts**: anything the code left unclear, or that differs from a decision's text.
- Labels are quoted, since many contain parentheses or colons. Node ids avoid `end` and never start with `o` or `x` after an edge, which Mermaid reads as an edge type.

## Keeping the charts current

There is no CI check. A pull request that changes a flow updates its chart, and the reviewer checks it against this table: if the diff touches a folder on the left, the charts on the right are read again.

| Source folder | Charts |
|---|---|
| `ios/Packages/TollFeatures/Sources/TollFeatures/Setup/` (`SetupFlow`, `SetupModel`, `WakeTimeView`, `ScreenTimeView`, `BlocklistView`, `ReadyView`, `NightPictureView`) | onboarding |
| `…/TollFeatures/Setup/` (`SetHomeFlow`, `SetHomeModel`, `HomeMapView`, `PermissionsView`) | set-home, permissions |
| `…/TollFeatures/Home/` | tonight, pause, heads-up, before-bed, set-home |
| `…/TollFeatures/BeforeBed/` | before-bed |
| `…/TollFeatures/Door/` | pause |
| `…/TollFeatures/Purchase/` | purchase |
| `…/TollFeatures/Settings/` | settings, heads-up, before-bed, permissions |
| `…/TollFeatures/Insights/` | your-sleep |
| `…/TollFeatures/Blocks/` | blocks |
| `…/TollFeatures/App/` (`RootView`, `DuskTabs`, `AppModel*`) | every chart; read the one whose flow the change touches |
| `…/TollFeatures/Demo/` | the `render:` ids in every chart |
| `ios/Packages/TollCore/Sources/TollCore/App/` (`HomeSnapshot`, `TonightCard`, `Morning`, `HeadsUp`, `GapRules`, `GapSnapshot`, `DoorRules`, `Engine*`) | tonight, pause, heads-up, before-bed, set-home, purchase |
| `…/TollCore/App/` (`YourSleep`, `InsightsSnapshot`, `Sky*`, `PastNight`, `NightFacts`) | your-sleep, data |
| `…/TollCore/Domain/` (`Trial`, `TrialStart`, `Door`, `Gap`) | purchase, pause, before-bed |
| `…/TollCore/Persist/`, `…/TollCore/App/DuskState.swift`, `…/TollCore/Domain/` (any `Codable` type) | data |
| `ios/Packages/TollCore/Sources/TollScreenTime/`, `ios/Monitor/`, `ios/ShieldAction/`, `ios/ShieldConfig/` | pause, permissions, data |
| `ios/Packages/TollData/` | purchase, set-home, heads-up, permissions, data |
| `ios/Packages/SleepModel/`, `datascience/export/` | data |

When a flow is added, add its chart, a row in the first table and its folders in this one.
