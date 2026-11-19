import SwiftUI
import TollCore
import TollData
import TollScreenTime
import TollUI

/// Settings (the design canvas): is everything working, the week and the purchase, blocks, how it
/// looks, help, privacy, contact; the log while we test.
struct SettingsView: View {
  let model: AppModel
  var openPurchase: (() -> Void)?
  @Environment(\.dismiss) private var dismiss
  @State private var restoreNote: String?
  @State private var explaining = false
  @AppStorage(Appearance.key) private var appearance = Appearance.standard

  var body: some View {
    NavigationStack {
      List {
        Section(Copy.Settings.working) {
          LabeledContent(Copy.Settings.screenTime, value: screenTime)
          LabeledContent(Copy.Settings.location, value: location)
          LabeledContent(Copy.Settings.lastNight, value: lastNight)
        }
        .listRowBackground(TollColor.surface)
        Section(Copy.Settings.yourWeek) {
          if model.state.trial.purchased {
            LabeledContent(Copy.Settings.freeNights, value: Copy.Settings.purchased)
          } else {
            if let night = model.trialNight(now: Date()) {
              LabeledContent(
                Copy.Settings.freeNights,
                value: Copy.Settings.nightsUsed(night, of: model.config.trial.nights))
            }
            if let openPurchase {
              Button(Copy.Settings.keepIt) {
                dismiss()
                openPurchase()
              }
            }
          }
          Button(Copy.Settings.restore) { Task { await restore() } }
          if let restoreNote { Text(restoreNote).tollText(.subhead) }
        }
        .listRowBackground(TollColor.surface)
        Section {
          NavigationLink(Copy.Settings.blocks) { BlocksView(model: model) }
          Picker(Copy.Settings.appearance, selection: $appearance) {
            ForEach(Appearance.allCases) { Text($0.title).tag($0) }
          }
        }
        .listRowBackground(TollColor.surface)
        Section(Copy.Settings.help) {
          Button(Copy.Settings.howItWorks) { explaining = true }
          if let url = AppLinks.privacy {
            Link(destination: url) {
              LabeledContent(Copy.Settings.privacy, value: Copy.Settings.privacyLine)
            }
          } else {
            LabeledContent(Copy.Settings.privacy, value: Copy.Settings.privacyLine)
          }
          if let url = AppLinks.support, let address = AppLinks.supportAddress {
            Link(destination: url) { LabeledContent(Copy.Settings.contact, value: address) }
          }
        }
        .listRowBackground(TollColor.surface)
        Section {
          NavigationLink(Copy.Settings.log) { TransitionLogView(model: model) }
          LabeledContent(Copy.Settings.version, value: AppLinks.version)
        }
        .listRowBackground(TollColor.surface)
      }
      .scrollContentBackground(.hidden)
      .background(TollColor.bg)
      .navigationTitle(Copy.Settings.title)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(Copy.Setup.done) { dismiss() }
        }
      }
      .sheet(isPresented: $explaining) { HowItWorks() }
    }
    .tint(TollColor.accent)
    .preferredColorScheme(appearance.scheme)
  }

  private var screenTime: String {
    model.screenTime == .approved ? Copy.Settings.on : Copy.Settings.off
  }

  private var location: String {
    switch model.location {
    case .always: Copy.Settings.always
    case .whileUsing: Copy.Settings.whileUsing
    case .approximate: Copy.Settings.approximate
    case .denied, .notDetermined: Copy.Settings.off
    }
  }

  private var lastNight: String {
    guard let night = LastNight(log: Array(model.log.reversed())) else {
      return Copy.Settings.notYet
    }
    return Copy.Settings.blocked(Copy.time(night.on), night.off.map { Copy.time($0) })
  }

  private func restore() async {
    restoreNote = await model.restore() ? Copy.Settings.restored : Copy.Trial.nothingToRestore
  }
}

private struct HowItWorks: View {
  var body: some View {
    VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
      Text(Copy.Settings.howItWorks).font(TollFont.title).foregroundStyle(TollColor.label)
        .accessibilityAddTraits(.isHeader)
      ForEach(Copy.Settings.howItWorksLines, id: \.self) { line in
        Text(line).font(TollFont.body).foregroundStyle(TollColor.label)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .tollGutter()
    .padding(.top, TollSpacing.titleGap)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TollColor.bg)
    .presentationDetents([.medium, .large])
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
