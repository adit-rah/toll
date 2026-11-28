@preconcurrency import FamilyControls
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// New block and Block · edit, pushed from Blocks. A new block starts at its kind: picking one opens
/// Apple's apps picker straight away, and the kind's name and hours are already filled in, so what's
/// left is Save; the place is optional and last (#89). Editing changes the name, the kind (#62) and
/// the hours in place. The night is the user's nights: no name, no kind and no Delete (D68).
struct BlockEditorView: View {
  @State private var model: BlockEditorModel
  @Environment(\.dismiss) private var dismiss
  @State private var picking = false
  @State private var showingApps = false
  @State private var choosingPlace = false
  @State private var confirmingDelete = false
  @State private var askingAlways = false
  /// The night's place is home, set with the same map as Tonight and Settings (the audit).
  @State private var settingHome = false
  /// What was chosen when the editor opened: the Apps row animates only what arrives after.
  @State private var appsAtOpen: FamilyActivitySelection
  @Environment(\.dynamicTypeSize) private var typeSize

  /// `pickingApps` opens Apple's picker straight away: Tonight's note for a night that came back
  /// without its apps (#140).
  init(app: AppModel, editing id: BlockID?, pickingApps: Bool = false) {
    let model = BlockEditorModel(app: app, editing: id)
    _model = State(initialValue: model)
    _appsAtOpen = State(initialValue: model.selection)
    _picking = State(initialValue: pickingApps)
    #if DEBUG
      // Renders can't tap Place or Delete; their scenarios open on them (docs/renders.md).
      _choosingPlace = State(initialValue: DemoScenario.current == .blockPlace)
      _confirmingDelete = State(initialValue: DemoScenario.current == .blockDelete)
    #endif
  }

  var body: some View {
    Group {
      if model.kindPicked {
        page.tollBottomBar { actions }
      } else {
        page
      }
    }
    .background(TollColor.bg)
    .tollPushed(model.title)
    // The tab bar floats over the bottom of the screen; an editor's Save sits there.
    .toolbar(.hidden, for: .tabBar)
    .familyActivityPicker(isPresented: $picking, selection: $model.selection)
    .navigationDestination(isPresented: $showingApps) { BlockAppsView(model: model) }
    .navigationDestination(isPresented: $choosingPlace) {
      PlacePicker(app: model.app, place: model.place) { model.place = $0 }
    }
    .sheet(isPresented: $askingAlways) {
      if let question = model.alwaysQuestion {
        WithoutAlwaysSheet(place: question.place, line: question.body) { only in
          model.block.onlyAtPlace = only
          if model.save() { dismiss() }
        }
      }
    }
    .sheet(isPresented: $settingHome) {
      SetHomeFlow(app: model.app) {
        settingHome = false
        model.homeChanged()
      }
    }
    .sheet(isPresented: $confirmingDelete) {
      DeleteBlockSheet(model: model) { if model.delete() { dismiss() } }
    }
  }

