@preconcurrency import DeviceActivity
import SwiftUI
import TollCore

/// Draws Apple's count of screen time after bed in Dusk's row (#65). iOS shows this view inside the
/// app and the minutes never leave the extension: Dusk can't read them, so they are never compared
/// with its own numbers or used in a rule. TollCore only, for the words and the format.
@main
struct AfterBedReportExtension: DeviceActivityReportExtension {
  var body: some DeviceActivityReportScene {
    AfterBedScene { AfterBedValue(shown: $0) }
  }
}

/// The minutes as shown and as spoken.
struct AfterBedShown: Sendable {
  let text: String
  let spoken: String
}

/// Nonisolated: iOS hands the results over off the main actor, and adding them up needs no UI.
nonisolated struct AfterBedScene: DeviceActivityReportScene {
  let context = DeviceActivityReport.Context(AfterBed.context)
  let content: (AfterBedShown) -> AfterBedValue

  /// Every segment of the interval the app asked for (last night, bed to wake), added up.
  func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async
    -> AfterBedShown
  {
    let seconds = await data.flatMap { $0.activitySegments }
      .reduce(0) { $0 + $1.totalActivityDuration }
    let shown = AfterBed.shown(seconds)
    return AfterBedShown(text: shown.text, spoken: shown.spoken)
  }
}

/// The number at the row's end, in the system's type so it scales with Dynamic Type.
struct AfterBedValue: View {
  let shown: AfterBedShown

  var body: some View {
    Text(shown.text)
      .font(.body.weight(.semibold).monospacedDigit())
      .foregroundStyle(.primary)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
      .accessibilityLabel(shown.spoken)
  }
}
