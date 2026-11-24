import Foundation
import TollCore
import TollData

/// Before bed's helpers (D80): the rules are TollCore's; these send the person's choices, leave the
/// private log line the night record reads, and start or stop the tone.
extension AppModel {
  /// The breath's length now: Settings' choice, within its range.
  var breathMinutes: Int { state.helpers.breath(config) }

  /// A helper opened from the sheet: one log line, so the night record can say which (D62).
  func openHelper(_ helper: Helper) {
    send(helper.cause)
    if helper == .breathe { startBreath() }
  }

  func startBreath() {
    #if DEBUG
      if DemoScenario.current != nil { return }
    #endif
    BreathTone.shared.start(Breath(minutes: breathMinutes, config: config), config: config.helpers)
  }

  func stopBreath() {
    BreathTone.shared.stop()
  }

  /// Settings › Before bed's "Done": the gap (held while the night is on, B-3) and the helpers'
  /// switch and breath, which apply at once.
  func setBeforeBed(_ gap: Gap.Setting, helpers: Helpers) {
    send(.edit, [.gap(gap), .helpers(helpers)])
  }
}
