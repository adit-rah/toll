import SwiftUI

/// The setup bar: 2 or 4 segments. Segments before `current` are full; `current` fills left to right
/// over 250 ms as its screen lands (design §2.5). Keep one instance across the setup steps so moving
/// back and forth animates the change.
public struct ProgressSegments: View {
  let count: Int
  let current: Int
  let accessibilityText: String?
  @State private var filled: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// `current` is zero-based. `accessibilityLabel` is the spoken step ("Step 2 of 4").
  public init(count: Int, current: Int, accessibilityLabel: String? = nil) {
    let segments = max(1, count)
    let clamped = min(max(0, current), segments - 1)
    self.count = segments
    self.current = clamped
    self.accessibilityText = accessibilityLabel
    _filled = State(initialValue: clamped)
  }

  public var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<count, id: \.self) { index in
        Capsule()
          .fill(TollColor.surfaceRaised)
          .overlay(alignment: .leading) {
            GeometryReader { proxy in
              Capsule()
                .fill(TollColor.accent)
                .frame(width: fillWidth(index: index, total: proxy.size.width))
                .opacity(fillOpacity(index: index))
            }
          }
          .frame(height: 4)
      }
    }
    .frame(maxWidth: .infinity)
    .onAppear {
      withAnimation(Motion.progressFill) { filled = current + 1 }
    }
    .onChange(of: current) { _, newValue in
      withAnimation(Motion.progressFill) { filled = newValue + 1 }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText ?? "")
    .accessibilityHidden(accessibilityText == nil)
  }

  // Reduce Motion: the segment is full width from the start and fades in instead of growing.
  private func fillWidth(index: Int, total: CGFloat) -> CGFloat {
    if reduceMotion { return index <= current ? total : 0 }
    return index < filled ? total : 0
  }

  private func fillOpacity(index: Int) -> Double {
    guard reduceMotion else { return 1 }
    return index < filled ? 1 : 0
  }
}

/// A setup or sign-in title: 34 pt semibold, 28 pt under the 44 pt bar (design §4.3). The gap beneath
/// belongs to the caller, so a subtitle can sit closer than a field does.
public struct ScreenTitle: View {
  let text: String

  public init(_ text: String) {
    self.text = text
  }

  public var body: some View {
    Text(text)
      .font(TollFont.screenTitle)
      .foregroundStyle(TollColor.label)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, TollSpacing.titleGap)
      .accessibilityAddTraits(.isHeader)
  }
}

extension View {
  /// A bottom action pinned above the safe area, on the page's own colour so scrolled content ends
  /// cleanly at it instead of showing through around the button.
  public func tollBottomBar<Bar: View>(
    background: Color = TollColor.bgGrouped, @ViewBuilder content: () -> Bar
  ) -> some View {
    let bar = content()
    return safeAreaInset(edge: .bottom, spacing: 0) {
      bar
        .tollGutter()
        .padding(.top, TollSpacing.labelGap)
        .padding(.bottom, TollSpacing.footerBottom)
        .frame(maxWidth: .infinity)
        .background(background)
    }
  }
}
