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

/// App names on one line, then words that belong after them ("Instagram is open"). Names never
/// shrink into each other: when they do not all fit, the first ones stay whole and the rest become
/// "+2"; only a single name that cannot fit is cut.
struct NamesThen<After: View>: View {
  let refs: [AppRef]
  let after: After

  init(_ refs: [AppRef], @ViewBuilder after: () -> After) {
    self.refs = refs
    self.after = after()
  }

  var body: some View {
    let shown = Array(refs.prefix(4))
    ViewThatFits(in: .horizontal) {
      ForEach(Array(stride(from: shown.count, through: 1, by: -1)), id: \.self) { count in
        line(Array(shown.prefix(count)), hidden: refs.count - count, fixed: true)
      }
      line(Array(shown.prefix(1)), hidden: refs.count - 1, fixed: false)
    }
  }

  private func line(_ names: [AppRef], hidden: Int, fixed: Bool) -> some View {
    HStack(spacing: 0) {
      ForEach(Array(names.enumerated()), id: \.element) { index, ref in
        if index > 0 { Text(", ").fixedSize() }
        AppLabel(ref)
          .lineLimit(1)
          .fixedSize(horizontal: fixed, vertical: false)
      }
      if hidden > 0 { Text(Copy.Bar.more(hidden)).fixedSize() }
      after.fixedSize()
    }
    .lineLimit(1)
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

/// Behind the bar, down to the bottom edge: rows fade out over 20 pt as they pass under it, so no
/// half-covered line shows in the gap above the tab bar (design §4.1).
struct BarFade: View {
  private static let fade: CGFloat = 20

  var body: some View {
    VStack(spacing: 0) {
      LinearGradient(
        colors: [TollColor.bg.opacity(0), TollColor.bg], startPoint: .top, endPoint: .bottom
      )
      .frame(height: Self.fade)
      TollColor.bg
    }
    .padding(.top, -Self.fade)
    .ignoresSafeArea(edges: .bottom)
    .allowsHitTesting(false)
  }
}
