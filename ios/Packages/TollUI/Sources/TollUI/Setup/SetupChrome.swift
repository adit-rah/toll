import SwiftUI
import UIKit

/// The setup bar: 3 pt segments 6 pt apart (the canvas). Segments before `current` are full; `current` fills left to right
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
        RoundedRectangle(cornerRadius: 2)
          .fill(TollColor.surfaceRaised)
          .overlay(alignment: .leading) {
            GeometryReader { proxy in
              RoundedRectangle(cornerRadius: 2)
                .fill(TollColor.accent)
                .frame(width: fillWidth(index: index, total: proxy.size.width))
                .opacity(fillOpacity(index: index))
            }
          }
          .frame(height: 3)
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

/// A screen's title. Setup titles are 32/38, 28 pt under the bar; pushed screens' titles are 30/35,
/// 8 pt under it (sticky note s1). The gap beneath belongs to the caller.
public struct ScreenTitle: View {
  public enum Kind: Sendable {
    case setup
    case pushed
  }

  let text: String
  let kind: Kind

  public init(_ text: String, kind: Kind = .setup) {
    self.text = text
    self.kind = kind
  }

  public var body: some View {
    Text(text)
      .tollType(kind == .setup ? .setupTitle : .screenTitle, TollColor.label)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, kind == .setup ? TollSpacing.setupTitleGap : TollSpacing.pushedTitleGap)
      .accessibilityAddTraits(.isHeader)
  }
}

extension View {
  /// The bottom of a screen pinned above the home indicator, on the page's colour so scrolled
  /// content ends at it. The main button's bottom edge sits on the safe area, as on every board;
  /// a quiet link under it ("Already bought it? Restore") reaches 16 pt into the indicator's space,
  /// and phones without an indicator keep 16 pt.
  public func tollBottomBar<Bar: View>(
    background: Color = TollColor.bg, endsWithLink: Bool = false,
    @ViewBuilder content: () -> Bar
  ) -> some View {
    let bar = content()
    let indicator = HomeIndicator.present
    let bottom: CGFloat =
      indicator
      ? (endsWithLink ? -16 : 0)
      : TollSpacing.bottomWithoutIndicator
    return safeAreaInset(edge: .bottom, spacing: 0) {
      bar
        .tollGutter()
        .padding(.top, 8)
        .padding(.bottom, bottom)
        .frame(maxWidth: .infinity)
        .background(background)
    }
  }
}

/// Whether this phone has a home indicator (Face ID phones) rather than a Home button.
enum HomeIndicator {
  @MainActor static var present: Bool {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    return (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets.bottom ?? 34 > 0
  }
}

/// Whether a pinned bar keeps only its main button, the rest of it ending the scrolling page: at
/// accessibility sizes, and at the largest size below them on a phone too short for the whole bar
/// (iPhone SE), where it covered more than a quarter of the screen (#162, #178). Keyed on the
/// window, not the room the keyboard leaves, so typing never moves a button.
public enum PinnedBar {
  /// Phones shorter than this (points) are the small ones: the SE is 667, the next is 812.
  static let shortScreen: CGFloat = 700

  @MainActor public static func keepsOnlyMain(_ typeSize: DynamicTypeSize) -> Bool {
    if typeSize.isAccessibilitySize { return true }
    return typeSize >= .xxxLarge && windowHeight < shortScreen
  }

  @MainActor private static var windowHeight: CGFloat {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    return (windows.first(where: \.isKeyWindow) ?? windows.first)?.bounds.height ?? shortScreen
  }
}

extension View {
  /// A pushed screen draws its own title under the bar (`ScreenTitle(kind: .pushed)`); the bar keeps
  /// only Apple's back button. The title still names the screen on the next one's back button.
  public func tollPushed(_ title: String) -> some View {
    navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
        }
        .sharedBackgroundVisibility(.hidden)
      }
  }
}
