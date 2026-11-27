@preconcurrency import DeviceActivity
import SwiftUI
import TollCore
import TollUI

/// Apple's count of screen time after bed last night, in its own row (#65): Screen Time's hourglass
/// and Dusk's words on a raised tile with Apple's 12 pt corners, and the number drawn by the report
/// extension (`ios/Report`). Dusk can't read that number, so nothing compares it with Dusk's own
/// (D46). Self-contained: it reads last night from the environment the tabs set, and shows nothing
/// without Screen Time or a night that has ended.
struct AfterBedRow: View {
  @Environment(\.afterBedNight) private var night
  @ScaledMetric(relativeTo: .body) private var valueHeight: CGFloat = 28
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    if let night {
      // At accessibility sizes the number goes under the words rather than squeezing them.
      let layout =
        typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        : AnyLayout(HStackLayout(spacing: 12))
      layout {
        HStack(spacing: 12) {
          Image(symbol: .screenTime).unredacted()
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(TollColor.label2)
            .frame(width: 20)
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 1) {
            Text(Copy.AfterBed.title).tollType(.rowTitle, TollColor.label)
            Text(Copy.AfterBed.caption).tollType(.detail, TollColor.label2)
          }
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Copy.AfterBed.spoken)
        }
        value(night)
          .frame(
            width: typeSize.isAccessibilitySize ? nil : valueHeight * 2.2, height: valueHeight)
      }
      .padding(.vertical, 12)
      .padding(.horizontal, 14)
      .background(
        TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous))
    }
  }

  /// Apple's view for the night, bed to wake; in a demo render, where the simulator has no Screen
  /// Time data, a placeholder where the number goes.
  @ViewBuilder private func value(_ night: DateInterval) -> some View {
    #if DEBUG
      if DemoScenario.current != nil {
        Text(AfterBed.shown(360).text)
          .tollType(.rowTitle, TollColor.label)
          .redacted(reason: .placeholder)
          .frame(
            maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .trailing
          )
          .accessibilityHidden(true)
      } else {
        report(night)
      }
    #else
      report(night)
    #endif
  }

  private func report(_ night: DateInterval) -> some View {
    DeviceActivityReport(
      DeviceActivityReport.Context(AfterBed.context),
      filter: DeviceActivityFilter(
        segment: .hourly(during: night), users: .all, devices: .init([.iPhone])))
  }
}

extension EnvironmentValues {
  /// Last night, bed to wake, for Apple's report; nil without Screen Time or before a night ends.
  @Entry var afterBedNight: DateInterval?
}
