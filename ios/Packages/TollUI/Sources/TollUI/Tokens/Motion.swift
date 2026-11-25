import SwiftUI

/// Design §2.5, the only source of timing in the app. If a transition is not in that table, there is none.
public enum Motion {
  public enum Duration {
    public static let stateChange: TimeInterval = 0.2
    public static let movement: TimeInterval = 0.3
    public static let firstAppearance: TimeInterval = 0.45
    public static let progressFill: TimeInterval = 0.25
  }

  /// Rows returning from the system picker (design §2.5).
  public enum PickerRows {
    public static let stagger: TimeInterval = 0.04
    public static let rise: CGFloat = 6
  }

  // Every curve is a critically damped spring with no bounce, at the table's perceived durations:
  // it starts at once, never overshoots, and a change mid-way retargets from where things are and
  // how fast they move, instead of restarting.
  public static var stateChange: Animation { .smooth(duration: Duration.stateChange) }
  public static var movement: Animation { .smooth(duration: Duration.movement) }
  public static var firstAppearance: Animation { .smooth(duration: Duration.firstAppearance) }
  public static var progressFill: Animation { .smooth(duration: Duration.progressFill) }

  /// Content that arrives as its container grows (last night's card): it fades in once the card
  /// has grown for 100 ms, so the words never sit outside it.
  public static var contentIn: Animation {
    stateChange.delay(Duration.movement - Duration.stateChange)
  }

  /// Content that leaves as its container shrinks: it fades at once, before the edge reaches it.
  public static var contentOut: Animation { stateChange }

  /// One page of a sheet giving way to the next in place (the pause, the purchase, Before bed): the
  /// old fades at once and the new comes in after the first 100 ms, so the two sets of words
  /// barely overlap, and the whole swap still takes `movement`.
  public static var pageSwap: AnyTransition {
    .asymmetric(insertion: .opacity.animation(contentIn), removal: .opacity.animation(contentOut))
  }

  public static func staggered(
    _ index: Int, step: TimeInterval, duration: TimeInterval = Duration.firstAppearance
  ) -> Animation {
    .smooth(duration: duration).delay(Double(index) * step)
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
