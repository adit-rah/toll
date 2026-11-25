# Blocks and the block editor

**What it's for:** every block in one place. The night leads as its own card; other blocks (Study, Work, Gym, Other) are compact rows, and adding one is a kind, the apps and Save. Editing changes the name, kind, apps, hours and place in place. A change to a block that is on waits until it ends. The night's editor is "Your nights": no name, no kind, no Delete, and its place is home, set with the same map as Tonight and Settings.

**Implements:** D29 (blocks), D39, D40 and D45 (the limits: 40 apps and sites, 8 sets of hours, 8 blocks), D63 and D64 (the tab, the limits pinned at the bottom), D68 and D73 (quieter blocks, adding in three taps, kinds bring names and hours), D37 and #63 (a place without Always: run anyway or wait), D84 (the night's Place opens the home map), D87 (the note for a block that's on sits above Save and never moves the page), B-3 (edits to an active block wait).

**Code:** `TollFeatures/Blocks/` (`BlocksView`, `BlockEditorView`, `BlockEditorModel`, `BlockEditorParts`, `HoursInline`, `BlockAppsView`, `PlacePicker`); `TollCore/App/BlocksSnapshot.swift`, `BlockRows.swift`, `BlockDraft.swift`, `BlockLimits.swift`; `Engine.apply(.saveBlock, .deleteBlock, .savePlace)`, `Engine.validate`.

```mermaid
flowchart TD
  tab["Blocks: the night's card, other blocks as rows, New block, the limits pinned<br/>render: blocks, blocks-day"]
  tonightStrip["Tonight: a strip segment's Edit, or Set your night<br/>render: home-strip-day"]
  tab -->|"the night's card"| nightEditor
  tab -->|"a block's row"| editor
  tonightStrip -->|"Edit"| editor
  tab --> canAdd{"Fewer than 8 blocks and a set of hours free?"}
  canAdd -->|"no"| full(["New block greyed: Up to 8 blocks, or the hours are full"])
  canAdd -->|"yes: New block"| kinds["New block: Study, Work, Gym, Other<br/>render: block-new"]
  kinds -->|"picks a kind"| kindApplied[("draft: the kind's name and hours,<br/>e.g. Gym 6–7 pm weekdays")]
  kindApplied --> firstPicker{{"Apple's apps picker, at once"}}
  firstPicker -.->|"picked, or closed"| newDraft["The new block: name, Apps, hours, Place (Anywhere)<br/>render: block-new-gym"]
  newDraft --> editing

  editor["Edit a block: kind, name, Apps, hours, Place, Delete block, Save<br/>render: block-edit"]
  editor --> isOn{"The block on now?"}
  isOn -->|"yes"| onNote["Study is on until 5:00 pm. above Save for after 5:00 pm<br/>render: block-edit-on"]
  isOn -->|"no"| editing
  onNote --> editing

  editing(["Editing"]) -->|"kind chip"| kindFollow[("draft: name and hours follow the kind only while still the old kind's defaults")]
  editing -->|"Apps, with none yet"| picker{{"Apple's apps picker"}}
  editing -->|"Apps, with some"| appsList["The apps, the count against the limit, Choose more, Done<br/>render: none"]
  appsList -->|"Choose more"| picker
  editing -->|"From, Until, the day chips"| hours{"A ninth set of hours?"}
  hours -->|"yes"| hoursFull(["Said under the hours; Save stays off"])
  hours -->|"no"| editing
  editing -->|"Place"| placePicker["Place: search, current location, or Anywhere; then the map and its size<br/>render: none"]
  placePicker -->|"Use this place, or Use anywhere"| editing
  editing -->|"Save block / Save"| canSave{"A kind, some apps, valid hours, within 40 apps and sites,<br/>a name of 1–24 characters?"}
  canSave -->|"no"| editing
  canSave -->|"yes"| alwaysCheck{"A place, and location short of Always?"}
  alwaysCheck -->|"yes"| withoutAlways["Without Always: Only at Library, or Run anyway<br/>render: none"]
  withoutAlways -->|"Only at …: waits for Always"| save
  withoutAlways -->|"Run anyway"| save
  alwaysCheck -->|"no"| save
  save{"The engine: too many blocks, places, sets of hours or apps?"}
  save -->|"refused"| refusal(["A note says why; nothing saved"])
  save -->|"block on now"| held[("state.json: pending edit; applied when it ends (B-3)")]
  save -->|"otherwise"| applied[("state.json: the block; schedules and shield on the next reconcile")]
  held --> popped(["Back to where it came from: Blocks, or Tonight's strip"])
  applied --> popped

  editor -->|"Delete block"| deleteSheet["The delete sheet: what stops being blocked; the other blocks stay<br/>render: none"]
  deleteSheet -->|"Delete block, or Delete at 5:00 pm while on"| deleted[("state.json: removed now, or pending delete")]
  deleteSheet -->|"Cancel"| editor
  deleted --> popped

  nightEditor["Your nights: Apps, the hours (weeknights and Fri and Sat nights if they differ), Place<br/>render: block-night"]
  nightEditor -->|"Place"| homeSheet["The home map sheet, see set-home.md<br/>render: set-home-set"]
  homeSheet -.->|"closes: the editor reads home back"| nightEditor
  nightEditor -->|"Apps, hours"| editing

  classDef system stroke-dasharray: 5 3
  class firstPicker,picker system
```

The tab bar hides on the editor so Save can sit at the bottom. Saving a place moves it for every block that uses it (`savePlace` keeps its id); a move of a place an active block uses waits like an edit.

## Doubts
- **Block.isOn has no switch.** Blocks store whether they're on and the engine respects it, but no screen turns a block off; only Delete removes one.
- **No render reaches the apps list, the place picker, Delete's sheet or the Without Always question.** The simulator has no app tokens, so the apps list is empty there anyway.
- **The night can't be left without apps:** removing every app in the picker keeps Save off (`canSave`), with no note saying why beyond the Apps row's "Choose apps to save".
