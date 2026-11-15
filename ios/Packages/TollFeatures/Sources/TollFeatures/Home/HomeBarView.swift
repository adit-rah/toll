import SwiftUI
import TollCore
import TollUI

/// Home's state bar (design §3.18): the bar's state drawn as two lines. App names are the system's
/// labels, so a line that starts with one is a row of views, not a string.
struct HomeBarView: View {
  let state: HomeBarState
  let gateLine: String?
  /// The wait's end as the gate model keeps it, guarded against clock changes (G-9).
  let waitEndsAt: Date?
  let action: () -> Void

  var body: some View {
    StateBar(spoken: spoken, hint: Copy.Bar.opensSheet, action: action) {
      icon
    } title: {
      title
    } line: {
      line
    }
    .accessibilityIdentifier("stateBar")
  }

  private var spoken: String? {
    switch state {
    case .screenTimeOff:
      AccessibilitySentence.join([Copy.Bar.screenTimeOff, Copy.Bar.screenTimeOffLine])
    case .needsRepicking:
      AccessibilitySentence.join([Copy.Bar.needsRepicking, Copy.Bar.needsRepickingLine])
    case .nothingYet: AccessibilitySentence.join([Copy.Bar.nothingYet, Copy.Bar.chooseApps])
    default: nil
    }
  }

  @ViewBuilder
  private var icon: some View {
    switch state {
    case .screenTimeOff, .needsRepicking:
      SymbolTile("shield", tint: TollColor.level3)
    case .nothingYet:
      SymbolTile("shield")
    case .nothingNow:
      SymbolTile("clock")
    case .blocked(let active, _):
      AppIconCluster(HomeBarState.apps(of: active), size: 24)
    case .waiting(let wait):
      AppTile(wait.appRefs.first)
    case .choosing(let pending):
      AppTile(pending.appRefs.first)
    case .open(_, let session):
      AppTile(session.appRefs.first)
    }
  }

  @ViewBuilder
  private var title: some View {
    switch state {
    case .screenTimeOff: Text(Copy.Bar.screenTimeOff)
    case .needsRepicking: Text(Copy.Bar.needsRepicking)
    case .nothingYet: Text(Copy.Bar.nothingYet)
    case .nothingNow: Text(Copy.Bar.nothingNow)
    case .blocked(let active, _):
      NamesThen(HomeBarState.apps(of: active)) { Text(Copy.Bar.blockedSuffix) }
    case .waiting(let wait):
      NamesThen(Array(wait.appRefs.prefix(1))) {
        Text(Copy.Bar.unlocksInSuffix)
        CountdownText(endsAt: waitEndsAt ?? wait.startedAt.addingTimeInterval(wait.duration))
      }
    case .choosing: Text(Copy.Bar.unlockReady)
    case .open(_, let session):
      NamesThen(session.appRefs) { Text(Copy.Bar.isOpenSuffix) }
    }
  }

  @ViewBuilder
  private var line: some View {
    switch state {
    case .screenTimeOff: Text(Copy.Bar.screenTimeOffLine)
    case .needsRepicking: Text(Copy.Bar.needsRepickingLine)
    case .nothingYet: Text(Copy.Bar.chooseApps)
    case .nothingNow(let next, let apps):
      Text(HomeBarState.startsLine(next, apps: apps))
    case .blocked(let active, let next):
      Text(HomeBarState.blockedLine(active.first, next: next))
    case .waiting:
      Text(gateLine ?? "")
    case .choosing(let pending):
      NamesThen(pending.appRefs) { Text(Copy.middleDot + Copy.Bar.chooseHowLong) }
    case .open(let block, let session):
      if case .open(let until) = block.line {
        TickingText(endsAt: until) { Copy.Bar.session(minutes: session.minutes, secondsLeft: $0) }
      }
    }
  }
}

/// App names on one line, then words that belong after them ("Instagram is open").
struct NamesThen<After: View>: View {
  let refs: [AppRef]
  let after: After

  init(_ refs: [AppRef], @ViewBuilder after: () -> After) {
    self.refs = refs
    self.after = after()
  }

  var body: some View {
    HStack(spacing: 0) {
      AppNames(refs)
        .layoutPriority(0)
      after
        .fixedSize()
        .layoutPriority(1)
    }
  }
}

/// One app's icon at the bar's and the sheet's 36 pt.
struct AppTile: View {
  let ref: AppRef?

  init(_ ref: AppRef?) {
    self.ref = ref
  }

  var body: some View {
    Group {
      if let ref {
        AppLabel(ref, style: .icon)
      } else {
        Color.clear
      }
    }
    .frame(width: 36, height: 36)
    .accessibilityHidden(true)
  }
}
