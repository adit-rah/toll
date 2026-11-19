@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// The door (the design canvas; D-1 to D-7, D31), a sheet over Home opened from the block screen's
/// "Unlock in Dusk" or Home's "Open one app": choosing, waiting, open, or none left. Its parts crossfade
/// inside the sheet; the sheet itself does not move (design §2.5).
struct DoorSheet: View {
  let model: AppModel
  let now: Date
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    // Scrolls so nothing is cut off at accessibility sizes, where the sheet also opens full height.
    ScrollView {
      VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
        content.transition(.opacity)
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .tollGutter()
      .padding(.vertical, TollSpacing.titleGap)
    }
    .background(TollColor.bg)
    .animation(Motion.movement, value: model.state.door?.phase)
    .tollHaptic(.light, trigger: model.state.door?.phase)
    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
  }

  @ViewBuilder private var content: some View {
    if let door = model.state.door {
      switch door.phase {
      case .waiting: DoorWaiting(model: model, door: door)
      case .open: DoorOpen(model: model, door: door, now: now)
      }
    } else if model.state.unlocks.left(model.config) == 0 {
      DoorNoneLeft(model: model)
    } else {
      DoorChoosing(model: model)
    }
  }
}

/// The blocked apps are listed by their system names to tap; one inside a blocked category is not on
/// the list by itself, so "Another app" opens the system picker for it (D27).
private struct DoorChoosing: View {
  let model: AppModel
  @State private var picking = false
  @State private var selection = FamilyActivitySelection()
  @State private var tooMany = false

  var body: some View {
    let choices = model.doorChoices
    DoorTitle(Copy.Door.question(minutes: model.config.door.minutes))
    UnlockPips(left: model.state.unlocks.left(model.config), max: model.config.unlocks.max)
    Footnote(Copy.Door.waitFirst(seconds: model.config.door.waitSeconds))
    if !choices.applicationTokens.isEmpty {
      Card {
        ForEach(Array(choices.applicationTokens.enumerated()), id: \.offset) { _, token in
          Button {
            model.startDoor(token)
          } label: {
            Label(token)
              .font(TollFont.bodyMedium)
              .foregroundStyle(TollColor.label)
              .frame(maxWidth: .infinity, minHeight: TollSpacing.rowMinHeight, alignment: .leading)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
    }
    if tooMany { Footnote(Copy.Door.chooseOne) }
    if !choices.categoryTokens.isEmpty || choices.applicationTokens.isEmpty {
      QuietButton(Copy.Door.anotherApp) { picking = true }
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        .onChange(of: picking) { _, isOpen in
          guard !isOpen else { return }
          // The system picker cannot be limited to one, so anything but one app is asked again.
          let apps = selection.applicationTokens
          guard apps.count == 1, let app = apps.first else {
            tooMany = !apps.isEmpty || !selection.categoryTokens.isEmpty
            return
          }
          tooMany = false
          model.startDoor(app)
        }
    }
    QuietButton(Copy.Door.notNow, tone: .secondary) { model.dismissDoor() }
      .frame(maxWidth: .infinity)
  }
}

private struct DoorWaiting: View {
  let model: AppModel
  let door: Door

  var body: some View {
    AppName(app: door.app)
    Footnote(Copy.Door.onceWaitEnds(minutes: model.config.door.minutes))
    Countdown(endsAt: door.waitEndsAt, text: { $0 }, spoken: Copy.Door.opensInSpoken)
      .font(.system(size: 64, weight: .semibold, design: .rounded))
      .foregroundStyle(TollColor.label)
      .frame(maxWidth: .infinity)
      // The monitor opens the door when its interval starts; this covers a late callback.
      .task(id: door.waitEndsAt) {
        try? await Task.sleep(for: .seconds(max(0, door.waitEndsAt.timeIntervalSinceNow)))
        model.send(.doorStart)
      }
    Footnote(Copy.Door.leaveFreely)
    QuietButton(Copy.Door.cancel) { model.cancelDoor() }
      .frame(maxWidth: .infinity)
    Footnote(Copy.Door.cancelFree)
  }
}

private struct DoorOpen: View {
  let model: AppModel
  let door: Door
  let now: Date

  var body: some View {
    AppName(app: door.app, detail: Copy.Door.isOpen)
    Text(Copy.Door.forMinutes(model.config.door.minutes))
      .font(TollFont.subhead).foregroundStyle(TollColor.label2)
    if let expiresAt = door.expiresAt {
      // On the clock (D31): the monitor closes it at this moment even with the app closed.
      let total = TimeInterval(model.config.door.minutes * 60)
      ProgressView(value: max(0, min(total, expiresAt.timeIntervalSince(now))), total: total)
        .tint(TollColor.accent)
        .accessibilityHidden(true)
      Countdown(endsAt: expiresAt, text: Copy.Door.left, spoken: Copy.Door.leftSpoken)
        .font(TollFont.title)
        .foregroundStyle(TollColor.label)
        .task(id: expiresAt) {
          try? await Task.sleep(for: .seconds(max(0, expiresAt.timeIntervalSinceNow)))
          model.send(.doorEnd)
        }
    }
    if let regretEnd = door.regretEndsAt(model.config), now < regretEnd {
      Countdown(endsAt: regretEnd, text: Copy.Door.regretFor, spoken: Copy.Door.leftSpoken)
        .font(TollFont.subhead)
        .foregroundStyle(TollColor.label2)
        .transition(.opacity)
    }
    PrimaryButton(Copy.Door.lockAgain) { model.lockDoor() }
  }
}

private struct DoorNoneLeft: View {
  let model: AppModel

  var body: some View {
    DoorTitle(Copy.Door.noneTitle)
    UnlockPips(left: 0, max: model.config.unlocks.max)
    Footnote(
      Copy.Door.refillLine(
        model.state.unlocks.nightsToRefill(model.config) ?? model.config.unlocks.refillNights,
        after: model.config.unlocks.refillNights))
    Footnote(Copy.Door.othersWork)
    PrimaryButton(Copy.Door.ok) { model.dismissDoor() }
  }
}

/// Unlocks as dots, with the count beside them in words (never the dots alone).
struct UnlockPips: View {
  let left: Int
  let max: Int

  var body: some View {
    HStack(spacing: 10) {
      HStack(spacing: 6) {
        ForEach(0..<max, id: \.self) { index in
          Circle()
            .fill(index < left ? TollColor.accent : TollColor.fill)
            .frame(width: 10, height: 10)
        }
      }
      Text(Copy.Door.unlocksOf(left, max)).font(TollFont.subhead).monospacedDigit()
        .foregroundStyle(TollColor.label2)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.Door.unlocksOf(left, max))
  }
}

private struct DoorTitle: View {
  let text: String
  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(TollFont.screenTitle)
      .foregroundStyle(TollColor.label)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }
}

/// The chosen app by the system's own icon and name; the app never learns which app it is.
private struct AppName: View {
  let app: Data
  var detail: String?

  var body: some View {
    if let token = DoorApp.token(from: app) {
      VStack(alignment: .leading, spacing: 4) {
        Label(token).font(TollFont.title).foregroundStyle(TollColor.label)
        if let detail { Text(detail).font(TollFont.subhead).foregroundStyle(TollColor.accent) }
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
    }
  }
}
