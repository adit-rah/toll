import SwiftUI
import TollCore
import TollUI

/// The only main screen (spec §7 Status): the state in one line, the facts beneath, a gear. Nothing
/// else.
struct StatusView: View {
  let state: SleepState
  let now: Date
  let openSettings: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
          ScreenTitle(StatusLine(state: state, now: now, calendar: .current).text())
            .contentTransition(.opacity)
            .animation(Motion.stateChange, value: state.blockOn)
          StatusFacts(state: state, now: now)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tollGutter()
      }
      .background(TollColor.bg)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: openSettings) {
            Image(systemName: "gearshape")
          }
          .accessibilityLabel(Copy.Status.settings)
        }
      }
    }
    .tint(TollColor.accent)
  }
}

/// The lines under the state. Unlocks arrive with the door (step 6), the trial line with step 7.
struct StatusFacts: View {
  let state: SleepState
  let now: Date

  var body: some View {
    EmptyView()
  }
}
