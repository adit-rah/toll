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

  init(app: AppModel, editing id: BlockID?) {
    _model = State(initialValue: BlockEditorModel(app: app, editing: id))
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
    if let note = model.activeNote {
      NoteCard(note, symbol: .blocked).padding(.top, 16)
    }
    if !model.isSleep {
      KindChips(model: model) { picking = $0 }.padding(.top, 20)
    }
    Card {
      if !model.isSleep { NameRow(name: $model.name) }
      Button {
        if model.hasApps { showingApps = true } else { picking = true }
      } label: {
        CardRow(Copy.Blocks.apps, detail: model.appsSummary) {
          // The row Save is waiting for is drawn as a slot to fill (#78).
          if model.hasApps { IconTile(.apps, accent: false) } else { EmptyTile(.apps) }
        } trailing: {
          Chevron()
        }
      }
      .buttonStyle(.plain)
      ForEach(model.block.schedule.rules.indices, id: \.self) { index in
        HoursInline(
          title: hoursTitle(index), rule: model.block.schedule.rules[index]
        ) { model.setRule(index, $0) }
      }
      Button {
        choosingPlace = true
      } label: {
        CardRow(Copy.Blocks.place, detail: model.place?.name ?? Copy.Blocks.anywhere) {
          IconTile(placeSymbol, accent: false)
        } trailing: {
          Chevron()
        }
      }
      .buttonStyle(.plain)
    }
    .padding(.top, model.isSleep && model.activeNote == nil ? TollSpacing.titleToContent : 12)
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
    if model.isSleep {
      Footnote(Copy.Blocks.sleepStays).padding(.top, 12)
    } else if model.isNew {
      Footnote(Copy.Blocks.explainer).padding(.top, 12)
    }
    if let refusal = model.refusal {
      NoteCard(refusal, severity: .broken).padding(.top, 12)
    }
  }

  private var actions: some View {
    VStack(spacing: 0) {
      if !model.isNew && !model.isSleep {
        DestructiveQuiet(Copy.Blocks.delete) { confirmingDelete = true }
          .padding(.bottom, 10)
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

  /// The night with weekends different has two rules; name them as setup did (#49).
  private func hoursTitle(_ index: Int) -> String {
    guard model.isSleep, model.block.schedule.rules.count == 2 else { return Copy.Blocks.hours }
    return index == 0 ? Copy.Setup.weeknights : Copy.Setup.weekendNights
  }
}
