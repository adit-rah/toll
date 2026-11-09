import SwiftUI
import TollCore

/// Design §3.5 and the device-state line of §4.1. The accent dot is the only accent on Home, so the eye
/// stops here. Insert and remove it with `.tollTransition(Motion.pinnedLine)` inside a
/// `withAnimation(Motion.movement)`.
public struct PinnedRow: View {
  let text: String
  let actionTitle: String?
  let action: (() -> Void)?

  public init(_ text: String) {
    self.text = text
    self.actionTitle = nil
    self.action = nil
  }

  /// A device-state line: "Screen Time is off · Fix", where the trailing word is the button.
  public init(_ text: String, actionTitle: String, action: @escaping () -> Void) {
    self.text = text
    self.actionTitle = actionTitle
    self.action = action
  }

  public var body: some View {
    HStack(alignment: .center, spacing: TollSpacing.rowLeadingGap) {
      Circle()
        .fill(TollColor.accent)
        .frame(width: 8, height: 8)
        .frame(width: TollSpacing.rowLeadingSlot)
        .accessibilityHidden(true)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 0) {
          line
          actionButton
        }
        VStack(alignment: .leading, spacing: 0) {
          Text(text).font(TollFont.bodyMedium).foregroundStyle(TollColor.label)
          actionButton
        }
      }
    }
    .frame(maxWidth: .infinity, minHeight: TollSpacing.rowMinHeight, alignment: .leading)
  }

  private var line: some View {
    HStack(spacing: 0) {
      Text(text)
      if actionTitle != nil {
        Text(Copy.middleDot).accessibilityHidden(true)
      }
    }
    .font(TollFont.bodyMedium)
    .foregroundStyle(TollColor.label)
    .lineLimit(1)
  }

  @ViewBuilder
  private var actionButton: some View {
    if let actionTitle, let action {
      Button(actionTitle, action: action)
        .buttonStyle(QuietButtonStyle())
    }
  }
}
