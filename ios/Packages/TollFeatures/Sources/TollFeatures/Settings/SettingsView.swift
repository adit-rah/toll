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
  /// Restored on this visit: the row stays to say so (`Copy.Settings.restored`).
  @State private var restored = false
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
            locationRow
            Button {
              settingHome = true
            } label: {
              SettingsRow(Copy.Settings.onlyAtHome, detail: onlyAtHome, glyph: true) { Chevron() }
            }
            .buttonStyle(.plain)
            BeforeBedRow(model: model)
            HeadsUpRow(model: model)
            SettingsRow(Copy.Settings.lastNight, detail: lastNight)
          }
        }
        SettingsSection(Copy.Settings.app) {
          Card {
            SettingsRow(Copy.Settings.appearance, minHeight: 50) {
              AppearancePicker(selection: $appearance)
            }
            freeNights
            // An action, not a place: no chevron. Gone once bought, except to say it worked.
            if !model.state.trial.purchased || restored {
              Button {
                Task { await restore() }
              } label: {
                SettingsRow(
                  Copy.Settings.restore, detail: restored ? Copy.Settings.restored : nil)
              }
              .buttonStyle(.plain)
              .disabled(restoring || restored)
            }
          }
        }
        SettingsSection(Copy.Settings.help) {
          Card {
            Button {
              explaining = true
            } label: {
              SettingsRow(Copy.Settings.howItWorks, glyph: true) { Chevron() }
            }
            .buttonStyle(.plain)
            // Rows that leave the app say so with the glyph; a row with nowhere to go isn't shown.
            if let privacy = AppLinks.privacy {
              Link(destination: privacy) {
                SettingsRow(Copy.Settings.privacy, detail: Copy.Settings.privacyLine, glyph: true) {
                  LeavesApp()
                }
              }
              .buttonStyle(.plain)
            }
            if let address = AppLinks.supportAddress, let support = AppLinks.support {
              Link(destination: support) {
                SettingsRow(Copy.Settings.contact, detail: address, glyph: true) { LeavesApp() }
              }
              .buttonStyle(.plain)
            }
            NavigationLink(value: HomeRoute.log) {
              SettingsRow(Copy.Settings.log, detail: Copy.Settings.testingOnly, glyph: true) {
                Chevron()
              }
            }
            .buttonStyle(.plain)
          }
        }
        Text(Copy.Settings.versionLine(AppLinks.version))
          .tollType(.detail, TollColor.label2)
          .frame(maxWidth: .infinity)
          .padding(.top, 20)
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

  /// With home set and location short of Always, location is why home doesn't work, so the row
  /// opens iOS Settings (the audit); otherwise it only reports.
  @ViewBuilder private var locationRow: some View {
    if model.state.homeIsSet, model.location != .always {
      Button(action: openSystemSettings) {
        SettingsRow(Copy.Settings.location) {
          HStack(spacing: 8) {
            PermissionState(text: location.0, tone: location.1)
            LeavesApp()
          }
        }
      }
      .buttonStyle(.plain)
    } else {
      SettingsRow(Copy.Settings.location) {
        PermissionState(text: location.0, tone: location.1)
      }
    }
  }

  /// "On", or when a change made during the night applies (B-3).
  private var onlyAtHome: String {
    let on = model.state.homeIsSet
    if let at = model.state.homeChangeAt { return Copy.Settings.onlyAtHomeFrom(on, Copy.time(at)) }
    return on ? Copy.Settings.onlyAtHomeOn : Copy.Settings.onlyAtHomeOff
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
    guard
      let night = PastNight.latest(
        history: model.history, state: model.state, log: model.log, now: model.now,
        calendar: .current),
      let start = night.start, let end = night.end
    else { return Copy.Settings.notYet }
    return Copy.Settings.lastNightSpan(
      day: Copy.shortWeekday(night.night), Copy.time(start), Copy.time(end))
  }

  private func restore() async {
    restoring = true
    defer { restoring = false }
    if await model.restore() {
      restored = true
    } else {
      nothingToRestore = true
    }
  }
}

/// A row that leaves the app for somewhere else (design §2.6).
private struct LeavesApp: View {
  var body: some View {
    Image(symbol: .openSettings).unredacted()
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(TollColor.label3)
      .accessibilityHidden(true)
  }
}
