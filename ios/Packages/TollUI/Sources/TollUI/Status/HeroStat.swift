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
    VStack(spacing: 4) {
      HStack(alignment: .center, spacing: 12) {
        HeroNumber(value.map { "\($0)" } ?? "--")
        StatusGlyph(mark, size: .hero)
          .opacity(value == nil ? 0 : 1)
      }
      Text(unit).font(TollFont.bodyMedium).foregroundStyle(TollColor.label)
      if let subhead {
        Text(subhead).tollText(.subhead).monospacedDigit()
      }
      if let caption {
        Text(caption).tollText(.caption).monospacedDigit()
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
