import SwiftUI
import TollCore
import TollUI

/// "23 nights" beside the moon, under Your sky: one star for each of those nights (D65, D79). A
/// count that only goes up. On a landmark morning the picture can be shared, and only then.
struct NightsCard: View {
  let nights: String
  let sky: Sky
  /// Hidden until the sky appears when last night's star hasn't been seen yet, then faded in once.
  @State private var newestShown: Bool

  init(nights: String, sky: Sky) {
    self.nights = nights
    self.sky = sky
    _newestShown = State(initialValue: !sky.fadesIn(seen: SkySeen.count))
  }

  var body: some View {
    // The sky runs to the card's edges, like a picture, with the number under it.
    VStack(alignment: .leading, spacing: 0) {
      SkyCanvas(drawing: sky.drawing, newestShown: newestShown, corner: 0)
      HStack(spacing: 14) {
        HStack(spacing: 14) {
          IconTile(.sleep, size: .large)
          Text(nights)
            .tollType(.sheetTitle, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sky.spoken)
        Spacer(minLength: 0)
        if let landmark = sky.landmark {
          SkyShare(landmark: landmark)
        }
      }
      .padding(TollSpacing.cardPadding)
    }
    .background(TollColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
    .onAppear {
      SkySeen.count = sky.nights
      guard !newestShown else { return }
      withAnimation(Motion.stateChange) { newestShown = true }
    }
  }
}

/// How many nights the sky showed when it was last seen, so the newest star fades in only the
/// first time (design §2.5). This phone's own preference; nothing else reads it.
enum SkySeen {
  private static let key = "dusk.sky.seen"

  static var count: Int {
    get { UserDefaults.standard.integer(forKey: key) }
    set { UserDefaults.standard.set(newValue, forKey: key) }
  }
}

/// This week as seven dots; on a new week, last week in one line above seven empty ones (#103).
struct WeekDotsCard: View {
  let sleep: YourSleep

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let lastWeek = sleep.lastWeek {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(symbol: .sleep).unredacted()
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(TollColor.label2)
            .accessibilityHidden(true)
          Text(lastWeek)
            .tollType(.rowTitle, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
      }
      NightDots(bars: sleep.dots)
    }
    .padding(.vertical, TollSpacing.statsCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// A personal best, only when it's true and better than the person's own past (D65): a fact and
/// what it's measured against, never praise.
struct BestCard: View {
  let best: YourSleep.Best

  var body: some View {
    HStack(spacing: 14) {
      IconTile(.best, size: .large)
      RowText(title: best.title, detail: best.detail)
      Spacer(minLength: 0)
    }
    .padding(TollSpacing.cardPadding)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
    )
    .accessibilityElement(children: .combine)
  }
}
