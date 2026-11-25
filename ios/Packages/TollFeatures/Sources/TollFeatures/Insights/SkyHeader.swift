import SwiftUI
import TollCore
import TollUI
import UIKit

/// Your sleep opens onto the sky (D79): edge to edge and under the status bar, "Your sleep" set on
/// it in the night's light text, last night's moon in the corner, the land along the bottom in the
/// page's colour, and "N nights locked" on the land just under it. A tap near a star opens that
/// night in a system popover, as Tonight's strip does (D75), and brings its figure forward; a tap
/// on the open sky brightens or fades every name (`SkyFocus`). VoiceOver hears the sky as one
/// element, and a double-tap there does what a tap on the open sky does.
struct SkyHeader: View {
  let sleep: YourSleep
  /// The sky's height, a fixed share of the screen at every text size.
  let height: CGFloat
  /// Demo renders open with the names shown or on a star's popover (docs/renders.md).
  var initialFocus: SkyFocus?
  @State private var newestStar: CGFloat
  @State private var newestLines: CGFloat
  @State private var newestLinesShown: CGFloat
  @State private var focus: SkyFocus
  @State private var titleHeight: CGFloat = 43
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase

  static let horizon: CGFloat = 56

  init(sleep: YourSleep, height: CGFloat, initialFocus: SkyFocus? = nil) {
    self.sleep = sleep
    self.height = height
    self.initialFocus = initialFocus
    _focus = State(initialValue: SkyFocus(everything: initialFocus?.everything ?? false))
    let shown: CGFloat = sleep.sky.fadesIn(seen: SkySeen.count) ? 0 : 1
    _newestStar = State(initialValue: shown)
    _newestLines = State(initialValue: shown)
    _newestLinesShown = State(initialValue: shown)
  }

  /// The status bar's height. The title sits just under it, in the bar's empty space: the bar is
  /// see-through over the sky and Your sleep is a tab, with nothing to go back to.
  private var status: CGFloat {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    return (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets.top ?? 54
  }

  /// The stars keep clear of the title above and the land's crest below.
  private var field: EdgeInsets {
    EdgeInsets(
      top: status + titleHeight + 16, leading: 22, bottom: Self.horizon * 0.55, trailing: 22)
  }

  var body: some View {
    let sky = sleep.sky
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topLeading) {
        SkyScene(
          drawing: sky.drawing, light: sky.light, moon: sky.moon,
          moonInset: CGSize(width: 42, height: status + 4 + titleHeight / 2),
          field: field, horizon: Self.horizon, newestStar: newestStar, newestLines: newestLines,
          newestLinesShown: newestLinesShown, focus: $focus,
          night: { index in
            AnyView(
              sleep.starNight(index).map { night in
                StarNightView(night: night)
                  .presentationCompactAdaptation(
                    typeSize.isAccessibilitySize ? .sheet : .popover
                  )
                  .presentationDetents([.medium])
                  .presentationBackground(TollColor.surface)
              })
          }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sky.spoken)
        .accessibilityAddTraits(.isImage)
        // The label already says every name; this is for anyone who also zooms in to see them.
        .accessibilityHint(
          sky.drawing.stars.isEmpty
            ? "" : focus.everything ? Copy.Sky.fadeNames : Copy.Sky.showNames
        )
        .accessibilityAction { focus.tap(star: nil, in: sky.drawing) }
        ScreenTitle(Copy.Tabs.sleep, kind: .pushed)
          .environment(\.colorScheme, .dark)
          .dynamicTypeSize(...DynamicTypeSize.accessibility1)
          .onGeometryChange(for: CGFloat.self) {
            $0.size.height - TollSpacing.pushedTitleGap
          } action: {
            titleHeight = $0
          }
          .padding(.top, status - 4)
          .padding(.horizontal, 24)
          .padding(.trailing, 48)
      }
      .frame(height: height)
      line.tollGutter().padding(.top, 2)
    }
    .onAppear(perform: arrive)
    // Nothing is kept: the names are faint again each time Your sleep appears.
    .onDisappear { focus = SkyFocus() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { focus = SkyFocus() }
    }
    .task {
      guard let star = initialFocus?.star else { return }
      // After the first frame: a popover asked for before the screen is up doesn't show.
      try? await Task.sleep(for: .milliseconds(900))
      focus.star = star
    }
  }

  /// On the land: the moon and the count, with share on a landmark morning; under an empty sky,
  /// its one line. VoiceOver has both in the sky's own label.
  @ViewBuilder private var line: some View {
    if let nights = sleep.nights {
      let count = Text(nights)
        .tollType(.sheetTitle, TollColor.label)
        .fixedSize(horizontal: false, vertical: true)
      // At accessibility sizes the count gets the whole width under the moon and share.
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 14) {
          IconTile(.sleep, size: .large)
          if !typeSize.isAccessibilitySize { count }
          Spacer(minLength: 0)
          if let landmark = sleep.sky.landmark {
            SkyShare(landmark: landmark)
          }
        }
        if typeSize.isAccessibilitySize { count }
      }
      .accessibilityElement(children: .contain)
    } else {
      Text(Copy.Sky.empty)
        .tollType(.body, TollColor.label2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
  }

  /// Last night's star, once: it brightens from nothing, then its lines draw from the stars they
  /// join (design §2.5). With Reduce Motion, one 200 ms crossfade.
  private func arrive() {
    SkySeen.count = sleep.sky.nights
    guard newestStar == 0 else { return }
    if reduceMotion {
      newestLines = 1
      withAnimation(Motion.stateChange) {
        newestStar = 1
        newestLinesShown = 1
      }
      return
    }
    newestLinesShown = 1
    withAnimation(Motion.firstAppearance) {
      newestStar = 1
    } completion: {
      withAnimation(Motion.firstAppearance) { newestLines = 1 }
    }
  }
}

/// A star's night (`YourSleep.starNight`): its date, and when the lock came on and went off.
private struct StarNightView: View {
  let night: YourSleep.StarNight

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Image(symbol: .sleep).unredacted()
          .font(.subheadline.weight(.medium))
          .foregroundStyle(TollColor.accent)
          .accessibilityHidden(true)
        Text(night.day).tollType(.rowTitle, TollColor.label)
      }
      if let locked = night.locked {
        HStack(spacing: 8) {
          Image(symbol: .blocked).unredacted()
            .font(.footnote.weight(.medium))
            .foregroundStyle(TollColor.label2)
            .accessibilityHidden(true)
          Text(locked).tollType(.detail, TollColor.label2)
        }
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, TollSpacing.cardPadding)
    .padding(.vertical, 14)
    .frame(minWidth: 200, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

extension EnvironmentValues {
  /// The names shown, or a star whose night opens in its popover, as the sky appears; set only by
  /// demo renders.
  @Entry var skyDemoFocus: SkyFocus?
}

/// How many nights the sky showed when it was last seen, so the newest star arrives only the first
/// time (design §2.5). This phone's own preference; nothing else reads it.
enum SkySeen {
  private static let key = "dusk.sky.seen"

  static var count: Int {
    get { UserDefaults.standard.integer(forKey: key) }
    set { UserDefaults.standard.set(newValue, forKey: key) }
  }
}
