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
  /// "Only when I'm home" (D68): the same flow as Tonight's card, here for good.
  @State private var settingHome = false
  @AppStorage(Appearance.key) private var appearance = Appearance.standard

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Settings.title, kind: .pushed)
        SettingsSection(Copy.Settings.working, top: 16) {
          Card {
            if model.screenTime == .approved {
              SettingsRow(Copy.Settings.screenTime) {
                PermissionState(text: screenTime.0, tone: screenTime.1)
              }
            } else {
              // Off is the one setting that stops everything, so it's a button (#45).
              Button {
                Task { await model.turnOnScreenTime() }
              } label: {
                SettingsRow(Copy.Settings.screenTime) {
                  HStack(spacing: 8) {
                    PermissionState(text: screenTime.0, tone: screenTime.1)
                    Text(Copy.Home.turnOn).tollType(.action, TollColor.accent)
                  }
                }
              }
              .buttonStyle(.plain)
            }
            SettingsRow(Copy.Settings.location) {
              PermissionState(text: location.0, tone: location.1)
            }
            Button {
              settingHome = true
            } label: {
              SettingsRow(
                Copy.Settings.onlyAtHome,
                detail: model.state.homeIsSet
                  ? Copy.Settings.onlyAtHomeOn : Copy.Settings.onlyAtHomeOff
              ) { Chevron() }
            }
            .buttonStyle(.plain)
            BeforeBedRow(model: model)
            HeadsUpRow(model: model)
            SettingsRow(Copy.Settings.lastNight, detail: lastNight)
          }
        }
        SettingsSection(Copy.Settings.app) {
          Card {
            NavigationLink(value: HomeRoute.blocks) {
              SettingsRow(Copy.Settings.blocks, detail: blocksSummary) { Chevron() }
            }
            .buttonStyle(.plain)
            SettingsRow(Copy.Settings.appearance, minHeight: 50) {
              AppearancePicker(selection: $appearance)
            }
            freeNights
            Button {
              Task { await restore() }
            } label: {
              SettingsRow(Copy.Settings.restore) { Chevron() }
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
              SettingsRow(Copy.Settings.howItWorks) { Chevron() }
            }
            .buttonStyle(.plain)
            link(AppLinks.privacy) {
              SettingsRow(Copy.Settings.privacy, detail: Copy.Settings.privacyLine) { Chevron() }
            }
            if let address = AppLinks.supportAddress {
              link(AppLinks.support) { SettingsRow(Copy.Settings.contact, detail: address) }
            }
            NavigationLink(value: HomeRoute.log) {
              SettingsRow(Copy.Settings.log, detail: Copy.Settings.testingOnly) { Chevron() }
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
    .sheet(isPresented: $settingHome) { SetHomeFlow(app: model) { settingHome = false } }
  }

  @ViewBuilder private var freeNights: some View {
    if model.state.trial.purchased {
      SettingsRow(Copy.Settings.purchased, detail: Copy.Settings.purchasedDetail)
    } else {
      SettingsRow(
        Copy.Settings.freeNights,
        detail: model.trialNight(now: Date()).map {
          Copy.Settings.night($0, of: model.config.trial.nights)
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
      items: model.state.blocks.map(\.appCount).reduce(0, +), max: model.config.blocks.maxApps)
  }

  private func restore() async {
    restoring = true
    defer { restoring = false }
    if !(await model.restore()) { nothingToRestore = true }
  }
}
