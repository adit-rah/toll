import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// The only three haptics (design §2.5).
public enum Haptic: Sendable {
  /// The door's wait starts or ends.
  case light
  /// Confirming something that cannot be undone.
  case warning
  /// A picker value changes.
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

/// Imperative spellings for view models (`Haptics.light()`), so the three stay the only three.
public enum Haptics {
  @MainActor public static func light() { Haptic.light.play() }
  @MainActor public static func warning() { Haptic.warning.play() }
  @MainActor public static func selection() { Haptic.selection.play() }
}

extension View {
  public func tollHaptic(_ haptic: Haptic, trigger: some Equatable) -> some View {
    sensoryFeedback(haptic.feedback, trigger: trigger)
  }
}
