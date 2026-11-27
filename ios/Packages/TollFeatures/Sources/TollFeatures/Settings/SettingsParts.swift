import SwiftUI
import TollCore
import TollUI

/// An eyebrow 4 pt in, 8 pt over its card; 14 pt between one card and the next eyebrow.
struct SettingsSection<Content: View>: View {
  let title: String
  var top: CGFloat = 14
  @ViewBuilder let content: Content

  init(_ title: String, top: CGFloat = 14, @ViewBuilder content: () -> Content) {
    self.title = title
    self.top = top
    self.content = content()
  }

  var body: some View {
    Text(title)
      .tollType(.eyebrow, TollColor.label2)
      .padding(.horizontal, 4)
      .padding(.top, top)
      .accessibilityAddTraits(.isHeader)
    content.padding(.top, 8)
  }
}

/// A plain row: 46 pt for one line, 54 pt with a detail, and whatever sits at its end.
struct SettingsRow<Trailing: View>: View {
  let title: String
  let detail: String?
  let minHeight: CGFloat?
  /// A small trailing glyph (a chevron, the leaves-the-app arrow) stays beside the title at
  /// accessibility sizes instead of sitting alone on a line of its own (the audit).
  let glyph: Bool
  /// What the row is about, as a tile before it (#79): the wordless test reads a list of rows by
  /// their tiles, so "Is everything working?" names each thing it checks.
  let symbol: TollSymbol?
  let trailing: Trailing

  init(
    _ title: String, detail: String? = nil, minHeight: CGFloat? = nil, glyph: Bool = false,
    symbol: TollSymbol? = nil, @ViewBuilder trailing: () -> Trailing
  ) {
    self.title = title
    self.detail = detail
    self.minHeight = minHeight
    self.glyph = glyph
    self.symbol = symbol
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: TollSpacing.rowGap) {
      if let symbol { IconTile(symbol, accent: false) }
      if glyph {
        HStack(spacing: TollSpacing.rowGap) {
          RowText(title: title, detail: detail)
          trailing
        }
      } else {
        AdaptiveStack(spacing: TollSpacing.rowGap) {
          RowText(title: title, detail: detail)
          trailing
        }
      }
    }
    .padding(.vertical, 8)
    .frame(minHeight: minHeight ?? (symbol != nil ? 60 : detail == nil ? 46 : 54))
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

extension SettingsRow where Trailing == EmptyView {
  init(
    _ title: String, detail: String? = nil, minHeight: CGFloat? = nil, symbol: TollSymbol? = nil
  ) {
    self.init(title, detail: detail, minHeight: minHeight, symbol: symbol) { EmptyView() }
  }
}

/// Dark · Light · Match iPhone as the board draws it: 13 pt segments in a 32 pt track, the chosen
/// one raised. Apple's segmented control is too wide to sit beside the row's title.
struct AppearancePicker: View {
  @Binding var selection: Appearance

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Appearance.allCases) { option in
        let chosen = option == selection
        Button {
          selection = option
        } label: {
          Text(option.title)
            .tollType(
              TollType(
                size: 13, lineHeight: 18, weight: chosen ? .semibold : .medium, style: .footnote)
            )
            .foregroundStyle(chosen ? TollColor.label : TollColor.label2)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity)
            .background(
              chosen ? TollColor.surface : .clear,
              in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
      }
    }
    .padding(2)
    .frame(height: 32)
    .background(TollColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    .fixedSize(horizontal: true, vertical: false)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    .tollHaptic(.selection, trigger: selection)
  }
}

/// How it works, as a sheet, with a button to close it: a swipe isn't the only way out (the audit).
struct HowItWorks: View {
  let config: TollConfig
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    // Five paragraphs since the buffers' line (#127): tall enough that the last isn't under Done.
    SheetPage(height: 610) {
      SheetTitle(Copy.Settings.howItWorks)
      ForEach(Copy.Settings.howItWorksLines(config), id: \.self) { line in
        Text(line)
          .tollType(.sheetBody, TollColor.label)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 12)
      }
    } actions: {
      PrimaryButton(Copy.Setup.done) { dismiss() }
    }
  }
}

/// Where the policy and support live, from Info.plist so they change without a code edit.
enum AppLinks {
  static var privacy: URL? { string("TollPrivacyURL").flatMap(URL.init(string:)) }
  static var supportAddress: String? { string("TollSupportEmail") }
  static var support: URL? { supportAddress.flatMap { URL(string: "mailto:\($0)") } }
  static var version: String {
    "\(string("CFBundleShortVersionString") ?? "?") (\(string("CFBundleVersion") ?? "?"))"
  }

  private static func string(_ key: String) -> String? {
    (Bundle.main.object(forInfoDictionaryKey: key) as? String).flatMap { $0.isEmpty ? nil : $0 }
  }
}
