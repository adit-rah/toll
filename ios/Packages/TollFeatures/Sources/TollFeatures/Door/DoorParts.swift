@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollUI

/// Door · none left: the empty supply, when one comes back, and that nothing else is blocked.
struct DoorNoneLeft: View {
  let model: AppModel

  var body: some View {
    SheetPage(height: 374) {
      SheetTitle(Copy.Door.noneTitle)
      UnlockPips(left: 0, max: model.config.unlocks.max).padding(.top, 16)
      Text(
        Copy.Door.refillLine(
          model.state.unlocks.nightsToRefill(model.config) ?? model.config.unlocks.refillNights,
          after: model.config.unlocks.refillNights)
      )
      .tollType(.sheetBody, TollColor.label)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 18)
      Text(Copy.Door.othersWork)
        .tollType(TollType(size: 14, lineHeight: 20, weight: .regular, style: .subheadline))
        .foregroundStyle(TollColor.label2)
        .padding(.top, 8)
    } actions: {
      PrimaryButton(Copy.Door.ok) { model.dismissDoor() }
    }
  }
}

/// Door · not blocked: Apple's picker offers every app, and one nothing blocks would spend an unlock
/// for nothing (#47).
struct DoorNotBlocked: View {
  let model: AppModel
  let chooseAgain: () -> Void

  var body: some View {
    SheetPage(height: 374) {
      SheetTitle(Copy.Door.notBlockedTitle)
      SheetBody(Copy.Door.notBlockedBody).padding(.top, 10)
    } actions: {
      PrimaryButton(Copy.Door.chooseAgain, action: chooseAgain)
      QuietButton(Copy.Door.notNow) { model.dismissDoor() }.frame(maxWidth: .infinity)
    }
  }
}

/// "You wait 90 seconds first. Cancelling costs nothing." on `surfaceRaised`.
struct WaitNote: View {
  let seconds: Int

  var body: some View {
    Text(Copy.Door.waitFirst(seconds: seconds))
      .tollType(.body, TollColor.label2)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, TollSpacing.noteCardVertical)
      .padding(.horizontal, TollSpacing.cardPadding)
      .background(
        TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// Unlocks as 12 pt dots, filled amber for each left and outlined for each used, with the count
/// in words beside them (never the dots alone).
struct UnlockPips: View {
  let left: Int
  let max: Int

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 6) {
        ForEach(0..<max, id: \.self) { index in
          if index < left {
            Circle().fill(TollColor.accent).frame(width: 12, height: 12)
          } else {
            Circle().strokeBorder(TollColor.label3, lineWidth: 1.5).frame(width: 12, height: 12)
          }
        }
      }
      Text(left == 0 ? Copy.Door.noneOf(max) : Copy.Door.unlocksOf(left, max))
        .tollType(.heroLine, TollColor.label2)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.Door.unlocksOf(left, max))
  }
}

/// The chosen app as iOS draws it: its icon at the board's size, its name beside it. The app never
/// learns which app it is.
struct DoorAppStyle: LabelStyle {
  enum Title {
    /// 17 semibold, beside a 40 pt icon.
    case sheetApp
    /// 16 semibold, beside a 32 pt icon.
    case rowApp
  }

  let size: CGFloat
  let radius: CGFloat
  let title: Title
  var gap: CGFloat = 10
  var detail: String?

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: gap) {
      configuration.icon
        .font(.system(size: size - 6))
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 0) {
        configuration.title
          .tollType(
            title == .sheetApp
              ? TollType(size: 17, lineHeight: 22, weight: .semibold, style: .body)
              : TollType(size: 16, lineHeight: 21, weight: .semibold, style: .callout)
          )
          .foregroundStyle(TollColor.label)
        if let detail { Text(detail).tollType(.detail, TollColor.label2) }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}
