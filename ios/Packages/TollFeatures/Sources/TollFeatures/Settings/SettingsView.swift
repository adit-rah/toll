@preconcurrency import FamilyControls
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Spec §7 Settings: the three things the user chose, then the purchase, the policy, support, the
/// log and the version. Nothing else.
struct SettingsView: View {
  let model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var picking = false
  @State private var selection = FamilyActivitySelection()
  @State private var restoreNote: String?

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink(Copy.Settings.window) { WindowSettingsView(model: model) }
          NavigationLink(Copy.Settings.home) { HomeSettingsView(model: model) }
          Button {
            picking = true
          } label: {
            LabeledContent(Copy.Settings.keepOpen, value: keptSummary)
          }
          .foregroundStyle(TollColor.label)
        } footer: {
          Text(Copy.Settings.changesLater)
        }
        Section {
          Button(Copy.Settings.restore) { Task { await restore() } }
          if let restoreNote { Text(restoreNote).tollText(.subhead) }
          if let url = AppLinks.privacy { Link(Copy.Settings.privacy, destination: url) }
          if let url = AppLinks.support { Link(Copy.Settings.support, destination: url) }
        }
        Section {
          NavigationLink(Copy.Settings.log) { TransitionLogView(model: model) }
          LabeledContent(Copy.Settings.version, value: AppLinks.version)
        }
      }
      .navigationTitle(Copy.Settings.title)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(Copy.Setup.done) { dismiss() }
        }
      }
    }
    .tint(TollColor.accent)
    .familyActivityPicker(isPresented: $picking, selection: $selection)
    .onAppear { selection = KeepOpen.selection(from: model.draft.keepOpen) }
    .onChange(of: picking) { _, isOpen in
      guard !isOpen else { return }
      var edit = model.draft
      edit.keepOpen = KeepOpen.encode(selection)
      model.submit(edit)
    }
  }

  private var keptSummary: String {
    let kept = KeepOpen.selection(from: model.draft.keepOpen)
    return Copy.Settings.kept(apps: kept.applicationTokens.count, sites: kept.webDomainTokens.count)
  }

  private func restore() async {
    restoreNote = await model.restore() ? Copy.Settings.restored : Copy.Trial.nothingToRestore
  }
}

/// Where the policy and support live, from Info.plist so they change without a code edit.
enum AppLinks {
  static var privacy: URL? { url("TollPrivacyURL") }
  static var support: URL? {
    string("TollSupportEmail").flatMap { URL(string: "mailto:\($0)") }
  }
  static var version: String {
    let short = string("CFBundleShortVersionString") ?? "?"
    let build = string("CFBundleVersion") ?? "?"
    return "\(short) (\(build))"
  }

  private static func string(_ key: String) -> String? {
    (Bundle.main.object(forInfoDictionaryKey: key) as? String).flatMap { $0.isEmpty ? nil : $0 }
  }

  private static func url(_ key: String) -> URL? { string(key).flatMap(URL.init(string:)) }
}
