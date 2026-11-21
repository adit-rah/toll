import SwiftUI
import TollCore
import TollData
import TollUI
import UIKit

/// Setup 3 (the canvas's Permissions, and Permissions · Screen Time denied): one button runs Apple's
/// prompts. Screen Time has no skip; location can stay short of Always, and then blocks run on their
/// hours alone (decisions D8, D37).
struct PermissionsView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(
      step: SetupModel.Step.permissions.number, title: Copy.Setup.permissionsTitle,
      subtitle: Copy.Setup.permissionsLine
    ) {
      Card {
        PermissionRow(
          symbol: "hourglass", title: Copy.Setup.screenTime, why: Copy.Setup.screenTimeWhy,
          state: screenTimeState)
        PermissionRow(
          symbol: "location", title: Copy.Setup.location, why: Copy.Setup.locationWhy,
          state: locationState)
      }
      .padding(.top, TollSpacing.lineToContent)
      if model.app.screenTime == .denied {
        NoteCard(Copy.Setup.screenTimeDenied, symbol: "hourglass")
          .padding(.top, 14)
          .transition(.opacity)
      }
    } actions: {
      if model.screenTimeReady && model.locationSettled {
        PrimaryButton(Copy.Setup.continue) { model.go(model.afterPermissions) }
      } else {
        PrimaryButton(model.app.screenTime == .denied ? Copy.Setup.tryAgain : Copy.Setup.allow) {
          Task { await model.allow() }
        }
      }
    }
    .animation(Motion.stateChange, value: model.app.screenTime)
  }

  private var screenTimeState: PermissionState? {
    switch model.app.screenTime {
    case .approved: PermissionState(text: Copy.Setup.on, tone: .good)
    case .denied: PermissionState(text: Copy.Setup.off, tone: .bad)
    case .notDetermined: nil
    }
  }

  private var locationState: PermissionState? {
    switch model.app.location {
    case .always: PermissionState(text: Copy.Setup.always, tone: .good)
    case .whileUsing: PermissionState(text: Copy.Setup.whileUsing, tone: .neutral)
    case .approximate: PermissionState(text: Copy.Settings.approximate, tone: .neutral)
    case .denied: PermissionState(text: Copy.Setup.never, tone: .neutral)
    case .notDetermined: nil
    }
  }
}

private struct PermissionRow: View {
  let symbol: String
  let title: String
  let why: String
  let state: PermissionState?

  var body: some View {
    CardRow(title, detail: why, size: .permission) {
      IconTile(symbol, size: .permission)
    } trailing: {
      if let state { state.transition(.opacity) }
    }
    .animation(Motion.stateChange, value: state?.text)
    .accessibilityElement(children: .combine)
  }
}

/// The canvas's Always step: While Using can't start a block with the app closed. Says what happens
/// without it instead of warning (D37), and draws where the setting is.
struct AlwaysView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(
      step: SetupModel.Step.always.number, title: Copy.Setup.alwaysTitle,
      subtitle: Copy.Setup.alwaysLine, endsWithLink: true
    ) {
      SettingsPicture().padding(.top, 24)
      Footnote(Copy.Setup.alwaysPath).padding(.top, 14)
    } actions: {
      PrimaryButton(Copy.Setup.openSettings) {
        openSystemSettings()
        model.go(.blocklist)
      }
      // Its label already says what Not now means; the location-off screen is for Never and
      // Approximate, where there's something to see (#46).
      QuietButton(Copy.Setup.alwaysLater, type: .smallQuiet) { model.go(.blocklist) }
    }
  }
}

/// A picture of iOS's location setting with Always chosen, read out as the path to it.
private struct SettingsPicture: View {
  var body: some View {
    VStack(spacing: 0) {
      Text(Copy.Setup.alwaysHeader)
        .tollType(
          TollType(
            size: 12, lineHeight: 16, weight: .semibold, style: .caption, tracking: 0.6,
            uppercase: true)
        )
        .foregroundStyle(TollColor.label2)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.horizontal, TollSpacing.cardPadding)
      ForEach(Copy.Setup.alwaysOptions, id: \.self) { option in
        Hairline()
        Text(option)
          .tollType(TollType(size: 15, lineHeight: 20, weight: .regular, style: .subheadline))
          .foregroundStyle(TollColor.label)
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          .padding(.horizontal, TollSpacing.cardPadding)
      }
      Hairline()
      HStack {
        Text(Copy.Setup.alwaysChoice).tollType(.link, TollColor.label)
        Spacer()
        Image(systemName: "checkmark").unredacted()
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(TollColor.accent)
      }
      .frame(minHeight: 48)
      .padding(.horizontal, TollSpacing.cardPadding)
      .background(TollColor.accentSoft)
    }
    .background(TollColor.surface)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.Setup.alwaysPath)
  }
}

/// The canvas's Location off or approximate: what Settings says now, and what that means.
struct LocationOffView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(step: SetupModel.Step.locationOff.number, title: Copy.Setup.locationOffTitle) {
      Card {
        StateRow(symbol: "location", title: Copy.Setup.location, value: locationValue)
        StateRow(
          symbol: "mappin", title: Copy.Setup.preciseLocation,
          value: model.app.locationAccess.isPrecise ? Copy.Setup.on : Copy.Setup.off)
      }
      .padding(.top, TollSpacing.lineToContent)
      NoteCard(fact, symbol: "clock") {
        Button(Copy.Setup.changeInSettings, action: openSystemSettings)
          .tollType(.link, TollColor.accent)
          .frame(minHeight: 28)
      }
      .padding(.top, 14)
    } actions: {
      PrimaryButton(Copy.Setup.continue) { model.go(.blocklist) }
    }
  }

  private var locationValue: String {
    switch model.app.location {
    case .denied, .notDetermined: Copy.Setup.never
    default: model.app.locationAccess.isAlways ? Copy.Setup.always : Copy.Setup.whileUsing
    }
  }

  private var fact: String {
    switch model.app.location {
    case .approximate: Copy.Setup.approximateFact
    case .denied, .notDetermined: Copy.Setup.deniedFact
    default: Copy.Setup.whileUsingFact
    }
  }
}

private struct StateRow: View {
  let symbol: String
  let title: String
  let value: String

  var body: some View {
    CardRow(title, size: RowSize(minHeight: 64, tile: .permission)) {
      IconTile(symbol, size: .permission, accent: false)
    } trailing: {
      PermissionState(text: value, tone: .neutral)
    }
    .accessibilityElement(children: .combine)
  }
}

@MainActor func openSystemSettings() {
  guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
  UIApplication.shared.open(url)
}
