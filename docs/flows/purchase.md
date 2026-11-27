# The free nights, their end and the purchase

**What it's for:** 14 nights free, then $9.99 once. The free nights' start is kept in the phone's Keychain and in iCloud Keychain, so deleting the app or moving to a new phone on the same Apple ID doesn't start them again. Nothing is sold while anything is blocked. When the free nights end, Dusk is Off until bought; buying, restoring or an Ask to Buy approval turns it back on.

**Implements:** P-1 to P-4, D7 (the deal stated in full), D23 (entitlement worked out at every wake), D33 (selling only when nothing blocks), D34 (the price), D50 (setup promises only what's left), D74 (Off, not "Paused"), D78 and D82 (14 nights, both Keychain copies, earliest wins), D84 (the sheet hides zeros; "Purchase restored."), D87 (outcomes keep the offer's height).

**Code:** `TollCore/Domain/Trial.swift`, `TrialStart.swift`; `Engine.reconcile` (`Trial.isEntitled`); `HomeSnapshot.pill`, `FreeWeek`; `TollData/Purchase/Purchase.swift` (`Purchase`, `TrialClock`), `Keychain/Keychain.swift`; `TollFeatures/Purchase/PurchaseSheet.swift`; `AppModel.start`, `foreground`, `buy`, `restore`, `setPurchased`; `Settings/SettingsView.swift` (Free nights, Restore).

## The free nights and their end

```mermaid
flowchart TD
  done(["Onboarding's Done"]) --> begin[("Keychain: the free nights' start, this phone and iCloud;<br/>the earliest on record wins, else now")]
  begin --> stateStart[("state.json: trial.start")]
  launch(["Every launch and foreground"]) --> settle[("Keychain: both copies set to the earliest;<br/>state.json: trial.start the earlier of the two")]
  stateStart --> during["Tonight: Night 5 of 14 free, segments, in the bar<br/>render: home-first-week"]
  during -->|"the pill"| sheet["The purchase sheet<br/>render: home-pill-purchase"]
  during -.->|"the 14th night is next"| lastNight["Tonight: Last free night tonight, amber<br/>render: home-last-night"]
  lastNight -->|"the pill"| sheet
  lastNight -.->|"its end: the first wake after it (monitor, app or block screen)"| notEntitled[("reconcile: entitled false; every shield off; nothing scheduled to block")]
  notEntitled --> offState["Tonight: Dusk is off this morning; Turn Dusk back on · $9.99 once, for good<br/>render: home-paused"]
  offState -->|"Turn Dusk back on"| sheet
  notEntitled --> sleepFrozen["Your sleep: Your free nights, two rows of seven dots<br/>render: sleep-after-trial"]
  settingsRow["Settings: Free nights · Night 5 of 14, $9.99 once<br/>render: settings"]
  settingsRow -->|"$9.99 once"| sheet
```

No pill shows while any block is on, while away, or with no night (D33, D75). Off also stops the heads-up ([heads-up.md](heads-up.md)) and the Tonight cards ([tonight.md](tonight.md)).

## Buying and restoring

```mermaid
flowchart TD
  sheet["The purchase sheet: free nights as segments, the nights locked and taps if above 0,<br/>what buying keeps, its terms; $9.99 once, Keep it, Restore purchase<br/>render: purchase"]
  sheet -->|"Keep it"| payment{{"App Store payment sheet"}}
  payment -.->|"cancelled"| sheet
  payment -.->|"bought"| bought[("state.json: trial.purchased; reconcile: entitled")]
  payment -.->|"Ask to Buy: waiting for a parent"| pending["Waiting for approval<br/>render: purchase-pending"]
  payment -.->|"failed"| failed["The purchase didn't go through: Try again, Not now<br/>render: purchase-failed"]
  failed -->|"Try again"| payment
  failed -->|"Not now"| closed(["Sheet closes"])
  pending -->|"OK"| closed
  bought --> doneSheet["Every night is yours: Dusk keeps locking your apps every night; all segments filled; Done<br/>render: purchase-done"]
  doneSheet -->|"Done"| closed
  sheet -->|"Restore purchase"| sync{{"App Store sync (may ask for the Apple Account)"}}
  sync -.->|"found"| bought
  sync -.->|"none"| restoreNone["No purchase found: OK<br/>render: purchase-restore-none"]
  restoreNone -->|"OK"| sheet

  updates(["Later, with Dusk running: StoreKit transaction updates<br/>(Ask to Buy approved, a refund, a purchase on another phone)"]) -.-> recheck{"A current, verified, unrevoked purchase?"}
  foreground(["Every foreground"]) -.-> recheck
  recheck -->|"yes"| bought
  recheck -->|"no"| unbought[("state.json: trial.purchased off; Off again if the free nights are over")]

  settingsRestore["Settings: Restore purchase<br/>render: settings"]
  settingsRestore -->|"tap"| sync2{{"App Store sync"}}
  sync2 -.->|"found"| restored["Settings: Purchase restored. (row stays this visit)<br/>render: none"]
  sync2 -.->|"none"| restoreNoneSmall["No purchase found (374 pt)<br/>render: none"]
  sync2 -.->|"found"| bought

  classDef system stroke-dasharray: 5 3
  class payment,sync,sync2 system
```

Welcome's "Already bought it? Restore" is the same restore; see [onboarding.md](onboarding.md).

Every outcome's button sits on the offer's "Keep it" line (#135): the terms left the bar for the scrolling content, and an outcome with one button keeps the restore link's room under it, empty (`LinkRoom`). There is no spinner in "Keep it" while the App Store answers: a spinner loops, which design §2.5 never allows; the button dims until Apple's sheet appears (#129).

## Doubts
- **An approved Ask to Buy reaches Dusk only while it runs** (`Transaction.updates`) or at the next foreground. Until then the monitor still treats the night as Off, so a night can stay unlocked after approval if Dusk isn't opened. Intended (#141): the extensions never import StoreKit (spec §9, CLAUDE.md), and the pending sheet already asks the person to come back; proposed for the decisions log.
- **A refund while Dusk stays closed** keeps blocking until the next foreground: the extensions read `trial.purchased` from the state file, and only the app asks StoreKit.
- **The free nights after the trial on Your sleep** ("Your free nights"): `sleep-after-trial`.
- **The Off state's name in code:** `home-paused` is the render id for Off, and night records call it `dusk.paused` (see `data.md`). Both predate D74's rename; the pause itself is `door` in code.
