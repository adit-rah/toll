import SwiftUI
import TollCore
import TollData
import TollUI

/// Friend detail sheet (design §4.5): their week, today and yesterday, their tagged blocks; nothing older
/// than yesterday.
struct FriendDetailView: View {
  let app: AppModel
  let friend: FriendSummary
  @Environment(\.dismiss) private var dismiss
  @State private var personAction: (PersonAction, PersonRef)?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text("\(friend.today.passes)").font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
          StatusGlyph(FriendFormatting.mark(friend), size: .hero, accessibilityLabel: FriendFormatting.speech(friend).status)
          Text(Copy.Home.passesToday(friend.today.passes)).tollText(.bodyMedium)
        }
        metrics
        passList(Copy.FriendDetail.today, friend.todayPasses)
        passList(Copy.FriendDetail.yesterday, friend.yesterdayPasses)
        if !friend.blocks.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            SectionHeader(Copy.FriendDetail.blocks)
            FlowLayout(spacing: 8, centred: false) {
              ForEach(Array(friend.blocks.enumerated()), id: \.offset) { _, block in
                Text(Copy.Tags.list(block.tags.map(Copy.Tags.display)) + Copy.middleDot + Copy.Schedules.inline(block.schedule))
                  .tollText(.subhead)
                  .padding(.horizontal, 10)
                  .frame(minHeight: 34)
                  .background(TollColor.surfaceRaised, in: RoundedRectangle(cornerRadius: TollRadius.chip))
              }
            }
          }
        }
        HStack(spacing: 24) {
          QuietButton(Copy.FriendDetail.remove, tone: .secondary) { personAction = (.remove, friend.user) }
          QuietButton(Copy.FriendDetail.block, tone: .secondary) { personAction = (.block, friend.user) }
          QuietButton(Copy.FriendDetail.report, tone: .secondary) { personAction = (.report, friend.user) }
        }
        .frame(maxWidth: .infinity)
      }
      .tollGutter()
      .padding(.top, 24)
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .personActions(app: app, pending: $personAction) { dismiss() }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Avatar(name: friend.user.displayName, handle: friend.user.handle, photoURL: FriendFormatting.photo(friend.user), size: .detail)
      VStack(alignment: .leading, spacing: 2) {
        Text(friend.user.displayName).tollText(.title)
        Text(
          Copy.FriendDetail.since(
            handle: friend.user.handle,
            date: Date(millis: friend.friendsSince).formatted(.dateTime.month(.abbreviated).day()))
        )
        .tollText(.caption)
      }
    }
  }

  private var metrics: some View {
    let w = friend.week
    return HStack(alignment: .top) {
      MetricPair(label: Copy.FriendDetail.thisWeek, value: "\(w.passes)", previous: "\(w.lastWeek)")
      MetricPair(label: Copy.FriendDetail.held, value: w.heldPercent.map(Copy.percent) ?? "—")
      MetricPair(label: Copy.FriendDetail.waited, value: "\(w.waited)")
      MetricPair(label: Copy.FriendDetail.cleanDays, value: "\(w.cleanDays)")
    }
  }

  private func passList(_ title: String, _ passes: [PassLine]) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title)
      if passes.isEmpty {
        Text(Copy.FriendDetail.noPasses).tollText(.subhead).frame(minHeight: 36)
      }
      ForEach(Array(passes.enumerated()), id: \.offset) { index, pass in
        VStack(spacing: 0) {
          if index > 0 { Hairline() }
          Text(FriendFormatting.passLine(pass)).tollText(.subhead)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        }
      }
    }
  }
}

/// The invite sheet (design §4.9): the code, a share link, one caption.
struct InviteSheet: View {
  let app: AppModel
  @State private var invite: Invite?

  var body: some View {
    VStack(spacing: 16) {
      Text(Copy.Invite.yourCode).tollText(.caption)
      Text(invite?.code ?? "------")
        .font(.system(size: 44, weight: .semibold, design: .rounded))
        .tracking(6)
        .monospacedDigit()
        .textSelection(.enabled)
      if let invite, let url = URL(string: invite.url) {
        ShareLink(item: url, message: Text(Copy.Invite.message(invite.url))) {
          Text(Copy.Invite.share)
        }
        .buttonStyle(.tollPrimary)
      }
      Text(Copy.Invite.caption).tollText(.caption).multilineTextAlignment(.center)
    }
    .tollGutter()
    .padding(.top, 32)
    .presentationDetents([.medium])
    .task { invite = try? await app.deps.network.invite() }
  }
}
