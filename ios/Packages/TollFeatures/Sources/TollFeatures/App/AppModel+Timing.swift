import Foundation
import TollCore
import TollData

/// Personal timing (D66, D99): the week's start is drawn here, in the app, the only process that
/// links the sleep model and keeps its state. TollCore says when a draw is due (`TimingRules.ask`)
/// and keeps the answer in force for every process; nights the app doesn't open before run at the
/// plan and are recorded as such.
extension AppModel {
  /// After the nights are recorded and corrected from Health, so the draw learns from last night.
  func chooseStart() async {
    guard let ask = TimingRules.ask(state, now: Date(), calendar: .current, config: config) else {
      return
    }
    let command = await Task.detached(priority: .utility) { ModelStore().choose(ask) }.value
    guard let command else { return }
    send(.foreground, [command])
  }
}
