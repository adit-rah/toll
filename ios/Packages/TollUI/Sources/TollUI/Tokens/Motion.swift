import SwiftUI

/// Design §2.5, the only source of timing in the app. If a transition is not in that table, there is none.
public enum Motion {
  public enum Duration {
    public static let stateChange: TimeInterval = 0.2
    public static let movement: TimeInterval = 0.3
    public static let firstAppearance: TimeInterval = 0.45
    public static let codeRing: TimeInterval = 0.15
    public static let progressFill: TimeInterval = 0.25
    public static let calloutExit: TimeInterval = 0.15
  }

  /// Per-item delays for first-appearance sequences.
  public enum Stagger {
    public static let pickerRows: TimeInterval = 0.04
    public static let weekStrip: TimeInterval = 0.03
    public static let homeRows: TimeInterval = 0.025
    public static let chartBars: TimeInterval = 0.02
  }

  public static var stateChange: Animation { .easeInOut(duration: Duration.stateChange) }
  public static var movement: Animation { .easeInOut(duration: Duration.movement) }
  public static var firstAppearance: Animation { .easeOut(duration: Duration.firstAppearance) }
  public static var codeRing: Animation { .easeInOut(duration: Duration.codeRing) }
  public static var progressFill: Animation { .easeOut(duration: Duration.progressFill) }

  /// The one spring: no overshoot past 2%.
  public static var spring: Animation { .spring(response: 0.35, dampingFraction: 0.85) }

  public static func staggered(
    _ index: Int, step: TimeInterval, duration: TimeInterval = Duration.firstAppearance
  ) -> Animation {
    .easeOut(duration: duration).delay(Double(index) * step)
  }

  /// Pinned and device-state lines slide down from under the hero zone; Reduce Motion fades them.
  public static var pinnedLine: AnyTransition { .move(edge: .top).combined(with: .opacity) }

  /// The wait card leaving as the system switches apps: drops 24 pt and fades.
  public static var waitCardExit: AnyTransition {
    .offset(y: 24).combined(with: .opacity)
  }
}

extension View {
  /// Applies `transition`, or a crossfade of the same timing when Reduce Motion is on.
  public func tollTransition(_ transition: AnyTransition) -> some View {
    modifier(ReducibleTransition(transition: transition))
  }

  /// An offset that Reduce Motion drops; pair it with an opacity change so the crossfade remains.
  public func reducibleOffset(x: CGFloat = 0, y: CGFloat = 0) -> some View {
    modifier(ReducibleOffset(x: x, y: y))
  }

  /// A scale that Reduce Motion drops.
  public func reducibleScale(_ scale: CGFloat, anchor: UnitPoint = .center) -> some View {
    modifier(ReducibleScale(scale: scale, anchor: anchor))
  }

  /// Fades in (and rises `rise` points unless Reduce Motion is on) once, at position `index` of a
  /// staggered sequence. Pass `isActive: false` to show the view in place with no motion.
  public func staggeredAppearance(
    index: Int, step: TimeInterval, rise: CGFloat = 0, isActive: Bool = true
  ) -> some View {
    modifier(StaggeredAppearance(index: index, step: step, rise: rise, isActive: isActive))
  }
}

private struct ReducibleTransition: ViewModifier {
  let transition: AnyTransition
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content.transition(reduceMotion ? .opacity : transition)
  }
}

private struct ReducibleOffset: ViewModifier {
  let x: CGFloat
  let y: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content.offset(x: reduceMotion ? 0 : x, y: reduceMotion ? 0 : y)
  }
}

private struct ReducibleScale: ViewModifier {
  let scale: CGFloat
  let anchor: UnitPoint
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content.scaleEffect(reduceMotion ? 1 : scale, anchor: anchor)
  }
}

private struct StaggeredAppearance: ViewModifier {
  let index: Int
  let step: TimeInterval
  let rise: CGFloat
  let isActive: Bool
  @State private var shown = false

  func body(content: Content) -> some View {
    let visible = shown || !isActive
    content
      .opacity(visible ? 1 : 0)
      .reducibleOffset(y: visible ? 0 : rise)
      .onAppear {
        guard isActive, !shown else { return }
        withAnimation(Motion.staggered(index, step: step)) { shown = true }
      }
  }
}
