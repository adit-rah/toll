@preconcurrency import FamilyControls
import SwiftUI
import TollCore
import TollUI

/// Set up 3 · Block these (step of the setup bar).
struct SetupBlocksView: View {
  let app: AppModel
  let returning: Bool

  var body: some View {
    BlockEditorView(app: app, mode: .setup(returning: returning))
  }
}

/// The fast creator and New block (flows §5, §14; design §4.3, §4.6).
struct BlockEditorView: View {
  let app: AppModel
  let mode: BlockEditorModel.Mode
  @State private var model: BlockEditorModel?
  @State private var showAll = false
  @State private var confirmDiscard = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      if let model {
        @Bindable var bound = model
        content(model)
          .familyActivityPicker(isPresented: $bound.pickerPresented, selection: $bound.selection)
          .sheet(isPresented: $bound.customSheetPresented) { CustomHoursSheet(schedule: $bound.schedule) }
          .sheet(isPresented: $showAll) { allApps(model) }
      }
    }
    .task {
      if model == nil {
        model = BlockEditorModel(app: app, mode: mode)
        await model?.load()
      }
    }
  }

  @ViewBuilder
  private func content(_ model: BlockEditorModel) -> some View {
    if model.isSetup {
      SetupScaffold(app: app, step: app.setupSteps == 4 ? 2 : 1, title: model.title) {
        editor(model)
      } footer: {
        VStack(spacing: 0) {
          PrimaryButton(Copy.BlockEditor.done) { Task { if await model.done() { await app.reroute() } } }
            .disabled(!model.canFinish)
          QuietButton(Copy.BlockEditor.addAnother) { Task { await model.addAnother() } }
            .disabled(!model.canFinish)
        }
      }
    } else {
      ScrollView { editor(model).tollGutter().padding(.vertical, TollSpacing.cardPadding) }
        .background(TollColor.bgGrouped)
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.hasChanges)
        .toolbar {
          if model.hasChanges {
            ToolbarItem(placement: .topBarLeading) {
              Button { confirmDiscard = true } label: { Image(systemName: "chevron.backward") }
            }
          }
        }
        .tollBottomBar {
          PrimaryButton(Copy.BlockEditor.done) { Task { if await model.done() { dismiss() } } }
            .disabled(!model.canFinish)
        }
        .confirmationDialog(Copy.BlockEditor.discardTitle, isPresented: $confirmDiscard) {
          Button(Copy.BlockEditor.discard, role: .destructive) { dismiss() }
          Button(Copy.BlockEditor.keepEditing, role: .cancel) {}
        }
    }
  }

  private func editor(_ model: BlockEditorModel) -> some View {
    @Bindable var bound = model
    let kind = Binding(get: { model.schedule.kind }, set: { model.choose($0) })
    // Cards need a fill the page does not have: `surface` is the page colour in setup, and
    // `surfaceRaised` is the page colour on the grouped background.
    let fill = model.isSetup ? TollColor.surfaceRaised : TollColor.surface
    return VStack(alignment: .leading, spacing: 0) {
      finishedBlocks(model, fill: fill)
      if model.needsRepicking {
        Text(Copy.BlockEditor.needsRepicking)
          .tollText(.subhead)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, TollSpacing.labelGap)
      }
      BlockAppsCard(model: model, fill: fill, showAll: $showAll)
      if model.overLimit {
        Text(Copy.BlockEditor.limit).tollText(.subhead).padding(.top, TollSpacing.labelGap)
      }
      if !model.isSetup && !model.refs.isEmpty {
        Text(Copy.BlockEditor.tagNote).tollText(.detail).padding(.top, TollSpacing.labelGap)
      }
      SectionHeader(Copy.Schedules.when)
        .padding(.top, TollSpacing.groupGap)
        .padding(.bottom, TollSpacing.tileGap)
      WhenChips(
        selection: kind, customSchedule: model.schedule.kind == .custom ? model.schedule : nil,
        tileFill: fill
      ) {
        model.customSheetPresented = true
      }
      if !model.isSetup {
        FilledField(Copy.BlockEditor.blockName, text: $bound.name, fill: TollColor.surface)
          .padding(.top, TollSpacing.groupGap)
        Text(Copy.BlockEditor.blockNameNote).tollText(.caption).padding(.top, TollSpacing.labelGap)
      }
    }
  }

  /// Blocks already made with "Add another block", above the creator. They are a record, not a way
  /// back in, so they carry no chevron.
  @ViewBuilder
  private func finishedBlocks(_ model: BlockEditorModel, fill: Color) -> some View {
    if !model.finished.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        if let summary = model.compactSummary {
          Text(summary)
            .tollText(.body)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: TollSpacing.compactBlockRowHeight, alignment: .leading)
        } else {
          ForEach(model.finished) { block in
            BlockRow(schedule: Copy.Schedules.label(block.schedule), style: .compact, showsChevron: false) {
              AppIconCluster(block.appRefs)
            } names: {
              AppNames(block.appRefs)
            }
          }
        }
      }
      .padding(.horizontal, TollSpacing.cardPadding)
      .background(fill, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
      .padding(.bottom, 12)
    }
  }

  private func allApps(_ model: BlockEditorModel) -> some View {
    NavigationStack {
      List(model.refs, id: \.self) { ref in AppLabel(ref, style: .both) }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium, .large])
  }
}

/// App names on one line, truncated (design §3.10).
struct AppNames: View {
  let refs: [AppRef]
  init(_ refs: [AppRef]) { self.refs = refs }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(refs.prefix(4).enumerated()), id: \.element) { index, ref in
        if index > 0 { Text(", ") }
        AppLabel(ref)
      }
    }
    .lineLimit(1)
  }
}
