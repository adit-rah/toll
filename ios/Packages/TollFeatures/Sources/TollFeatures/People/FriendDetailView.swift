import SwiftUI
import TollCore
import TollData
import TollUI

/// Friend detail sheet (design §4.5): their week, today and yesterday, their tagged blocks; nothing older
/// than yesterday.
struct FriendDetailView: View {
  let app: AppModel
  let friend: FriendSummary
  let onChanged: () -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var personAction: (PersonAction, PersonRef)? = nil

  /// `onChanged` runs after the friend is removed or blocked, so the list behind the sheet can drop
  /// their row.
  init(app: AppModel, friend: FriendSummary, onChanged: @escaping () -> Void = {}) {
    self.app = app
    self.friend = friend
    self.onChanged = onChanged
  }

  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          header
          today.padding(.top, 20)
          metrics.padding(.top, TollSpacing.cardPadding)
          passList(Copy.FriendDetail.today, friend.todayPasses).padding(.top, TollSpacing.groupGap)
          passList(Copy.FriendDetail.yesterday, friend.yesterdayPasses).padding(.top, 20)
          blocks
          // The quiet actions rest on the bottom edge of a short sheet and follow a long one.
          Spacer(minLength: TollSpacing.sectionGap)
          actions
        }
        .tollGutter()
        .padding(.top, TollSpacing.sectionGap)
        .padding(.bottom, TollSpacing.footerBottom)
        .frame(minHeight: proxy.size.height, alignment: .top)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .personActions(app: app, pending: $personAction) {
      onChanged()
      dismiss()
    }
  }

  private var header: some View {
    HStack(spacing: TollSpacing.rowLeadingGap) {
      Avatar(
        name: friend.user.displayName, handle: friend.user.handle,
        photoURL: FriendFormatting.photo(friend.user), size: .detail)
      VStack(alignment: .leading, spacing: 2) {
        Text(friend.user.displayName).tollText(.title).lineLimit(2)
        Text(FriendFormatting.friendsSince(friend)).tollText(.caption)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  private var today: some View {
    HStack(alignment: .firstTextBaseline, spacing: TollSpacing.labelGap) {
      // The label wraps before the count shrinks.
      HeroNumber("\(friend.today.passes)", size: 40).fixedSize()
      Text(Copy.Home.passesToday(friend.today.passes)).tollText(.body)
      StatusGlyph(FriendFormatting.mark(friend))
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AccessibilitySentence.join([
        "\(friend.today.passes) \(Copy.Home.passesToday(friend.today.passes))",
        FriendFormatting.speech(friend).status,
      ]))
  }

  // Four equal columns so the values line up under their labels; two by two once the text is too
  // large for a quarter of the width.
  private var metrics: some View {
    let w = friend.week
    let pairs = [
      MetricPair(label: Copy.FriendDetail.thisWeek, value: "\(w.passes)", previous: "\(w.lastWeek)"),
      MetricPair(label: Copy.FriendDetail.held, value: w.heldPercent.map(Copy.percent) ?? "—"),
      MetricPair(label: Copy.FriendDetail.waited, value: Copy.minutes(w.waitMinutes)),
      MetricPair(label: Copy.FriendDetail.cleanDays, value: "\(w.cleanDays)"),
    ]
    let perRow = typeSize.isAccessibilitySize ? 2 : 4
    return VStack(alignment: .leading, spacing: TollSpacing.cardPadding) {
      ForEach(Array(stride(from: 0, to: pairs.count, by: perRow)), id: \.self) { start in
        HStack(alignment: .top, spacing: TollSpacing.labelGap) {
          ForEach(start..<min(start + perRow, pairs.count), id: \.self) { index in
            pairs[index].frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
  }

  private func passList(_ title: String, _ passes: [PassLine]) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title).padding(.bottom, 6)
      Hairline()
      if passes.isEmpty {
        Text(Copy.FriendDetail.noPasses).tollText(.subhead).frame(minHeight: 36)
      }
      // The lines never reorder while the sheet is up, so position is identity enough.
      ForEach(passes.indices, id: \.self) { index in
        if index > 0 { Hairline() }
        Text(FriendFormatting.passLine(passes[index]))
          .font(TollFont.subhead)
          .foregroundStyle(TollColor.label)
          .padding(.vertical, TollSpacing.labelGap)
          .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
      }
    }
  }

  @ViewBuilder
  private var blocks: some View {
    let chips = FriendFormatting.blockChips(friend)
    if !chips.isEmpty {
      VStack(alignment: .leading, spacing: TollSpacing.labelGap) {
        SectionHeader(Copy.FriendDetail.blocks)
        FlowLayout(spacing: 8, lineSpacing: 8, centred: false) {
          ForEach(chips, id: \.self) { chip in
            Text(chip)
              .font(TollFont.captionMedium)
              .foregroundStyle(TollColor.label)
              .lineLimit(1)
              .padding(.horizontal, 12)
              .frame(minHeight: 30)
              .background(
                TollColor.fill, in: RoundedRectangle(cornerRadius: TollRadius.chip, style: .continuous))
          }
        }
      }
      .padding(.top, TollSpacing.groupGap)
    }
  }

  private var actions: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: TollSpacing.groupGap) { actionButtons }
      VStack(spacing: 0) { actionButtons }
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var actionButtons: some View {
    QuietButton(Copy.FriendDetail.remove, tone: .secondary) { personAction = (.remove, friend.user) }
    QuietButton(Copy.FriendDetail.block, tone: .secondary) { personAction = (.block, friend.user) }
    QuietButton(Copy.FriendDetail.report, tone: .secondary) { personAction = (.report, friend.user) }
  }
}
