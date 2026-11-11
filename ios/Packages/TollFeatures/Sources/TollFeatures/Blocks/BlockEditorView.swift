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
      ScrollView { editor(model).tollGutter() }
        .background(TollColor.bgGrouped)
        .navigationTitle(model.title)
        .navigationBarBackButtonHidden(model.hasChanges)
        .toolbar {
          if model.hasChanges {
            ToolbarItem(placement: .topBarLeading) {
              Button { confirmDiscard = true } label: { Image(systemName: "chevron.backward") }
            }
          }
        }
        .safeAreaInset(edge: .bottom) {
          PrimaryButton(Copy.BlockEditor.done) { Task { if await model.done() { dismiss() } } }
            .disabled(!model.canFinish)
            .tollGutter()
            .padding(.bottom, 8)
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
    return VStack(alignment: .leading, spacing: 16) {
      if let summary = model.compactSummary {
        BlockRow(schedule: summary, style: .compact) { EmptyView() } names: { EmptyView() }
      } else {
        ForEach(model.finished) { block in
          BlockRow(schedule: Copy.Schedules.label(block.schedule), style: .compact) {
            AppIconCluster(block.appRefs)
          } names: {
            AppNames(block.appRefs)
          }
        }
      }
      appsCard(model)
      if model.overLimit { Text(Copy.BlockEditor.limit).tollText(.subhead) }
      SectionHeader(Copy.Schedules.when)
      WhenChips(selection: kind, customSchedule: model.schedule.kind == .custom ? model.schedule : nil) {
        model.customSheetPresented = true
      }
      if !model.isSetup {
        VStack(alignment: .leading, spacing: 4) {
          FilledField(Copy.BlockEditor.blockName, text: $bound.name, fill: TollColor.surface)
          Text(Copy.BlockEditor.blockNameNote).tollText(.caption)
        }
      }
    }
  }

  private func appsCard(_ model: BlockEditorModel) -> some View {
    let visible = model.isSetup ? Array(model.refs.prefix(3)) : model.refs
    return VStack(alignment: .leading, spacing: 0) {
      if model.refs.isEmpty {
        QuietButton(Copy.BlockEditor.chooseApps) { model.pickerPresented = true }
          .frame(maxWidth: .infinity, minHeight: 52)
      }
      ForEach(Array(visible.enumerated()), id: \.element) { index, ref in
        appRow(model, ref: ref)
          .staggeredAppearance(index: index, step: Motion.Stagger.pickerRows, rise: 6, isActive: true)
      }
      if model.isSetup && model.refs.count > 3 {
        Button(Copy.BlockEditor.more(model.refs.count - 3)) { showAll = true }
          .tollText(.bodyMedium)
          .frame(minHeight: 44)
      }
      if !model.refs.isEmpty {
        QuietButton(Copy.BlockEditor.chooseMore) { model.pickerPresented = true }
          .frame(minHeight: 44)
      }
      if !model.isSetup && !model.refs.isEmpty {
        Text(Copy.BlockEditor.tagNote).tollText(.micro).padding(.bottom, 8)
      }
    }
    .padding(.horizontal, TollSpacing.cardPadding)
    .background(TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card))
  }

  private func appRow(_ model: BlockEditorModel, ref: AppRef) -> some View {
    HStack(spacing: 12) {
      AppLabel(ref, style: .both).tollText(.body)
      Spacer()
      if !model.isSetup {
        Menu {
          ForEach(Tag.allCases, id: \.self) { tag in
            Button(Copy.Tags.chip(tag)) { Task { await model.setTag(tag, for: ref) } }
          }
        } label: {
          Text(model.tags[ref].map(Copy.Tags.chip) ?? Copy.Tags.display(nil)).tollText(.caption)
        }
      }
    }
    .frame(minHeight: 44)
    .swipeActions { Button(Copy.Blocks.remove, role: .destructive) { model.remove(ref) } }
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
