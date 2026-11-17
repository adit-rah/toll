import SwiftUI
import TollCore
import TollData
import TollScreenTime
import TollUI

/// The device-testing screen for spec §12 step 2: the state, the permissions, the settings and the
/// log in one list. Setup and Status replace it in steps 4 and 5.
struct TriggerView: View {
  let model: AppModel

  var body: some View {
    NavigationStack {
      Form {
        stateSection
        permissionsSection
        WindowSection(model: model)
        HomeSection(model: model)
        KeepOpenSection(model: model)
        logSection
      }
      .navigationTitle(Copy.Trigger.title)
    }
  }

  private var stateSection: some View {
    Section(Copy.Trigger.state) {
      let state = model.state
      if state.blockOn, let end = state.blockEndsAt {
        LabeledContent(Copy.Trigger.blocked, value: Copy.Trigger.until(Copy.time(end)))
      } else {
        Text(Copy.Trigger.notBlocked)
      }
      Text(state.homeCheck == .windowOnly ? Copy.Trigger.windowOnly : presence(state.presence))
      Text(inWindow(state) ? Copy.Trigger.inWindow : Copy.Trigger.outsideWindow)
      Text(state.entitled ? Copy.Trigger.entitled : Copy.Trigger.notEntitled)
      if state.pending != nil { Text(Copy.Trigger.pending) }
    }
  }

  private var permissionsSection: some View {
    Section(Copy.Trigger.permissions) {
      PermissionRow(title: Copy.Trigger.screenTime, status: screenTimeText) {
        Task { await model.requestScreenTime() }
      }
      PermissionRow(title: Copy.Trigger.location, status: locationText) {
        model.requestLocation()
      }
    }
  }

  private var logSection: some View {
    Section(Copy.Trigger.log) {
      Button(Copy.Trigger.reconcileNow) { model.reconcile(.foreground) }
      ForEach(Array(model.log.enumerated()), id: \.offset) { _, line in
        Text(Copy.Trigger.line(line))
          .font(TollFont.caption)
          .monospacedDigit()
      }
    }
  }

  private func presence(_ presence: Presence?) -> String {
    guard let presence else { return Copy.Trigger.unknown }
    return
      "\(presence.isHome ? Copy.Trigger.home : Copy.Trigger.away)\(Copy.middleDot)\(Copy.time(presence.at))"
  }

  private func inWindow(_ state: SleepState) -> Bool {
    state.settings.window?.contains(Date(), calendar: .current) ?? false
  }

  private var screenTimeText: String {
    switch model.screenTime {
    case .approved: Copy.Trigger.allowed
    case .denied: Copy.Trigger.denied
    case .notDetermined: Copy.Trigger.notAsked
    }
  }

  private var locationText: String {
    switch model.location {
    case .always: Copy.Trigger.always
    case .whileUsing: Copy.Trigger.whileUsing
    case .approximate: Copy.Trigger.approximate
    case .denied: Copy.Trigger.denied
    case .notDetermined: Copy.Trigger.notAsked
    }
  }
}

private struct PermissionRow: View {
  let title: String
  let status: String
  let allow: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(title)
        Text(status).tollText(.caption)
      }
      Spacer()
      Button(Copy.Trigger.allow, action: allow)
    }
  }
}
