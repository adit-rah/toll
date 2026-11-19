import SwiftUI
import TollCore
import TollUI

/// Home, in every state (the design canvas): what tonight holds, the week, the blocks. Laid out from a
/// `HomeSnapshot`; nothing here decides anything.
struct HomeView: View {
  let home: HomeSnapshot
  let price: String
  let openSettings: () -> Void
  let openDoor: () -> Void
  let openPurchase: () -> Void
  let fixLocation: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        topBar
        HomeHero(hero: home.hero).padding(.top, 20)
        if let left = home.unlocksLeft {
          UnlockRow(left: left, open: openDoor).padding(.top, 20)
        }
        if home.hero == .paused {
          PausedCard(price: price, open: openPurchase).padding(.top, 20)
        }
        if home.locationBanner {
          LocationBanner(fix: fixLocation).padding(.top, 20)
        }
        if let timeline = home.timeline {
          TimelineStrip(timeline: timeline).padding(.top, 20)
        }
        SectionHeader(Copy.Home.thisWeek).padding(.top, 30)
        WeekCard(home: home).padding(.top, 12)
        SectionHeader(Copy.Home.blocks).padding(.top, 26)
        BlockList(rows: home.blocks).padding(.top, 10)
      }
      .tollGutter()
      .padding(.bottom, TollSpacing.sectionGap)
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: home.hero)
  }

  private var topBar: some View {
    HStack {
      if let pill = home.pill {
        if pill.opensPurchase {
          Button(action: openPurchase) { PillLabel(text: pill.text, accent: true) }
        } else {
          PillLabel(text: pill.text, accent: false)
        }
      }
      Spacer()
      Button(action: openSettings) {
        Image(systemName: "gearshape")
          .font(.title3)
          .foregroundStyle(TollColor.label2)
          .frame(width: TollSpacing.minTapTarget, height: TollSpacing.minTapTarget)
      }
      .accessibilityLabel(Copy.Home.settings)
    }
    .frame(minHeight: TollSpacing.minTapTarget)
  }
}

private struct PillLabel: View {
  let text: String
  let accent: Bool

  var body: some View {
    Text(text)
      .font(TollFont.captionMedium)
      .monospacedDigit()
      .foregroundStyle(accent ? TollColor.accent : TollColor.label2)
      .padding(.horizontal, 14)
      .frame(minHeight: 32)
      .background(TollColor.surface, in: Capsule())
  }
}

/// The state, in one big time and two small lines.
struct HomeHero: View {
  let hero: HomeSnapshot.Hero

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(TollFont.captionMedium).foregroundStyle(TollColor.label2)
      if let time {
        BigTime(date: time)
      } else {
        Text(title).font(TollFont.screenTitle).foregroundStyle(TollColor.label)
      }
      Text(detail).font(TollFont.subhead).foregroundStyle(TollColor.label2).monospacedDigit()
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  private var label: String {
    switch hero {
    case .tonight: Copy.Home.tonight
    case .blocked(let label, _, _): label
    case .away: Copy.Home.awayLabel
    case .paused, .noBlocks: ""
    }
  }

  private var time: Date? {
    switch hero {
    case .tonight(let start, _): start
    case .blocked(_, let until, _): until
    case .away(let start): start
    case .paused, .noBlocks: nil
    }
  }

  private var title: String { hero == .paused ? Copy.Home.paused : Copy.Home.noBlocks }

  private var detail: String {
    switch hero {
    case .tonight(_, let detail), .blocked(_, _, let detail): detail
    case .away: Copy.Home.startsWhenHome
    case .paused: "\(Copy.Home.notBlocking) · \(Copy.Home.trialEnded)"
    case .noBlocks: ""
    }
  }
}

/// "10:30 pm" with the time large and the am/pm small (the canvas).
private struct BigTime: View {
  let date: Date
  @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 64

  var body: some View {
    let style = Date.FormatStyle(date: .omitted, time: .shortened)
    let parts = date.formatted(style).split(separator: " ", maxSplits: 1)
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Text(String(parts.first ?? ""))
        .font(.system(size: min(size, 96), weight: .semibold).monospacedDigit())
        .minimumScaleFactor(0.6)
        .lineLimit(1)
      if parts.count > 1 {
        Text(String(parts[1])).font(.title2.weight(.medium)).foregroundStyle(TollColor.label2)
      }
    }
    .foregroundStyle(TollColor.label)
  }
}
