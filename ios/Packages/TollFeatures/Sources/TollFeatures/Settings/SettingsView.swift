import SwiftUI
import TollCore
import TollData
import TollScreenTime
import TollUI

/// Settings (the canvas's Settings), pushed from Home: is everything working, the app, help, and the
/// log while we test. Three cards of plain rows at the board's heights.
struct SettingsView: View {
  let model: AppModel
  var openPurchase: () -> Void = {}
  @State private var explaining = false
  @State private var nothingToRestore = false
  @State private var restoring = false
  @AppStorage(Appearance.key) private var appearance = Appearance.standard

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Settings.title, kind: .pushed)
        SettingsSection(Copy.Settings.working, top: 16) {
          Card {
            SettingsRow(Copy.Settings.screenTime) {
              PermissionState(text: screenTime.0, tone: screenTime.1)
            }
            SettingsRow(Copy.Settings.location) {
              PermissionState(text: location.0, tone: location.1)
            }
            SettingsRow(Copy.Settings.lastNight, detail: lastNight)
          }
        }
        SettingsSection(Copy.Settings.app) {
          Card {
            NavigationLink(value: HomeRoute.blocks) {
              SettingsRow(Copy.Settings.blocks, detail: blocksSummary)
            }
            .buttonStyle(.plain)
            SettingsRow(Copy.Settings.appearance, minHeight: 50) {
              Picker(Copy.Settings.appearance, selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
              }
              .pickerStyle(.segmented)
              .fixedSize()
              .labelsHidden()
            }
            freeNights
            Button {
              Task { await restore() }
            } label: {
              SettingsRow(Copy.Settings.restore)
            }
            .buttonStyle(.plain)
            .disabled(restoring)
          }
        }
        SettingsSection(Copy.Settings.help) {
          Card {
            Button {
              explaining = true
            } label: {
              SettingsRow(Copy.Settings.howItWorks)
            }
            .buttonStyle(.plain)
            link(AppLinks.privacy) {
              SettingsRow(Copy.Settings.privacy, detail: Copy.Settings.privacyLine)
            }
            if let address = AppLinks.supportAddress {
              link(AppLinks.support) { SettingsRow(Copy.Settings.contact, detail: address) }
            }
            NavigationLink(value: HomeRoute.log) {
              SettingsRow(Copy.Settings.log, detail: Copy.Settings.testingOnly)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .tollGutter()
      .padding(.bottom, 32)
    }
    .background(TollColor.bg)
    .tollPushed(Copy.Settings.title)
    .sheet(isPresented: $explaining) { HowItWorks() }
    .sheet(isPresented: $nothingToRestore) { RestoreNoneSheet() }
  }

  @ViewBuilder private var freeNights: some View {
    if model.state.trial.purchased {
      SettingsRow(Copy.Settings.freeNights, detail: Copy.Settings.purchased)
    } else {
      SettingsRow(
        Copy.Settings.freeNights,
        detail: model.trialNight(now: Date()).map {
          Copy.Settings.nightsUsed($0, of: model.config.trial.nights)
        }
      ) {
        Button(Copy.Settings.once(model.price), action: openPurchase)
          .tollType(.link, TollColor.accent)
          .frame(minHeight: TollSpacing.minTapTarget)
      }
    }
  }

  @ViewBuilder private func link<Content: View>(_ url: URL?, @ViewBuilder content: () -> Content)
    -> some View
  {
    if let url {
      Link(destination: url) { content() }.buttonStyle(.plain)
    } else {
      content()
    }
  }

  private var screenTime: (String, PermissionState.Tone) {
    model.screenTime == .approved ? (Copy.Settings.on, .good) : (Copy.Settings.off, .bad)
  }

  private var location: (String, PermissionState.Tone) {
    switch model.location {
    case .always: (Copy.Settings.always, .good)
    case .whileUsing: (Copy.Settings.whileUsing, .neutral)
    case .approximate: (Copy.Settings.approximate, .neutral)
    case .denied, .notDetermined: (Copy.Settings.off, .neutral)
    }
  }

  private var lastNight: String {
    guard let night = LastNight(log: Array(model.log.reversed())) else {
      return Copy.Settings.notYet
    }
    return Copy.Settings.blocked(Copy.time(night.on), night.off.map { Copy.time($0) })
  }

  private var blocksSummary: String {
    Copy.Settings.blocksSummary(
      blocks: model.state.blocks.count, items: model.state.blocks.map(\.appCount).reduce(0, +),
      max: model.config.blocks.maxApps)
  }

  private func restore() async {
    restoring = true
    defer { restoring = false }
    if !(await model.restore()) { nothingToRestore = true }
  }
}

/// An eyebrow 4 pt in, 8 pt over its card; 14 pt between one card and the next eyebrow.
private struct SettingsSection<Content: View>: View {
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
private struct SettingsRow<Trailing: View>: View {
  let title: String
  let detail: String?
  let minHeight: CGFloat?
  let trailing: Trailing

  init(
    _ title: String, detail: String? = nil, minHeight: CGFloat? = nil,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.title = title
    self.detail = detail
    self.minHeight = minHeight
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: TollSpacing.rowGap) {
      RowText(title: title, detail: detail)
      trailing
    }
    .padding(.vertical, 8)
    .frame(minHeight: minHeight ?? (detail == nil ? 46 : 54))
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

extension SettingsRow where Trailing == EmptyView {
  init(_ title: String, detail: String? = nil, minHeight: CGFloat? = nil) {
    self.init(title, detail: detail, minHeight: minHeight) { EmptyView() }
  }
}

/// How blocking works, as a sheet.
private struct HowItWorks: View {
  var body: some View {
    SheetPage(height: 420) {
      SheetTitle(Copy.Settings.howItWorks)
      ForEach(Copy.Settings.howItWorksLines, id: \.self) { line in
        Text(line)
          .tollType(.sheetBody, TollColor.label)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 12)
      }
    } actions: {
      EmptyView()
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
