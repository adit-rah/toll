import SwiftUI
import TollCore
import TollUI

/// Your sleep's lead under the sky (#88): each measure as a card, its glyph, its value, a chart of
/// the last two weeks and, once there are first nights to compare with, which way it went as a
/// glyph and a plain sentence. Where the numbers come from is said once, under them.
struct SleepTrendsSection: View {
  let trends: SleepTrends
  @Environment(\.askHealth) private var askHealth

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(Copy.Trends.title)
      if trends.isEmpty {
        Footnote(Copy.Trends.empty, symbol: .insights).padding(.top, TollSpacing.headerToCard)
      } else {
        VStack(spacing: 12) {
          ForEach(trends.measures) { TrendCard(measure: $0) }
        }
        .padding(.top, TollSpacing.headerToCard)
        switch trends.source {
        case .health: EmptyView()
        case .healthEmpty:
          Footnote(Copy.Trends.healthEmpty, symbol: .health).padding(.top, 12)
        case .dusk:
          Footnote(Copy.Trends.fromDusk, symbol: .health).padding(.top, 12)
        }
      }
      // A quiet way to Health for someone who skipped it at setup (#86).
      if trends.source == .dusk, let askHealth {
        HealthLink(title: Copy.Trends.addHealth, action: askHealth).padding(.top, 4)
      }
    }
  }
}

/// One measure: what it is, where it is now, the nights behind it, and which way it went.
struct TrendCard: View {
  let measure: SleepTrends.Measure
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      let head =
        typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
        : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
      head {
        IconTile(Self.symbol(measure.kind), size: .row, accent: !measure.standIn)
        VStack(alignment: .leading, spacing: 1) {
          Text(Copy.Trends.name(measure.kind))
            .tollType(.rowTitle, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
          Text(measure.value)
            .tollType(.stat, TollColor.label)
            .contentTransition(.numericText())
          Text(measure.detail)
            .tollType(.detail, TollColor.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      TrendChart(chart: measure.chart).frame(height: 48)
      if let change = measure.change {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          TrendGlyph(way: change.way)
          Text(change.line)
            .tollType(.body, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      if let context = measure.context {
        Text(context)
          .tollType(.detail, TollColor.label2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, TollSpacing.statsCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tollSurface()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel([measure.spoken, measure.context].compactMap { $0 }.joined(separator: " "))
  }

  /// One glyph per measure (design §2.6); Dusk's stand-ins keep the sign of what they stand for
  /// where it's theirs: the phone put down, the nights locked.
  static func symbol(_ kind: SleepTrends.Kind) -> TollSymbol {
    switch kind {
    case .asleepBy: .asleep
    case .timeAsleep: .timeAsleep
    case .steadiness, .phoneSteadiness: .steady
    case .reaches: .reach
    case .phoneDown: .phoneDown
    case .nightsLocked: .blocked
    }
  }
}

/// Which way a measure went: up and right the way it improves, in `ok`; down and right the other
/// way; equal for about the same. The glyph carries it without colour or words.
struct TrendGlyph: View {
  let way: SleepTrends.Way

  var body: some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(way == .toward ? TollColor.ok : TollColor.label2)
      .accessibilityHidden(true)
  }

  private var symbol: TollSymbol {
    switch way {
    case .toward: .trendToward
    case .away: .trendAway
    case .steady: .trendSame
    }
  }
}

/// A link that acts carries its glyph (design §2.6): Apple Health's, in the accent.
struct HealthLink: View {
  let title: String
  let action: @MainActor @Sendable () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(symbol: .health).unredacted().accessibilityHidden(true)
        Text(title).fixedSize(horizontal: false, vertical: true)
      }
      .frame(minHeight: TollSpacing.minTapTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.tollPressable)
    .tollType(.link, TollColor.accent)
  }
}

extension EnvironmentValues {
  /// "See how you slept" and "Add your sleep from Apple Health" (#86): iOS's sheet for Health, then
  /// the nights it has. Nil in demo renders, where it does nothing.
  @Entry var askHealth: (@MainActor @Sendable () -> Void)?
}
