import SwiftUI
import TollCore
import TollUI

/// Settings › Sleep (#144, was "Before bed", D76): sleep and the time either side of it in one
/// place, and the helpers Tonight offers before sleep (D80). The row says the hours and both
/// buffers; a tap pushes the screen that changes them.
struct SleepRow: View {
  let model: AppModel

  var body: some View {
    NavigationLink(value: HomeRoute.sleep) {
      SettingsRow(Copy.Fit.row, detail: BeforeBed.sleepRow(model.state)) { Chevron() }
    }
    .buttonStyle(.plain)
  }
}

/// Sleep, the buffer before and the one after, each growing toward a target or fixed, and the
/// helpers. Save applies it all; Back leaves things as they were. A change while the night is on
/// applies from tomorrow night (B-3), and the screen says so.
struct SleepSettingsView: View {
  let model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var draft: FitDraft
  @State private var before: BufferChoice
  @State private var after: BufferChoice
  @State private var helpers: Bool
  @State private var breath: Int
  private let nightOn: Bool

  init(model: AppModel) {
    self.model = model
    // The hours as last chosen, a change held through tonight included (B-3); the buffers are
    // edited apart, growing or fixed.
    let none = Fit.Buffer(start: 0, target: 0)
    _draft = State(
      initialValue: FitDraft(
        config: model.config, schedule: model.sleepDraft?.schedule, before: none, after: none,
        health: model.state.health))
    let snapshot = BeforeBed(state: model.state, side: .before, config: model.config)
    _before = State(initialValue: BufferChoice(snapshot))
    _after = State(
      initialValue: BufferChoice(BeforeBed(state: model.state, side: .after, config: model.config)))
    _helpers = State(initialValue: model.state.helpers.on)
    _breath = State(initialValue: model.breathMinutes)
    nightOn = snapshot.nightOn
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Fit.sheetTitle, kind: .pushed)
        SetupLine(Copy.Fit.sheetBody).padding(.top, TollSpacing.titleToLine)
        if let picture = NightPicture(
          .everyDay(draft.window), gap: before.minutes, after: after.minutes, now: Date(),
          calendar: .current)
        {
          NightPictureView(picture: picture).padding(.top, 20)
        }
        SleepTimesCard(draft: draft).padding(.top, 20)
        BufferChoiceCard(side: .before, choice: $before, config: model.config).padding(.top, 12)
        BufferChoiceCard(side: .after, choice: $after, config: model.config).padding(.top, 12)
        if nightOn {
          Footnote(Copy.Gap.tonightStays).padding(.top, TollSpacing.underCard)
        }
        helpersCard.padding(.top, 12)
      }
      .tollGutter()
      .padding(.bottom, 24)
    }
    .background(TollColor.bg)
    .tollPushed(Copy.Fit.sheetTitle)
    .tollBottomBar {
      PrimaryButton(Copy.Fit.save) {
        save()
        dismiss()
      }
      .disabled(!draft.schedule.isValid)
    }
  }

  private var helpersCard: some View {
    Card {
      Toggle(isOn: $helpers) {
        RowText(title: Copy.Helpers.setting, detail: Copy.Helpers.settingDetail)
      }
      .tint(TollColor.accent)
      .padding(.vertical, 8)
      .frame(minHeight: 54)
      if helpers {
        Stepper(value: $breath, in: model.config.helpers.breathRange) {
          HStack(spacing: 8) {
            Image(symbol: .breathe).unredacted()
              .font(.system(size: 15, weight: .medium))
              .foregroundStyle(TollColor.label2)
              .accessibilityHidden(true)
            Text(Copy.Helpers.breathLength(breath)).tollType(.rowTitle, TollColor.label)
          }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 54)
      }
    }
  }

  private func save() {
    var sleep = model.sleepDraft
    if sleep?.schedule == draft.schedule { sleep = nil }
    sleep?.schedule = draft.schedule
    model.saveSleep(
      sleep, before: (before.setting, before.target), after: (after.setting, after.target),
      helpers: Helpers(on: helpers, breathMinutes: breath))
  }
}

/// One side as Settings edits it: growing from tonight's minutes toward a target, or fixed.
struct BufferChoice: Equatable {
  var grows: Bool
  var minutes: Int
  var target: Int

  init(_ snapshot: BeforeBed) {
    grows = snapshot.grows
    minutes = snapshot.minutes
    target = max(snapshot.target, snapshot.minutes)
  }

  var setting: Gap.Setting { grows ? .grows(minutes) : .fixed(minutes) }
}

/// A side's card: its glyph and words, growing or fixed with a tick (never colour alone), and the
/// numbers each needs.
struct BufferChoiceCard: View {
  let side: Gap.Side
  @Binding var choice: BufferChoice
  let config: TollConfig

  var body: some View {
    let limits = config.limits(side)
    Card {
      CardRow(
        side == .before ? Copy.Fit.before : Copy.Fit.after,
        detail: choice.grows
          ? Copy.Fit.grows(choice.minutes, to: choice.target) : Copy.Gap.fixedDetail(choice.minutes)
      ) {
        IconTile(side == .before ? .beforeBed : .afterWake)
      }
      option(Copy.Gap.grows, chosen: choice.grows) { choice.grows = true }
      option(Copy.Gap.fixed, chosen: !choice.grows) { choice.grows = false }
      MinutesRow(
        title: choice.grows ? Copy.Fit.tonight : Copy.Gap.fixedOption, minutes: choice.minutes,
        range: 0...(choice.grows ? choice.target : limits.manualMax),
        step: choice.grows ? 5 : limits.manualStep
      ) { choice.minutes = $0 }
      if choice.grows {
        MinutesRow(
          title: Copy.Fit.growsTo, minutes: choice.target, range: 0...limits.manualMax,
          step: limits.manualStep
        ) { choice.target = max($0, choice.minutes) }
      }
    }
    .tollHaptic(.selection, trigger: choice.grows)
  }

  private func option(_ title: String, chosen: Bool, pick: @escaping () -> Void) -> some View {
    Button(action: pick) {
      HStack(spacing: TollSpacing.rowGap) {
        Text(title).tollType(.rowTitle, TollColor.label)
        Spacer(minLength: 0)
        Image(symbol: .done).unredacted()
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(TollColor.accent)
          .opacity(chosen ? 1 : 0)
          .accessibilityHidden(true)
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(chosen ? .isSelected : [])
  }
}
