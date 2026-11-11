import SwiftUI
import TollCore
import TollData
import TollUI

/// School members and mutuals at the school (flows §12). Nobody is ranked (N-8).
struct SchoolMembersView: View {
  let app: AppModel
  let model: PeopleModel
  let school: String
  @State private var personAction: (PersonAction, PersonRef)?

  var body: some View {
    List {
      ForEach(model.schoolMembers ?? []) { member in
        let level = member.level.flatMap(StatusLevel.init(rawValue:))
        MutualRow(
          name: member.user.displayName, handle: member.user.handle,
          photoURL: FriendFormatting.photo(member.user),
          // A stranger's level is not theirs to show (N-16), so there is no badge to draw.
          status: level.map { StatusMark(level: $0) }, detail: "@\(member.user.handle)",
          trailing: trailing(member), statusSpeech: FriendFormatting.statusSpeech(level),
          separatorAbove: false, backing: TollColor.surface
        )
        .listRowInsets(PeopleView.rowInsets)
        .contextMenu {
          PersonMenu(isFriend: member.relation == Self.friend) { personAction = ($0, member.user) }
        }
      }
    }
    .listStyle(.insetGrouped)
    .overlay {
      if let members = model.schoolMembers {
        if members.isEmpty { EmptyState(Copy.People.schoolBelowMinimum).tollGutter() }
      } else if let error = model.schoolError {
        EmptyState(error).tollGutter()
      }
    }
    .navigationTitle(school)
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.loadSchoolMembers() }
    .refreshable { await model.loadSchoolMembers() }
    .personActions(app: app, pending: $personAction) { Task { await model.loadSchoolMembers() } }
  }

  // The relations `/school/members` sends (api `school/members.ts`).
  private static let friend = "friend"
  private static let requested = "requested"

  private func trailing(_ member: SchoolMember) -> MutualRow.Trailing {
    switch member.relation {
    case Self.friend: return .nothing
    case Self.requested: return .note(Copy.People.requested)
    default: return model.addAction(for: member.user.id, source: "school")
    }
  }
}
