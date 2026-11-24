import Foundation
import TollCore

/// The gap before bed (D76): the rules are TollCore's `GapRules`; these send the person's choices.
extension AppModel {
  /// Settings › Before bed, or the offer on Tonight. Held while the night is on (B-3).
  func setGap(_ setting: Gap.Setting) {
    send(.edit, [.gap(setting)])
  }

  /// Monday's card: last week's gap.
  func keepGap() {
    send(.edit, [.keepGap])
  }

  /// What a gap card's link does.
  func openGapCard(_ card: TonightCard) {
    switch card {
    case .gapWeek: keepGap()
    case .gapOffer: setGap(.grows(config.gap.start))
    case .home, .headsUp, .beforeBed: break
    }
  }
}
