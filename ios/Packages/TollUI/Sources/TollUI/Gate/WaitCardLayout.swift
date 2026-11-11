import SwiftUI

/// The wait card's spacing (design §3.7 to §3.9, §4.10, and the wait, naming and session picker
/// artboards). Gaps beside the hero numeral are 4 pt under the design's 28 and 12 because the
/// numeral's own line box already carries about 5 pt of air above the digits and below the
/// baseline; gaps beside chips are 5 pt under the drawn ones because a 34 pt chip sits in a 44 pt
/// hit area, and gaps beside a quiet button are 11 pt under because its 22 pt line sits in one too.
///
/// The picker half ends in the same 44 pt quiet button as the countdown half ("Not now" where
/// Cancel is), so the two share a bottom edge. Its gaps are sized so that, at standard text sizes,
/// it stands within a few points of the countdown half (8 + 20 + 12 + 44 + 8 + 18 + 16 + 50 + 4 +
/// 44 = 224 against 24 + 86 + 8 + 20 + 28 + 44 = 210); the difference opens between the wait line
/// and Cancel.
enum WaitCardMetrics {
  static let top: CGFloat = 32
  static let inset: CGFloat = 20
  static let numeralTop: CGFloat = 24
  static let numeralToLine: CGFloat = 8
  static let lineToCancel: CGFloat = 28
  static let lineToNaming: CGFloat = 24
  static let hairlineToQuestion: CGFloat = 16
  static let titleToQuestion: CGFloat = 8
  static let questionToChips: CGFloat = 12
  static let noteGap: CGFloat = 8
  static let chipsToAction: CGFloat = 16
  static let noteToButton: CGFloat = 16
  /// Drawn 15 pt from the primary button to the quiet label beneath it.
  static let buttonToQuiet: CGFloat = 4
  static let chipGap: CGFloat = 8
  /// Pulls wrapped rows of 44 pt hit areas together until the chips themselves are `chipGap` apart.
  static let chipLineSpacing: CGFloat = -2
}

/// Lays every subview out in the same frame: as wide as offered and as tall as the tallest one
/// wants. Each subview is then given that full height, so a `Spacer` inside a shorter one opens up
/// and its last view lands on the shared bottom edge. This is what lets the countdown and the
/// session picker trade places without the card changing size.
struct SharedFrame: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    var size = CGSize.zero
    for subview in subviews {
      let fit = subview.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
      size.width = max(size.width, fit.width)
      size.height = max(size.height, fit.height)
    }
    return size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    for subview in subviews {
      subview.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
  }
}
