import SwiftUI
import TollCore
import TollUI

/// Your sleep, the second tab (D63): it opens onto Your sky (D79), then how the person's nights
/// are changing (#88), then this week as dots and a personal best when there is one (#103), then
/// everything from the log on this phone.
struct InsightsView: View {
  let sleep: YourSleep
  /// Demo renders open with the names shown or on a star's night (docs/renders.md).
  @Environment(\.skyDemoFocus) private var initialFocus
  @State private var range = InsightsSnapshot.Range.month
  /// Whether the sky has scrolled up under the bar; the bar takes the page's colour then.
  @State private var skyGone = false

  var body: some View {
    let insights = InsightsSnapshot(
      nights: sleep.past, hours: sleep.hours, now: sleep.now, calendar: .current, range: range)
    GeometryReader { proxy in
      let top = proxy.safeAreaInsets.top
      // About the top 45% of the screen, at every text size: the text below it scales instead.
      let sky = ((proxy.size.height + top + proxy.safeAreaInsets.bottom) * 0.45).rounded()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          SkyHeader(sleep: sleep, height: sky, initialFocus: initialFocus)
          VStack(alignment: .leading, spacing: 0) {
            // The person's improvement leads (#85, #88); what Dusk did follows as context.
            SleepTrendsSection(trends: sleep.trends).padding(.top, 28)
            SectionHeader(sleep.weekTitle).padding(.top, 28)
            WeekDotsCard(sleep: sleep).padding(.top, TollSpacing.headerToCard)
            if let best = sleep.best {
              BestCard(best: best).padding(.top, 12)
            }
            AfterBedRow().padding(.top, 12)
            // The night as it's planned, three parts: before sleep, sleep, after waking (#144).
            if let plan = sleep.plan {
              SectionHeader(Copy.Fit.aroundTitle).padding(.top, 28)
              NightPictureView(picture: plan)
                .padding(.vertical, TollSpacing.statsCardVertical)
                .padding(.horizontal, TollSpacing.cardPadding)
                .tollSurface()
                .padding(.top, TollSpacing.headerToCard)
            }
            // Design §2.5: a new range changes only its own numbers and chart, never the sky.
            VStack(alignment: .leading, spacing: 0) { ranges(insights) }
              .animation(Motion.stateChange, value: range)
          }
          .tollGutter()
          .padding(.bottom, 32)
        }
      }
      .onScrollGeometryChange(for: Bool.self) { geometry in
        geometry.contentOffset.y > sky - top
      } action: { _, gone in
        skyGone = gone
      }
      // No edge effect over the night; the bar's own colour takes over once the sky has gone.
      .scrollEdgeEffectHidden(!skyGone, for: .top)
      .ignoresSafeArea(.container, edges: .top)
    }
    .background(TollColor.bg)
    .tollPushed(Copy.Tabs.sleep)
    // The bar is see-through over the night, with light text over it in both appearances.
    .toolbarBackground(skyGone ? TollColor.bg : Color.clear, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarColorScheme(skyGone ? nil : .dark, for: .navigationBar)
  }

  @ViewBuilder private func ranges(_ insights: InsightsSnapshot) -> some View {
    SectionHeader(Copy.Insights.overTime).padding(.top, 28)
    Picker(Copy.Insights.range, selection: $range) {
      Text(Copy.Insights.week).tag(InsightsSnapshot.Range.week)
      Text(Copy.Insights.month).tag(InsightsSnapshot.Range.month)
      Text(Copy.Insights.all).tag(InsightsSnapshot.Range.all)
    }
    .pickerStyle(.segmented)
    .padding(.top, TollSpacing.headerToCard)
    if insights.isEmpty {
      Footnote(Copy.Insights.empty).padding(.top, 20)
    } else {
      // The nights are counted once, at the top; this is the range's one number.
      Stat(
        value: Copy.Insights.hours(insights.hoursBlocked), label: Copy.Insights.hoursLabel,
        symbol: .blocked
      )
      .padding(.top, 20)
      // No row of empty bars: a range without taps shows only its hours (D65).
      if insights.taps > 0 {
        HoursCard(insights: insights).padding(.top, 20)
      }
    }
  }
}

/// A card with a 15 pt semibold title (the canvas's Insights cards).
private struct InsightCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).tollType(.link, TollColor.label).accessibilityAddTraits(.isHeader)
      content
    }
    .padding(TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tollSurface()
  }
}

/// When you chose sleep, by hour of the night's own hours (48 pt at most), the busiest in amber.
private struct HoursCard: View {
  let insights: InsightsSnapshot

  var body: some View {
    InsightCard(title: Copy.Insights.when) {
      let top = max(1, insights.byHour.max() ?? 1)
      HStack(alignment: .bottom, spacing: 6) {
        ForEach(Array(insights.byHour.enumerated()), id: \.offset) { _, count in
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(count == top && count > 0 ? TollColor.accent : TollColor.bar)
            .frame(height: max(5, 48 * CGFloat(count) / CGFloat(top)))
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 48, alignment: .bottom)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        Copy.Insights.chartSpoken(
          peak: insights.peakHour.map { Copy.Insights.hourName($0) }, total: insights.taps))
      HStack {
        Text(Copy.time(ClockTime(hour: insights.hours.first), short: true))
        Spacer(minLength: 4)
        if let peak = insights.peakHour {
          Text(Copy.Insights.mostAt(Copy.Insights.hourName(peak)))
        }
        Spacer(minLength: 4)
        Text(Copy.time(ClockTime(hour: insights.hours.last), short: true))
      }
      .accessibilityHidden(true)
      .tollType(.micro, TollColor.label2)
      .padding(.top, -4)
      .tollChartTypeLimit()
    }
  }
}
