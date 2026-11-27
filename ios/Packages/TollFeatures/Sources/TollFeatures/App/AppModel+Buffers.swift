import Foundation
import TollCore

extension AppModel {
  /// The buffers' targets fitted from the person's recorded weeks (#145), or the baseline with too
  /// few; the rule is TollCore's `BufferSuggestion`.
  func bufferSuggestion() -> BufferSuggestion {
    #if DEBUG
      if let demo = DemoScenario.current { return demo.bufferSuggestion(config) }
    #endif
    return BufferSuggestion(
      nights: NightLog().buffers(calendar: .current), now: Date(), calendar: .current,
      config: config)
  }
}
