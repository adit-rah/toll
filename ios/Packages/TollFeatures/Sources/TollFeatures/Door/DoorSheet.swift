@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// The door (spec §7 Door), a sheet over Status opened from the block screen: choosing, waiting, open,
/// or none left. Its parts crossfade inside the sheet; the sheet itself does not move (design §2.5).
struct DoorSheet: View {
  let model: AppModel
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
      content
        .transition(.opacity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .tollGutter()
    .padding(.top, TollSpacing.titleGap)
    .background(TollColor.bg)
    .animation(Motion.movement, value: model.state.door?.phase)
    .tollHaptic(.light, trigger: model.state.door?.phase)
    .presentationDetents([.medium, .large])
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

private struct DoorChoosing: View {
  let model: AppModel
  @State private var picking = false
  @State private var selection = FamilyActivitySelection()
  @State private var tooMany = false

  var body: some View {
    DoorTitle(Copy.Door.question(minutes: model.config.door.minutes))
    UnlocksLine(model: model)
    if tooMany { Text(Copy.Door.chooseOne).tollText(.subhead) }
    Spacer(minLength: 0)
    PrimaryButton(Copy.Door.chooseApp) { picking = true }
    QuietButton(Copy.Door.notNow) { model.dismissDoor() }
      .frame(maxWidth: .infinity)
      .familyActivityPicker(isPresented: $picking, selection: $selection)
      .onChange(of: picking) { _, isOpen in
        guard !isOpen else { return }
        // The system picker cannot be limited to one, so anything but exactly one app is asked again.
        let apps = selection.applicationTokens
        guard apps.count == 1, let app = apps.first else {
          tooMany = !apps.isEmpty || !selection.categoryTokens.isEmpty
          return
        }
        tooMany = false
        model.startDoor(app)
      }
  }
}

private struct DoorWaiting: View {
  let model: AppModel
  let door: Door

  var body: some View {
    AppIcon(app: door.app)
    Countdown(
      endsAt: door.waitEndsAt, text: Copy.Door.opensIn, spoken: Copy.Door.opensInSpoken
    )
    .font(TollFont.screenTitle)
    .foregroundStyle(TollColor.label)
    Text(Copy.Door.cancelFree).tollText(.subhead)
    Spacer(minLength: 0)
    QuietButton(Copy.Door.cancel) { model.cancelDoor() }
      .frame(maxWidth: .infinity)
      // The monitor opens the door when its interval starts; this covers a late callback.
      .task(id: door.waitEndsAt) {
        try? await Task.sleep(for: .seconds(max(0, door.waitEndsAt.timeIntervalSinceNow)))
        model.reconcile(.doorStart)
      }
  }
}

private struct DoorOpen: View {
  let model: AppModel
  let door: Door
  let now: Date

  var body: some View {
    AppIcon(app: door.app)
    DoorTitle(Copy.Door.open(minutes: model.config.door.minutes))
    if let regretEnd = door.regretEndsAt(model.config), now < regretEnd {
      Text(Copy.Door.regret(minutes: model.config.door.regretSeconds / 60))
        .tollText(.subhead)
        .transition(.opacity)
    }
    Spacer(minLength: 0)
    PrimaryButton(Copy.Door.lockAgain) { model.lockDoor() }
  }
}

private struct DoorNoneLeft: View {
  let model: AppModel

  var body: some View {
    DoorTitle(
      Copy.Door.noneLeft(
        nights: model.state.unlocks.nightsToRefill(model.config)
          ?? model.config.unlocks.refillNights))
    Spacer(minLength: 0)
    QuietButton(Copy.Door.notNow) { model.dismissDoor() }
      .frame(maxWidth: .infinity)
  }
}

struct UnlocksLine: View {
  let model: AppModel

  var body: some View {
    Text(
      Copy.Door.unlocksLeft(model.state.unlocks.left(model.config), of: model.config.unlocks.max)
    )
    .tollText(.body)
    .monospacedDigit()
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

/// The system's icon for the chosen app; the app never learns which app it is.
private struct AppIcon: View {
  let app: Data

  var body: some View {
    if let token = DoorApp.token(from: app) {
      Label(token)
        .labelStyle(.iconOnly)
        .scaleEffect(2, anchor: .leading)
        .frame(height: 64, alignment: .leading)
    }
  }
}
