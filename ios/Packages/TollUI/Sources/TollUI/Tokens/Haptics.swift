import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// The only three haptics in Toll (design §2.5). No haptic on a pass being granted.
public enum Haptic: Sendable {
  /// A wait starts or ends.
  case light
  /// Confirming a removal or blocking a person.
  case warning
  /// When tiles and tag chips.
  case selection

  public var feedback: SensoryFeedback {
    switch self {
    case .light: .impact(weight: .light)
    case .warning: .warning
    case .selection: .selection
    }
  }

  /// For moments a view's state does not capture, such as a confirmation dialog's action.
  @MainActor
  public func play() {
    #if canImport(UIKit)
      switch self {
      case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
      case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
      case .selection: UISelectionFeedbackGenerator().selectionChanged()
      }
    #endif
  }
}

extension View {
  public func tollHaptic(_ haptic: Haptic, trigger: some Equatable) -> some View {
    sensoryFeedback(haptic.feedback, trigger: trigger)
  }
}
