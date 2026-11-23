import SwiftUI
import TollCore
import TollUI

/// Pause · none left (D67): the empty dots, the week as seven segments with the nights gone filled
/// (how long until they come back, without words), when they come back, and that nothing else is
/// blocked.
struct DoorNoneLeft: View {
  let model: AppModel
  let supply: HomeSnapshot.Supply

  var body: some View {
    SheetPage(height: 390) {
      IconTile(.unlock, size: .sheet, accent: false)
      SheetTitle(Copy.Door.noneTitle).padding(.top, 18)
      UnlockPips(left: 0, max: supply.max, back: supply.refillDay).padding(.top, 14)
      Pips(
        filled: supply.nightOfWeek - 1, total: 7, style: .segments,
        spoken: Copy.Door.weekly(supply.max, refill: supply.refill)
      )
      .padding(.top, 14)
      Text(Copy.Door.weekly(supply.max, refill: supply.refill))
        .tollType(.sheetBody, TollColor.label)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 18)
      Text(Copy.Door.othersWork)
        .tollType(TollType(size: 14, lineHeight: 20, weight: .regular, style: .subheadline))
        .foregroundStyle(TollColor.label2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
    } actions: {
      PrimaryButton(Copy.Door.ok) { model.dismissDoor() }
    }
  }
}

/// "You wait 60 seconds first. Cancelling costs nothing." on `surfaceRaised`.
struct WaitNote: View {
  let seconds: Int

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(symbol: .wait).unredacted().accessibilityHidden(true)
      Text(Copy.Door.waitFirst(seconds: seconds))
        .fixedSize(horizontal: false, vertical: true)
    }
    .tollType(.body, TollColor.label2)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, TollSpacing.noteCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .background(
      TollColor.surfaceRaised,
      in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// The week's pauses as 12 pt dots, filled amber for each left and outlined for each used, with the
/// count in words beside them (never the dots alone).
struct UnlockPips: View {
  let left: Int
  let max: Int
  /// Starting a pause: the dot it would spend is drawn as a dashed ring (#75).
  var spending = false
  /// None left: when they come back, in place of the count.
  var back: String?

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 6) {
        ForEach(0..<max, id: \.self) { index in
          if spending && index == left - 1 {
            Circle()
              .strokeBorder(TollColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2]))
              .frame(width: 12, height: 12)
          } else if index < left {
            Circle().fill(TollColor.accent).frame(width: 12, height: 12)
          } else {
            Circle().strokeBorder(TollColor.label3, lineWidth: 1.5).frame(width: 12, height: 12)
          }
        }
      }
      Text(words).tollType(.heroLine, TollColor.label2)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spoken)
  }

  private var words: String {
    if left == 0 { return back.map(Copy.Door.back) ?? Copy.Door.noneOf(max) }
    return Copy.Door.pausesOf(left, max)
  }

  private var spoken: String {
    if left == 0, let back { return Copy.Door.noneLeftBack(back) }
    return Copy.Door.pausesLeft(left, of: max)
  }
}

/// The pause's one bar (#75): it fills over the wait, then drains over the minutes paused.
/// An optional tick marks where the regret time ends.
struct DoorBar: View {
  let fraction: Double
  var tick: Double?

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 4).fill(TollColor.surfaceRaised)
        RoundedRectangle(cornerRadius: 4).fill(TollColor.accent)
          .frame(width: proxy.size.width * min(1, max(0, fraction)))
        if let tick {
          Rectangle().fill(TollColor.label)
            .frame(width: 2, height: 14)
            .offset(x: proxy.size.width * min(1, max(0, tick)) - 1)
        }
      }
      .frame(height: 8)
      .frame(maxHeight: .infinity)
    }
    .frame(height: 14)
    .accessibilityHidden(true)
  }
}
