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
  @State private var editing: Gap.Side?
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
    #if DEBUG
      _editing = State(initialValue: DemoScenario.current?.bufferSheet)
    #endif
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
          .everyDay(draft.window), gap: before.tonight, after: after.tonight, now: Date(),
          calendar: .current)
        {
          NightPictureView(picture: picture).padding(.top, 20)
        }
        SleepTimesCard(draft: draft).padding(.top, 20)
        // One row a side, as onboarding draws them; each opens its own small sheet.
        Card {
          BufferRow(side: .before, detail: before.summary) { editing = .before }
          BufferRow(side: .after, detail: after.summary) { editing = .after }
        }
        .padding(.top, 12)
        if nightOn {
          Footnote(Copy.Gap.tonightStays).padding(.top, TollSpacing.underCard)
        }
        helpersCard.padding(.top, 12)
      }
      .tollGutter()
      .padding(.bottom, 24)
    }
    .background(TollColor.bg)
    .sheet(
      isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    ) {
      if let side = editing {
        BufferChoiceSheet(
          side: side, choice: side == .before ? $before : $after, config: model.config
        ) { editing = nil }
      }
    }
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
  enum Mode: Equatable { case grows, fixed, none }

  var mode: Mode
  var minutes: Int
  var target: Int

  init(_ snapshot: BeforeBed) {
    mode = snapshot.grows ? .grows : snapshot.minutes == 0 ? .none : .fixed
    minutes = snapshot.minutes
    target = max(snapshot.target, snapshot.minutes)
  }

  var setting: Gap.Setting {
    switch mode {
    case .grows: .grows(minutes)
    case .fixed: .fixed(minutes)
    case .none: .fixed(0)
    }
  }

  /// Tonight's minutes as the picture draws them.
  var tonight: Int { mode == .none ? 0 : minutes }

  /// The row's line: what it does tonight and grows to, fixed, or none.
  var summary: String {
    switch mode {
    case .grows: Copy.Fit.grows(minutes, to: target)
    case .fixed: Copy.Gap.fixedDetail(minutes)
    case .none: Copy.Fit.off
    }
  }
}

/// One side in its own small sheet: growing from tonight's minutes toward a target, fixed, or none,
/// each with a tick (never colour alone), and only the numbers the choice needs.
struct BufferChoiceSheet: View {
  let side: Gap.Side
  @Binding var choice: BufferChoice
  let config: TollConfig
  let close: () -> Void

  var body: some View {
    let limits = config.limits(side)
    SheetPage(height: 520) {
      SheetTitle(side == .before ? Copy.Fit.before : Copy.Fit.after)
      SheetBody(side == .before ? Copy.Fit.beforeSheet : Copy.Fit.afterSheet)
      VStack(spacing: 0) {
        TickRow(title: Copy.Gap.grows, chosen: choice.mode == .grows) {
          choice.mode = .grows
          // Growing from nothing would stay at nothing until a smooth week: start where a new
          // install does.
          if choice.minutes == 0 { choice.minutes = min(limits.start, choice.target) }
        }
        Hairline()
        TickRow(title: Copy.Gap.fixed, chosen: choice.mode == .fixed) { choice.mode = .fixed }
        Hairline()
        TickRow(title: Copy.Fit.off, chosen: choice.mode == .none) { choice.mode = .none }
        switch choice.mode {
        case .grows:
          Hairline()
          MinutesRow(
            title: Copy.Fit.tonight, minutes: choice.minutes, range: 0...choice.target, step: 5
          ) { choice.minutes = $0 }
          Hairline()
          MinutesRow(
            title: Copy.Fit.growsTo, minutes: choice.target, range: 0...limits.manualMax,
            step: limits.manualStep
          ) { choice.target = max($0, choice.minutes) }
        case .fixed:
          Hairline()
          MinutesRow(
            title: Copy.Gap.fixedOption, minutes: choice.minutes, range: 0...limits.manualMax,
            step: limits.manualStep
          ) { choice.minutes = $0 }
        case .none:
          EmptyView()
        }
      }
      .padding(.top, 16)
    } actions: {
      PrimaryButton(Copy.Fit.done, action: close)
    }
    .tollHaptic(.selection, trigger: choice.mode)
  }
}
