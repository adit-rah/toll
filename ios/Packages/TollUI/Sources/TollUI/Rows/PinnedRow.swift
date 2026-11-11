import SwiftUI
import TollCore

/// Design §3.5 and the device-state line of §4.1. The accent dot is the only accent on Home, so the eye
/// stops here. Insert and remove it with `.tollTransition(Motion.pinnedLine)` inside a
/// `withAnimation(Motion.movement)`.
public struct PinnedRow: View {
  let text: String
  let actionTitle: String?
  let action: (() -> Void)?
  // Half the cap height of `body`: where the dot's centre sits above the first line's baseline.
  @ScaledMetric(relativeTo: .body) private var dotRise: CGFloat = 6

  private static let dotSize: CGFloat = 8

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
    Group {
      if let actionTitle, let action {
        HStack(alignment: .center, spacing: TollSpacing.rowLeadingGap) {
          dot
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
              message.lineLimit(1)
              Text(Copy.middleDot).font(TollFont.bodyMedium).foregroundStyle(TollColor.label)
                .accessibilityHidden(true)
              actionButton(actionTitle, action)
            }
            VStack(alignment: .leading, spacing: 0) {
              message
              actionButton(actionTitle, action)
            }
          }
        }
      } else {
        // A pinned sentence often wraps; the dot stays beside its first line like a bullet
        // instead of drifting to the middle of the block.
        HStack(alignment: .firstTextBaseline, spacing: TollSpacing.rowLeadingGap) {
          dot.alignmentGuide(.firstTextBaseline) { dimensions in dimensions.height / 2 + dotRise }
          message
        }
        .padding(.vertical, TollSpacing.grid)
      }
    }
    .frame(maxWidth: .infinity, minHeight: TollSpacing.rowMinHeight, alignment: .leading)
  }

  private var dot: some View {
    Circle()
      .fill(TollColor.accent)
      .frame(width: Self.dotSize, height: Self.dotSize)
      .frame(width: TollSpacing.rowLeadingSlot)
      .accessibilityHidden(true)
  }

  private var message: some View {
    Text(text)
      .font(TollFont.bodyMedium)
      .foregroundStyle(TollColor.label)
      .multilineTextAlignment(.leading)
  }

  private func actionButton(_ title: String, _ action: @escaping () -> Void) -> some View {
    Button(title, action: action)
      .buttonStyle(InlineActionStyle())
  }
}

/// `QuietButton`'s look, but the 44 pt hit area grows toward the trailing side only, so the word
/// sits flush against the middle dot before it rather than centred in a wider box.
private struct InlineActionStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TollFont.bodyMedium)
      .foregroundStyle(TollColor.accent)
      .frame(
        minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget,
        alignment: .leading
      )
      .contentShape(Rectangle())
      .opacity(configuration.isPressed ? 0.5 : 1)
  }
}
