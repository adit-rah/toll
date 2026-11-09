import SwiftUI

/// Design §3.13. One line and at most one quiet action. No illustration.
public struct EmptyState: View {
  let message: String
  let actionTitle: String?
  let action: (() -> Void)?

  public init(_ message: String) {
    self.message = message
    self.actionTitle = nil
    self.action = nil
  }

  public init(_ message: String, actionTitle: String, action: @escaping () -> Void) {
    self.message = message
    self.actionTitle = actionTitle
    self.action = action
  }

  public var body: some View {
    VStack(spacing: 4) {
      Text(message)
        .font(TollFont.body)
        .foregroundStyle(TollColor.label2)
        .multilineTextAlignment(.center)
      if let actionTitle, let action {
        QuietButton(actionTitle, action: action)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, TollSpacing.sectionGap)
  }
}
