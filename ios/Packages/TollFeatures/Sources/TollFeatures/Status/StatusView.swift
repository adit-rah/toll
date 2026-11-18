import SwiftUI
import TollCore
import TollUI

/// The only main screen (spec §7 Status): the state in one line, the facts beneath, a gear. Nothing
/// else.
struct StatusView: View {
  let state: SleepState
  let now: Date
  var trialNight: Int?
  let openSettings: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
          ScreenTitle(StatusLine(state: state, now: now, calendar: .current).text())
            .contentTransition(.opacity)
            .animation(Motion.stateChange, value: state.blockOn)
          StatusFacts(state: state, now: now, trialNight: trialNight)
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

/// The lines under the state: unlocks, when one returns (D-5, D-6), and the trial's night (P-5).
struct StatusFacts: View {
  let state: SleepState
  let now: Date
  var trialNight: Int?
  var config = TollConfig.defaults

  var body: some View {
    VStack(alignment: .leading, spacing: TollSpacing.labelGap) {
      Text(Copy.Door.unlocksLeft(state.unlocks.left(config), of: config.unlocks.max))
        .tollText(.body)
        .monospacedDigit()
      if let nights = state.unlocks.nightsToRefill(config) {
        Text(Copy.Door.refill(after: nights))
          .tollText(.subhead)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let trialNight {
        Text(Copy.Trial.night(trialNight, of: config.trial.nights))
          .tollText(.subhead)
          .monospacedDigit()
      }
    }
  }
}
