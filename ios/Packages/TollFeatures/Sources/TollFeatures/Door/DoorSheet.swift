@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// The door (the canvas's "Block screen and the door" row; D-1 to D-7, D31, D41), a sheet over Home
/// opened by the block screen's "Unlock in Dusk" or Home's "Open one app". Each part is its board's
/// sheet; they crossfade (design §2.5).
struct DoorSheet: View {
  let model: AppModel
  let now: Date
  @State private var picking = false
  @State private var selection = FamilyActivitySelection()
  /// What Apple's picker returned when it was not one app.
  @State private var refused: FamilyActivitySelection?
  /// "Choose a different app" sets the block screen's app aside.
  @State private var otherApp = false
  /// The app picked isn't on a block that's on.
  @State private var notBlocked = false

  var body: some View {
    content
      .transition(.opacity)
      .animation(Motion.movement, value: model.state.door?.phase)
      .animation(Motion.movement, value: refused)
      .animation(Motion.movement, value: otherApp)
      .animation(Motion.movement, value: notBlocked)
      .tollHaptic(.light, trigger: model.state.door?.phase)
      .familyActivityPicker(isPresented: $picking, selection: $selection)
      .onChange(of: picking) { _, isOpen in
        guard !isOpen else { return }
        // Apple's picker cannot be limited to one app, so anything else is asked again.
        let apps = selection.applicationTokens
        if apps.count == 1, let app = apps.first, selection.categoryTokens.isEmpty {
          refused = nil
          notBlocked = !model.startDoor(app)
        } else if !apps.isEmpty || !selection.categoryTokens.isEmpty {
          refused = selection
        }
        selection = FamilyActivitySelection()
      }
  }

  @ViewBuilder private var content: some View {
    if let door = model.state.door {
      switch door.phase {
      case .waiting: DoorWaiting(model: model, door: door)
      case .open: DoorOpen(model: model, door: door, now: now)
      }
    } else if model.state.unlocks.left(model.config) == 0 {
      DoorNoneLeft(model: model)
    } else if notBlocked {
      DoorNotBlocked(model: model) {
        notBlocked = false
        picking = true
      }
    } else if let refused {
      DoorChooseOne(model: model, picked: refused) { picking = true }
    } else if !otherApp, let app = DoorApp.token(from: model.state.doorAskedFor) {
      DoorFromShield(model: model, app: app) { otherApp = true }
    } else {
      DoorChoose(model: model) { picking = true }
    }
  }
}

/// Door · choose: the question, the unlocks, the wait, and Apple's picker.
private struct DoorChoose: View {
  let model: AppModel
  let choose: () -> Void

  var body: some View {
    SheetPage(height: 414, overhang: 16) {
      SheetTitle(Copy.Door.question(minutes: model.config.door.minutes))
      UnlockPips(left: model.state.unlocks.left(model.config), max: model.config.unlocks.max)
        .padding(.top, 16)
      WaitNote(seconds: model.config.door.waitSeconds).padding(.top, 20)
    } actions: {
      PrimaryButton(Copy.Door.chooseApp, action: choose)
      QuietButton(Copy.Door.notNow) { model.dismissDoor() }.frame(maxWidth: .infinity)
    }
  }
}

/// Door · from the block screen (D41): the app is already chosen.
private struct DoorFromShield: View {
  let model: AppModel
  let app: ApplicationToken
  let chooseDifferent: () -> Void

  var body: some View {
    // The board's 464 plus a 44 pt row for Not now, which the board lacks (#47).
    SheetPage(height: 508, overhang: 16) {
      Label(app).labelStyle(DoorAppStyle(size: 40, radius: 10, title: .sheetApp))
      SheetTitle(Copy.Door.openFor(minutes: model.config.door.minutes)).padding(.top, 18)
      UnlockPips(left: model.state.unlocks.left(model.config), max: model.config.unlocks.max)
        .padding(.top, 14)
      WaitNote(seconds: model.config.door.waitSeconds).padding(.top, 18)
    } actions: {
      PrimaryButton(Copy.Door.startWait) { _ = model.startDoor(app) }
      QuietButton(Copy.Door.chooseDifferent, action: chooseDifferent).frame(maxWidth: .infinity)
      QuietButton(Copy.Door.notNow) { model.dismissDoor() }.frame(maxWidth: .infinity)
    }
  }
}

/// Door · picked more than one, or a whole category: what was picked, and the picker again.
private struct DoorChooseOne: View {
  let model: AppModel
  let picked: FamilyActivitySelection
  let chooseAgain: () -> Void