  private var page: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        EditorTitle(
          text: model.title, kind: model.kindPicked ? model.block.kind : nil)
        if model.kindPicked {
          details
        } else {
          SetupLine(Copy.Blocks.kindLine).padding(.top, 8)
          KindChips(model: model) { picking = $0 }.padding(.top, 24)
        }
      }
      .tollGutter()
      .padding(.bottom, 24)
    }
    .scrollDismissesKeyboard(.interactively)
  }

  @ViewBuilder private var details: some View {
    if !model.isSleep {
      KindChips(model: model) { picking = $0 }.padding(.top, 20)
    }
    Card {
      if !model.isSleep { NameRow(name: $model.name) }
      Button {
        if model.hasApps { showingApps = true } else { picking = true }
      } label: {
        AppsRow(model: model, atOpen: appsAtOpen)
      }
      .buttonStyle(.plain)
      ForEach(model.block.schedule.rules.indices, id: \.self) { index in
        let rule = model.block.schedule.rules[index]
        HoursInline(
          title: hoursTitle(index), rule: rule, isNight: model.isSleep, length: length(rule.window)
        ) { model.setRule(index, $0) }
      }
      Button {
        if model.isSleep { settingHome = true } else { choosingPlace = true }
      } label: {
        CardRow(Copy.Blocks.place, detail: model.place?.name ?? Copy.Blocks.anywhere) {
          IconTile(placeSymbol, accent: false)
        } trailing: {
          Chevron()
        }
      }
      .buttonStyle(.plain)
    }
    .padding(.top, model.isSleep ? TollSpacing.titleToContent : 12)
    // Last and apart: a quiet card under the block's details, never above them (D105).
    if model.savedSwitch != nil {
      Card {
        SwitchRow(isOn: $model.block.isOn, line: model.switchLine, locked: model.switchLocked)
      }
      .padding(.top, 12)
    }
    notes
  }

  @ViewBuilder private var notes: some View {
    let limits = model.limits()
    if model.windowsOver {
      NoteCard(Copy.Blocks.windowsFull(limits.windowsMax), severity: .broken).padding(.top, 12)
    }
    if limits.appsOver > 0 {
      NoteCard(
        Copy.Blocks.overLimit(limits.appsMax, remove: limits.appsOver), severity: .broken
      )
      .padding(.top, 12)
    }
    if let ignored = model.placeIgnored {
      NoteCard(ignored, severity: .degraded) {
        SettingsLink(Copy.Setup.changeInSettings, action: openSystemSettings)
      }
      .padding(.top, 12)
    }
    if !model.isSleep, model.isNew {
      Footnote(Copy.Blocks.explainer).padding(.top, 12)
    }
    if let refusal = model.refusal {
      NoteCard(refusal, severity: .broken).padding(.top, 12)
    }
    if typeSize.isAccessibilitySize {
      // At accessibility sizes the bar keeps only Save, so it doesn't cover the page (#162): Delete
      // and the note end the page instead, the note last, so its coming moves nothing above it.
      VStack(alignment: .leading, spacing: 12) {
        if !model.isNew && !model.isSleep { delete }
        if let note = model.activeNote {
          NoteCard(note, symbol: .blocked).transition(.opacity)
        }
      }
      .padding(.top, 24)
      .animation(Motion.stateChange, value: model.activeNote)
    }
  }

  private var delete: some View {
    DestructiveQuiet(Copy.Blocks.delete) { confirmingDelete = true }
  }

  /// The note for a block that's on sits at the top of the pinned bar, over Save, which says when the
  /// edit applies (B-3): when the block comes on mid-edit the bar grows upward and nothing on the page
  /// or in the bar moves (#133, design §2.5). At accessibility sizes only Save is pinned.
  private var actions: some View {
    VStack(spacing: 0) {
      if !typeSize.isAccessibilitySize {
        if let note = model.activeNote {
          NoteCard(note, symbol: .blocked)
            .padding(.bottom, 12)
            .transition(.opacity)
        }
        if !model.isNew && !model.isSleep {
          delete.padding(.bottom, 10)
        }
      }
      PrimaryButton(saveTitle) {
        if model.asksAboutAlways {
          askingAlways = true
        } else if model.save() {
          dismiss()
        }
      }
      .disabled(!model.canSave)
    }
    .animation(Motion.stateChange, value: model.activeNote)
  }

  private var saveTitle: String {
    if model.isNew { return Copy.Blocks.save }
    if let end = model.activeUntil { return Copy.Blocks.saveAfter(Copy.time(end)) }
    return Copy.Blocks.saveEdit
  }

  /// House for Home, a pin for another place, a globe for none (#78, design §2.6).
  private var placeSymbol: TollSymbol {
    guard let place = model.place else { return .anywhere }
    return model.app.state.isHome(place.id) ? .home : .place
  }

  /// The night's length is its sleep, with the minutes apps lock before and after it (D76, #144).
  private func length(_ window: TimeWindow) -> String {
    guard model.isSleep else { return Copy.Blocks.length(minutes: window.minutes) }
    let state = model.app.state
    return Copy.Blocks.nightLength(
      minutes: window.minutes, before: state.gap.minutes, after: state.after.minutes)
  }

  /// The night with weekends different has two rules; name them as setup did (#49).
  private func hoursTitle(_ index: Int) -> String {
    guard model.isSleep, model.block.schedule.rules.count == 2 else { return Copy.Blocks.hours }
    return index == 0 ? Copy.Setup.weeknights : Copy.Setup.weekendNights
  }
}
