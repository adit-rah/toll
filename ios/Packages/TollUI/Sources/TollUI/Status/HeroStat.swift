import SwiftUI
import TollCore

/// Design §3.2. The numeral with the glyph beside it, then the unit line, the subhead line, and an
/// optional caption. A nil value shows "--" while loading: no shimmer, no spinner.
public struct HeroStat: View {
  let value: Int?
  let mark: StatusMark
  let unit: String
  let subhead: String?
  let caption: String?
  let statusSpeech: String?

  /// `unit` is `Copy.Home.passesToday(n)`; `statusSpeech` is the glyph's spoken level.
  public init(
    value: Int?, mark: StatusMark, unit: String, subhead: String? = nil, caption: String? = nil,
    statusSpeech: String? = nil
  ) {
    self.value = value
    self.mark = mark
    self.unit = unit
    self.subhead = subhead
    self.caption = caption
    self.statusSpeech = statusSpeech
  }

  public var body: some View {
    VStack(spacing: 0) {
      HeroNumeral(text: value.map { "\($0)" } ?? "--", mark: mark, showsGlyph: value != nil)
        // The same cap `HeroNumber` puts on itself, so the trim below scales with the numeral.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
      Text(unit).font(TollFont.bodyMedium).foregroundStyle(TollColor.label)
      if let subhead {
        Text(subhead).tollText(.subhead).monospacedDigit()
          .padding(.top, 10)
      }
      if let caption {
        Text(caption).tollText(.caption).monospacedDigit()
          .padding(.top, 2)
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AccessibilitySentence.join([
        value.map { "\($0) \(unit)" }, value == nil ? nil : statusSpeech, subhead, caption,
      ]))
  }
}

/// The numeral on the screen's centre line with the glyph hung off its trailing side. Centring the
/// pair instead would push the numeral 15 pt off the axis that the unit line and the week strip
/// beneath it are centred on.
private struct HeroNumeral: View {
  let text: String
  let mark: StatusMark
  let showsGlyph: Bool
  // A 72 pt line box leaves 17 pt under the baseline for descenders that digits do not have;
  // without the trim the unit line reads as detached from its number.
  @ScaledMetric(relativeTo: .largeTitle) private var descenderTrim: CGFloat = 8

  private static let glyphGap: CGFloat = 10

  var body: some View {
    HeroNumber(text)
      .overlay(alignment: .trailing) {
        StatusGlyph(mark, size: .hero)
          .opacity(showsGlyph ? 1 : 0)
          .alignmentGuide(.trailing) { _ in -Self.glyphGap }
      }
      .padding(.bottom, -descenderTrim)
  }
}

/// Design §3.3. Label above value, with last period small and in `label2`: "11 · 17 last week".
public struct MetricPair: View {
  let label: String
  let value: String
  let previous: String?

  public init(label: String, value: String, previous: String? = nil) {
    self.label = label
    self.value = value
    self.previous = previous
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).tollText(.caption).lineLimit(2)
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        Text(value).font(TollFont.number).foregroundStyle(TollColor.label)
        if let previous {
          Text(Copy.middleDot + previous).tollText(.caption).monospacedDigit()
        }
      }
      .lineLimit(1)
      .minimumScaleFactor(0.8)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(AccessibilitySentence.join([value, previous]))
  }
}
