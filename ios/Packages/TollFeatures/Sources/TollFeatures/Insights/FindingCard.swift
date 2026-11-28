import SwiftUI
import TollCore
import TollUI

/// The sleep model's insight (#189), the one result Dusk earns: personal timing's glyph, how much
/// sooner or later asleep with its way as a glyph, the sentence that says why, and the range and
/// nights under it. It leads Your sleep under the sky, above the measures, and is the one card with
/// a stat that has no chart.
struct FindingCard: View {
  let finding: YourSleep.Finding
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let head =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
      : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
    head {
      IconTile(.timing, size: .row)
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          // Sooner reads as Asleep by's earlier does (D104): the same glyph, never colour alone.
          TrendGlyph(way: finding.sooner ? .toward : .away)
          Text(finding.value)
            .tollType(.stat, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text(finding.line)
          .tollType(.body, TollColor.label)
          .fixedSize(horizontal: false, vertical: true)
        Text(finding.detail)
          .tollType(.detail, TollColor.label2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, TollSpacing.statsCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tollSurface()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(finding.spoken)
  }
}
