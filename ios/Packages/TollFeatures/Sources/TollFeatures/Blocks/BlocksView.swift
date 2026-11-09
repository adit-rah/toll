import SwiftUI
import TollCore
import TollData
import TollUI

/// Blocks (design §4.6): one row per block; removing one is shown to friends.
struct BlocksView: View {
  let app: AppModel
  @State private var blocks: [StoredBlock] = []
  @State private var removing: StoredBlock?

  var body: some View {
    List {
      Section {
        ForEach(blocks) { block in
          NavigationLink(value: BlockRoute.edit(block.id)) {
            BlockRow(schedule: Copy.Schedules.label(block.schedule)) {
              AppIconCluster(block.appRefs)
            } names: {
              AppNames(block.appRefs)
            }
          }
          .swipeActions {
            Button(Copy.Blocks.remove, role: .destructive) { removing = block }
          }
        }
      } footer: {
        Text(Copy.Blocks.header).tollText(.caption)
      }
    }
    .navigationTitle(Copy.Blocks.title)
    .navigationDestination(for: BlockRoute.self) { route in
      switch route {
      case .new: BlockEditorView(app: app, mode: .new)
      case .edit(let id): BlockEditorView(app: app, mode: .edit(id))
      }
    }
    .safeAreaInset(edge: .bottom) {
      NavigationLink(value: BlockRoute.new) {
        Text(Copy.Blocks.add)
      }
      .buttonStyle(.tollPrimary)
      .disabled(!BlockLimits.canAddBlock(existing: blocks.count, config: app.config.blocks))
      .tollGutter()
      .padding(.bottom, 8)
    }
    .confirmationDialog(
      removing.map { Copy.Blocks.removeConfirm(name(of: $0)) } ?? "", isPresented: .init(
        get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible
    ) {
      Button(Copy.Blocks.remove, role: .destructive) {
        guard let block = removing else { return }
        Haptics.warning()
        Task { try? await app.deps.blocks.remove(block.id) }
      }
      Button(Copy.Blocks.keep, role: .cancel) {}
    }
    .task {
      do {
        for try await value in app.deps.store.observeBlocks() {
          withAnimation(Motion.movement) { blocks = value }
        }
      } catch {}
    }
  }

  /// The confirmation names the block by its user-only name, else its schedule: Toll cannot read the
  /// system's app names as text (spec §6).
  private func name(of block: StoredBlock) -> String {
    block.name ?? Copy.Schedules.label(block.schedule)
  }
}

enum BlockRoute: Hashable {
  case new
  case edit(BlockRef)
}

/// Custom hours (design §4.6): From / Until wheels and a day row.
struct CustomHoursSheet: View {
  @Binding var schedule: Schedule
  @Environment(\.dismiss) private var dismiss
  @State private var from = Date()
  @State private var until = Date()
  @State private var days: Set<Weekday> = Weekday.all

  private let calendar = Calendar.current

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(Copy.Schedules.custom).tollText(.title)
      HStack {
        picker(Copy.Schedules.from, $from)
        picker(Copy.Schedules.until, $until)
      }
      HStack(spacing: 6) {
        ForEach(Weekday.allCases, id: \.self) { day in
          let on = days.contains(day)
          Button {
            Haptics.selection()
            if on { days.remove(day) } else { days.insert(day) }
          } label: {
            Text(calendar.veryShortStandaloneWeekdaySymbols[day.rawValue % 7])
              .frame(width: 40, height: 40)
              .background(on ? TollColor.accent : TollColor.surfaceRaised, in: RoundedRectangle(cornerRadius: TollRadius.chip))
              .foregroundStyle(on ? TollColor.onAccent : TollColor.label)
          }
          .accessibilityLabel(calendar.standaloneWeekdaySymbols[day.rawValue % 7])
          .accessibilityAddTraits(on ? .isSelected : [])
        }
      }
      PrimaryButton(Copy.BlockEditor.done) {
        schedule = .custom(start: clock(from), end: clock(until), days: days.isEmpty ? Weekday.all : days)
        dismiss()
      }
    }
    .tollGutter()
    .padding(.top, 24)
    .presentationDetents([.medium])
    .onAppear {
      from = date(schedule.kind == .custom ? schedule.start : ClockTime(hour: 22))
      until = date(schedule.kind == .custom ? schedule.end : ClockTime(hour: 7))
      if schedule.kind == .custom { days = schedule.days }
    }
  }

  private func picker(_ title: String, _ value: Binding<Date>) -> some View {
    VStack(spacing: 0) {
      Text(title).tollText(.caption)
      DatePicker(title, selection: value, displayedComponents: .hourAndMinute)
        .datePickerStyle(.wheel)
        .labelsHidden()
    }
  }

  private func clock(_ date: Date) -> ClockTime {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return ClockTime(hour: c.hour ?? 0, minute: c.minute ?? 0)
  }

  private func date(_ time: ClockTime) -> Date {
    calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
  }
}
