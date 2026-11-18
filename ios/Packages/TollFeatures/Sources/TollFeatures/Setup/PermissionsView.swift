import SwiftUI
import TollCore
import TollUI
import UIKit

/// Setup 4 (spec §7): one button runs the prompts. Screen Time has no skip; location can be left off,
/// and then the window alone decides (decisions D8).
struct PermissionsView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(step: SetupModel.Step.permissions.number, title: Copy.Setup.permissionsTitle) {
      PermissionRow(
        title: Copy.Setup.screenTime, why: Copy.Setup.screenTimeWhy, status: screenTimeStatus)
      PermissionRow(title: Copy.Setup.location, why: Copy.Setup.locationWhy, status: locationStatus)
      if needsSettings {
        QuietButton(Copy.Setup.openSettings) { openSettings() }
      }
    } actions: {
      if model.screenTimeReady && model.locationSettled {
        PrimaryButton(Copy.Setup.continue) { model.go(.blocklist) }
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
    case .whileUsing: model.askedAlways ? Copy.Setup.locationAlwaysNeeded : nil
    case .approximate: Copy.Setup.locationApproximate
    case .denied: Copy.Setup.locationDenied
    case .notDetermined: nil
    }
  }

  private var needsSettings: Bool {
    model.screenTimeReady && model.app.location != .always && model.locationSettled
  }

  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}

private struct PermissionRow: View {
  let title: String
  let why: String
  let status: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).tollText(.headline)
      SetupLine(why, .subhead)
      if let status {
        SetupLine(status)
          .transition(.opacity)
      }
    }
    .accessibilityElement(children: .combine)
    .animation(Motion.stateChange, value: status)
  }
}
