@preconcurrency import DeviceActivity
import SwiftUI
import TollCore
import TollScreenTime

/// Draws the "Screen time" fact on Home (design §4.1, ledger A126). The minutes never leave this
/// extension: iOS shows its view inside Toll, and Toll cannot read what it draws (spec §6).
@main
struct ScreenTimeReportExtension: DeviceActivityReportExtension {
  var body: some DeviceActivityReportScene {
    ScreenTimeScene { total in ScreenTimeValue(text: total) }
  }
}

struct ScreenTimeScene: DeviceActivityReportScene {
  let context = DeviceActivityReport.Context(ReportContext.screenTime)
  let content: (String) -> ScreenTimeValue

  func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async
    -> String
  {
    let seconds = await data.flatMap { $0.activitySegments }
      .reduce(0) { $0 + $1.totalActivityDuration }
    return Copy.duration(seconds)
  }
}

/// The value line of a Home fact: `number` (body, medium, tabular), centred in its column.
struct ScreenTimeValue: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.body.weight(.medium).monospacedDigit())
      .foregroundStyle(.primary)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .frame(maxWidth: .infinity)
  }
}