  var body: some View {
    let categoryOnly = picked.applicationTokens.isEmpty
    SheetPage(height: categoryOnly ? 424 : 454, overhang: 16) {
      SheetTitle(Copy.Door.chooseOneTitle)
      Text(
        categoryOnly
          ? Copy.Door.pickedCategory
          : Copy.Door.pickedSeveral(picked.applicationTokens.count + picked.categoryTokens.count)
      )
      .tollType(.body, TollColor.label2)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 10)
      VStack(spacing: 0) {
        Group(subviews: rows) { rows in
          ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
            if index > 0 { Hairline() }
            row
          }
        }
      }
      .padding(.horizontal, TollSpacing.cardPadding)
      .background(
        TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
      )
      .padding(.top, 20)
    } actions: {
      PrimaryButton(Copy.Door.chooseAgain, action: chooseAgain)
      QuietButton(Copy.Door.notNow) { model.dismissDoor() }.frame(maxWidth: .infinity)
    }
  }

  @ViewBuilder private var rows: some View {
    ForEach(Array(picked.categoryTokens), id: \.self) { token in
      Label(token).labelStyle(AppRowLabelStyle(detail: Copy.Blocks.wholeCategory))
    }
    ForEach(Array(picked.applicationTokens.prefix(3)), id: \.self) { token in
      Label(token).labelStyle(AppRowLabelStyle()).frame(minHeight: 50)
    }
  }
}

/// Door · waiting: the app, a big countdown, and a neutral Cancel.
private struct DoorWaiting: View {
  let model: AppModel
  let door: Door

  var body: some View {
    SheetPage(height: 464, overhang: 8) {
      if let token = DoorApp.token(from: door.app) {
        Label(token).labelStyle(
          DoorAppStyle(
            size: 40, radius: 10, title: .sheetApp, gap: 12,
            detail: Copy.Door.onceWaitEnds(minutes: model.config.door.minutes)))
      }
      Countdown(endsAt: door.waitEndsAt, text: { $0 }, spoken: Copy.Door.opensInSpoken)
        .tollType(
          TollType(size: 72, lineHeight: 76, weight: .semibold, style: .largeTitle, tabular: true)
        )
        .foregroundStyle(TollColor.label)
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        // The monitor opens the door when its interval starts; this covers a late callback.
        .task(id: door.waitEndsAt) {
          try? await Task.sleep(for: .seconds(max(0, door.waitEndsAt.timeIntervalSinceNow)))
          model.send(.doorStart)
        }
      Text(Copy.Door.leaveFreely)
        .tollType(TollType(size: 14, lineHeight: 20, weight: .regular, style: .subheadline))
        .foregroundStyle(TollColor.label2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    } actions: {
      PrimaryButton(Copy.Door.cancel, tone: .neutral) { model.cancelDoor() }
      Footnote(Copy.Door.cancelFree, alignment: .center).padding(.top, 10)
    }
  }
}

/// Door · open, counting down (D31): the app, "Open now", when it locks, the time left, a bar, and
/// the regret line while it lasts (D-4).
private struct DoorOpen: View {
  let model: AppModel
  let door: Door
  let now: Date

  var body: some View {
    SheetPage(height: 544) {
      if let token = DoorApp.token(from: door.app) {
        Label(token).labelStyle(DoorAppStyle(size: 32, radius: 8, title: .rowApp))
      }
      SheetTitle(Copy.Door.isOpen).padding(.top, 16)
      if let expiresAt = door.expiresAt {
        Text(Copy.Door.locksAt(Copy.time(expiresAt)))
          .tollType(.body, TollColor.label2)
          .padding(.top, 4)
        // iOS can't open another app from its token, so say where it is.
        Text(Copy.Door.fromHomeScreen).tollType(.body, TollColor.label2)
        // On the clock (D31): the monitor closes it at this moment even with the app closed.
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
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4).fill(TollColor.surfaceRaised)
            RoundedRectangle(cornerRadius: 4).fill(TollColor.accent)
              .frame(width: proxy.size.width * left / total)
          }
        }
        .frame(height: 8)
        .padding(.top, 16)
        .accessibilityHidden(true)
      }
      if let regretEnd = door.regretEndsAt(model.config), now < regretEnd {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "clock").unredacted()
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
      PrimaryButton(Copy.Door.lockAgain) { model.lockDoor() }
    }
  }
}
