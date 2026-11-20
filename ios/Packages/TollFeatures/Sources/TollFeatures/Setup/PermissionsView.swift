import SwiftUI
import TollCore
import TollUI
import UIKit

/// Setup 3 (the canvas): one button runs Apple's prompts. Screen Time has no skip; location can stay
/// short of Always, and then blocks run on their hours alone (decisions D8, D37).
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
          status: screenTimeStatus)
        PermissionRow(
          symbol: "location.fill", title: Copy.Setup.location, why: Copy.Setup.locationWhy,
          status: locationStatus)
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
  }

  private var screenTimeStatus: String? {
    switch model.app.screenTime {
    case .approved: Copy.Setup.allowed
    case .denied: Copy.Setup.screenTimeNeeded
    case .notDetermined: nil
    }
  }

  private var locationStatus: String? {
    switch model.app.location {
    case .always: Copy.Setup.allowed
    case .approximate: Copy.Setup.locationApproximate
    case .denied: Copy.Setup.locationDenied
    case .whileUsing, .notDetermined: nil
    }
  }
}

private struct PermissionRow: View {
  let symbol: String
  let title: String
  let why: String
  let status: String?

  var body: some View {
    CardRow(title, detail: status ?? why) { IconTile(symbol, size: .permission) }
      .animation(Motion.stateChange, value: status)
      .accessibilityElement(children: .combine)
  }
}

/// The canvas's Always step: While Using can't start a block with the app closed. Says what happens
/// without it instead of warning (D37), and shows where the setting is.
struct AlwaysView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(
      step: SetupModel.Step.always.number, title: Copy.Setup.alwaysTitle,
      subtitle: Copy.Setup.alwaysLine
    ) {
      VStack(spacing: 0) {
        Text(Copy.Setup.alwaysHeader.uppercased())
          .font(TollFont.captionMedium)
          .foregroundStyle(TollColor.label2)
          .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        ForEach(Copy.Setup.alwaysOptions, id: \.self) { option in
          Hairline()
          Text(option)
            .font(TollFont.subhead)
            .foregroundStyle(TollColor.label)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        Hairline()
        HStack {
          Text(Copy.Setup.alwaysChoice).font(TollFont.subheadSemibold)
          Spacer()
          Image(systemName: "checkmark").foregroundStyle(TollColor.accent)
        }
        .foregroundStyle(TollColor.label)
        .frame(minHeight: 48)
        .padding(.horizontal, TollSpacing.cardPadding)
        .background(TollColor.accentSoft)
        .padding(.horizontal, -TollSpacing.cardPadding)
      }
      .padding(.horizontal, TollSpacing.cardPadding)
      .background(TollColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Copy.Setup.alwaysPath)
      Footnote(Copy.Setup.alwaysPath)
    } actions: {
      PrimaryButton(Copy.Setup.openSettings) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        model.go(.blocklist)
      }
      QuietButton(Copy.Setup.alwaysLater, tone: .secondary) { model.go(.blocklist) }
    }
  }
}
