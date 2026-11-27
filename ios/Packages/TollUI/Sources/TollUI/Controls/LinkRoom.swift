import SwiftUI

/// The room a quiet link takes under a bottom bar's button, kept empty where that state has no
/// link, so the button stays on one line while links come and go (D87, #135). Every bottom bar that
/// can gain or lose a quiet link keeps one: the pause sheet, the purchase sheet, the home map.
public struct LinkRoom: View {
  let type: TollType

  /// `type` is the missing link's, so the room matches it at every text size.
  public init(type: TollType = .quiet) {
    self.type = type
  }

  public var body: some View {
    QuietButton(" ", type: type) {}
      .frame(maxWidth: .infinity)
      .hidden()
      .accessibilityHidden(true)
  }
}
