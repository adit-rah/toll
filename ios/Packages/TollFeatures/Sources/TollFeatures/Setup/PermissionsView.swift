import SwiftUI
import TollCore
import TollData
import TollUI
import UIKit

/// "Only when I'm home", second step (D68): location on its own, after the map. iOS asks While Using
/// on the map; this asks for Always once. Location can stay short of Always, and then the night runs
/// on its hours anywhere (decisions D8, D37).
struct LocationView: View {
  let model: SetHomeModel

  var body: some View {
    SetupPage(
      step: SetHomeModel.locationStep, of: SetHomeModel.questions,
      title: Copy.Setup.locationTitle, subtitle: Copy.Setup.locationLine
    ) {
      Card {
        PermissionRow(
          symbol: .location, title: Copy.Setup.location, why: Copy.Setup.locationWhy,
          state: locationState)
      }
      .padding(.top, TollSpacing.lineToContent)
    } actions: {
      if model.locationSettled {
        PrimaryButton(Copy.Setup.continue) { model.afterLocation() }
      } else {
        PrimaryButton(Copy.Setup.allow) { model.allowLocation() }
      }
    }
  }

  private var locationState: PermissionState? {
    switch model.app.location {
    case .always: PermissionState(text: Copy.Setup.always, tone: .good)
    case .whileUsing: PermissionState(text: Copy.Setup.whileUsing, tone: .neutral)
    case .approximate: PermissionState(text: Copy.Settings.approximate, tone: .neutral)
    case .denied: PermissionState(text: Copy.Setup.off, tone: .neutral)
    case .notDetermined: nil
    }
  }
}

struct PermissionRow: View {
  let symbol: TollSymbol
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
  let model: SetHomeModel

  var body: some View {
    SetupPage(
      step: SetHomeModel.locationStep, of: SetHomeModel.questions, title: Copy.Setup.alwaysTitle,
      subtitle: Copy.Setup.alwaysLine, endsWithLink: true
    ) {
      // The setting it names, by its glyph: wordless, this is a location screen (#76).
      IconTile(.location, size: .sheet).padding(.top, 24)
      SettingsPicture().padding(.top, 16)
      Footnote(Copy.Setup.alwaysPath).padding(.top, 14)
    } actions: {
      PrimaryButton {
        openSystemSettings()
        model.finish()
      } label: {
        HStack(spacing: 8) {
          Text(Copy.Setup.openSettings)
          Image(symbol: .openSettings).unredacted().accessibilityHidden(true)
        }
      }
      // Its label already says what Not now means; the location-off screen is for Never and
      // Approximate, where there's something to see (#46).
      QuietButton(Copy.Setup.alwaysLater, type: .smallQuiet) { model.finish() }
    }
  }
}

/// A picture of iOS's location setting with Always chosen, read out as the path to it. Drawn small,
/// inset and framed like a screenshot, with no row heights or dividers, over the caption that names
/// the path, so it isn't taken for a list to tap here (the audit).
private struct SettingsPicture: View {
  private let shape = RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous)
  private let small = TollType(size: 13, lineHeight: 18, weight: .regular, style: .footnote)

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(Copy.Setup.alwaysHeader).tollType(small).foregroundStyle(TollColor.label3)
      ForEach(Copy.Setup.alwaysOptions, id: \.self) { option in
        Text(option).tollType(small).foregroundStyle(TollColor.label2)
      }
      HStack(spacing: 6) {
        Text(Copy.Setup.alwaysChoice)
          .tollType(TollType(size: 13, lineHeight: 18, weight: .semibold, style: .footnote))
          .foregroundStyle(TollColor.label)
        Spacer(minLength: 0)
        Image(symbol: .done).unredacted()
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(TollColor.accent)
      }
    }
    .padding(14)
    .frame(maxWidth: 260, alignment: .leading)
    .background(TollColor.surfaceRaised, in: shape)
    .overlay(shape.strokeBorder(TollColor.separator))
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.Setup.alwaysPath)
  }
}

/// The canvas's Location off or approximate: what Settings says now, and what that means.
struct LocationOffView: View {
  let model: SetHomeModel

  var body: some View {
    SetupPage(
      step: SetHomeModel.locationStep, of: SetHomeModel.questions,
      title: Copy.Setup.locationOffTitle
    ) {
      Card {
        StateRow(symbol: .location, title: Copy.Setup.location, value: locationValue)
        StateRow(
          symbol: .precise, title: Copy.Setup.preciseLocation,
          value: model.app.locationAccess.isPrecise ? Copy.Setup.on : Copy.Setup.off)
      }
      .padding(.top, TollSpacing.lineToContent)
      NoteCard(fact, severity: .degraded) {
        SettingsLink(Copy.Setup.changeInSettings, action: openSystemSettings)
      }
      .padding(.top, 14)
    } actions: {
      PrimaryButton(Copy.Setup.continue) { model.finish() }
    }
  }

  private var locationValue: String {
    switch model.app.location {
    case .denied, .notDetermined: Copy.Setup.off
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
  let symbol: TollSymbol
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
