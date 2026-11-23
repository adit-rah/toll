import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Onboarding 2 (D68): Screen Time alone, the one permission a first night needs. It has no skip;
/// location is asked only when home is set, after the first night.
struct ScreenTimeView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(
      step: SetupModel.Step.screenTime.number, title: Copy.Setup.screenTimeTitle,
      subtitle: Copy.Setup.screenTimeLine
    ) {
      ScreenTimePicture(state: model.app.screenTime)
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
      Card {
        PermissionRow(
          symbol: .screenTime, title: Copy.Setup.screenTime, why: Copy.Setup.screenTimeWhy,
          state: state)
      }
      .padding(.top, 36)
      if model.app.screenTime == .denied {
        NoteCard(Copy.Setup.screenTimeDenied, severity: .broken)
          .padding(.top, 14)
          .transition(.opacity)
      }
    } actions: {
      if model.screenTimeReady {
        PrimaryButton(Copy.Setup.continue) { model.go(.blocklist) }
      } else {
        PrimaryButton(model.app.screenTime == .denied ? Copy.Setup.tryAgain : Copy.Setup.allow) {
          Task { await model.allow() }
        }
      }
    }
    .animation(Motion.stateChange, value: model.app.screenTime)
  }

  private var state: PermissionState? {
    switch model.app.screenTime {
    case .approved: PermissionState(text: Copy.Setup.on, tone: .good)
    case .denied: PermissionState(text: Copy.Setup.off, tone: .bad)
    case .notDetermined: nil
    }
  }
}

/// The permission as a picture (#76): Screen Time's hourglass, and once Apple has answered, a badge
/// with the outcome's glyph (a tick, or the warning triangle), so the answer shows without words or
/// colour alone.
private struct ScreenTimePicture: View {
  let state: ScreenTimeAuthorization.State

  var body: some View {
    Image(symbol: .screenTime).unredacted()
      .font(.system(size: 34, weight: .medium))
      .foregroundStyle(TollColor.accent)
      .frame(width: 80, height: 80)
      .background(
        TollColor.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous)
      )
      .overlay(alignment: .bottomTrailing) {
        if let badge {
          Image(symbol: badge.symbol).unredacted()
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(badge.color)
            .frame(width: 30, height: 30)
            .background(TollColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(TollColor.bg, lineWidth: 3))
            .offset(x: 8, y: 8)
            .transition(.opacity)
        }
      }
      .accessibilityHidden(true)
  }

  private var badge: (symbol: TollSymbol, color: Color)? {
    switch state {
    case .approved: (.done, TollColor.ok)
    case .denied: (.broken, TollColor.warn)
    case .notDetermined: nil
    }
  }
}
