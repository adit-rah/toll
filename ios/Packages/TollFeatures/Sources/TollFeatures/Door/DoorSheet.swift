import SwiftUI
import TollCore
import TollUI

/// The pause (D67; the spec's door, D-3, D-4, D31), a sheet over Tonight opened by the block
/// screen's "Open Dusk to pause" or Tonight's "Pause". Four states, each read without words: the pause
/// symbol and the dots, the wait's countdown, the pause's countdown, and the empty dots. They
/// crossfade (design §2.5).
struct DoorSheet: View {
  let model: AppModel
  let now: Date
  /// Choosing, waiting and open follow each other in one sheet, so they share the tallest one's
  /// height: the sheet never moves between them (design §2.5). None left only ever opens alone.
  static let height: CGFloat = 470

  var body: some View {
    let supply = HomeSnapshot.Supply(
      state: model.state, now: now, calendar: .current, config: model.config)
    Group {
      if let door = model.state.door {
        switch door.phase {
        case .waiting: DoorWaiting(model: model, door: door, now: now)
        case .open: DoorOpen(model: model, door: door, now: now)
        }
      } else if supply.left == 0 {
        DoorNoneLeft(model: model, supply: supply)
      } else {
        DoorChoose(model: model, supply: supply)
      }
    }
    .transition(.opacity)
    .animation(Motion.movement, value: model.state.door?.phase)
    .tollHaptic(.light, trigger: model.state.door?.phase)
  }
}

/// Pause · choosing: the pause symbol, the question, the dots with the one it would spend dashed,
/// the wait, and one button. No picker: a pause opens every app (D67).
private struct DoorChoose: View {
  let model: AppModel
  let supply: HomeSnapshot.Supply

  var body: some View {
    SheetPage(height: DoorSheet.height, overhang: 16) {
      IconTile(.unlock, size: .sheet)
      SheetTitle(Copy.Door.question(minutes: model.config.door.minutes)).padding(.top, 18)
      UnlockPips(left: supply.left, max: supply.max, spending: true).padding(.top, 14)
      WaitNote(seconds: model.config.door.waitSeconds).padding(.top, 20)
    } actions: {
      PrimaryButton {
        model.startDoor()
      } label: {
        HStack(spacing: 8) {
          Image(symbol: .unlock).unredacted().accessibilityHidden(true)
          Text(Copy.Door.pauseFor(minutes: model.config.door.minutes))
        }
      }
      QuietButton(Copy.Door.notNow) { model.dismissDoor() }.frame(maxWidth: .infinity)
    }
  }
}

/// Pause · waiting: the wait's glyph, a big countdown over a bar that fills toward the pause, and a
/// neutral Cancel (#75). The same bar then drains while the pause is open.
private struct DoorWaiting: View {
  let model: AppModel
  let door: Door
  let now: Date

  var body: some View {
    SheetPage(height: DoorSheet.height, overhang: 16) {
      Image(symbol: .wait).unredacted()
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(TollColor.label2)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
      Countdown(endsAt: door.waitEndsAt, text: { $0 }, spoken: Copy.Door.opensInSpoken)
        .tollType(
          TollType(size: 72, lineHeight: 76, weight: .semibold, style: .largeTitle, tabular: true)
        )
        .foregroundStyle(TollColor.label)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        // The monitor starts the pause when its interval starts; this covers a late callback.
        .task(id: door.waitEndsAt) {
          try? await Task.sleep(for: .seconds(max(0, door.waitEndsAt.timeIntervalSinceNow)))
          model.send(.doorStart)
        }
      let wait = TimeInterval(model.config.door.waitSeconds)
      DoorBar(fraction: 1 - max(0, min(wait, door.waitEndsAt.timeIntervalSince(now))) / wait)
        .padding(.top, 12)
      Text(Copy.Door.onceWaitEnds(minutes: model.config.door.minutes))
        .tollType(.sheetBody, TollColor.label)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
      Text(Copy.Door.leaveFreely)
        .tollType(TollType(size: 14, lineHeight: 20, weight: .regular, style: .subheadline))
        .foregroundStyle(TollColor.label2)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    } actions: {
      // Choosing already said cancelling costs nothing.
      PrimaryButton(Copy.Door.cancel, tone: .neutral) { model.cancelDoor() }
      LinkRoom()
    }
  }
}

/// Pause · open, counting down (D31): the pause symbol and "Paused", when blocking comes back, the
/// time left over a draining bar, and the regret line while it lasts (D-4); after it, a quiet line
/// over "Lock again" says the pause is spent.
private struct DoorOpen: View {
  let model: AppModel
  let door: Door
  let now: Date

  var body: some View {
    SheetPage(height: DoorSheet.height, overhang: 16) {
      HStack(spacing: 8) {
        Image(symbol: .unlock).unredacted()
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(TollColor.accent)
          .accessibilityHidden(true)
        SheetTitle(Copy.Door.isOpen)
      }
      if let expiresAt = door.expiresAt {
        Text(Copy.Door.locksAt(Copy.time(expiresAt)))
          .tollType(.body, TollColor.label2)
          .padding(.top, 4)
        Text(Copy.Door.everyAppOpens).tollType(.body, TollColor.label2)
        // On the clock (D31): the monitor ends it at this moment even with the app closed.
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Countdown(endsAt: expiresAt, text: { $0 }, spoken: Copy.Door.leftSpoken)
            .tollType(
              TollType(
                size: 56, lineHeight: 60, weight: .semibold, style: .largeTitle, tabular: true)
            )
            .foregroundStyle(TollColor.label)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
          Text(Copy.Door.leftWord).tollType(.bar, TollColor.label2).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .task(id: expiresAt) {
          try? await Task.sleep(for: .seconds(max(0, expiresAt.timeIntervalSinceNow)))
          model.send(.doorEnd)
        }
        let total = TimeInterval(model.config.door.minutes * 60)
        let left = max(0, min(total, expiresAt.timeIntervalSince(now)))
        // The regret window's end as a tick: lock before the bar drains past it and the pause comes
        // back (D-4, #75).
        let tick = door.regretEndsAt(model.config).flatMap { end in
          now < end ? expiresAt.timeIntervalSince(end) / total : nil
        }
        DoorBar(fraction: left / total, tick: tick).padding(.top, 16)
      }
      if let regretEnd = door.regretEndsAt(model.config), now < regretEnd {
        HStack(alignment: .top, spacing: 10) {
          Image(symbol: .keep).unredacted()
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(TollColor.accent)
            .frame(width: 18, height: 21)
            .accessibilityHidden(true)
          Countdown(endsAt: regretEnd, text: Copy.Door.regretFor, spoken: Copy.Door.leftSpoken)
            .tollType(.body, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, TollSpacing.noteCardVertical)
        .padding(.horizontal, TollSpacing.cardPadding)
        .background(
          TollColor.accentSoft,
          in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
        )
        .padding(.top, 20)
        .transition(.opacity)
      }
    } actions: {
      if let regretEnd = door.regretEndsAt(model.config), now >= regretEnd {
        Footnote(Copy.Door.pauseUsed, alignment: .center).padding(.bottom, 10)
      }
      PrimaryButton {
        model.lockDoor()
      } label: {
        HStack(spacing: 8) {
          Image(symbol: .blocked).unredacted().accessibilityHidden(true)
          Text(Copy.Door.lockAgain)
        }
      }
      LinkRoom()
    }
  }
}
