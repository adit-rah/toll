import SwiftUI
import TollCore
import TollData
import TollUI

/// Set up 4 · Find your friends (flows §6), and the same groups inside People.
struct FindFriendsView: View {
  let app: AppModel
  let isSetup: Bool
  @State private var model: FindFriendsModel?

  var body: some View {
    ZStack {
      if let model {
        if isSetup {
          SetupScaffold(app: app, step: 3, title: Copy.Friends.title) {
            ScrollView { groups(model) }
          } footer: {
            VStack(spacing: 0) {
              PrimaryButton(Copy.Friends.done) { Task { await model.finish(skipped: false) } }
              QuietButton(Copy.Friends.skip, tone: .secondary) { Task { await model.finish(skipped: true) } }
            }
          }
          .background(TollColor.bgGrouped)
        } else {
          groups(model)
        }
      }
    }
    .task {
      if model == nil {
        model = FindFriendsModel(app: app)
        await model?.start()
      }
    }
  }

  @ViewBuilder
  private func groups(_ model: FindFriendsModel) -> some View {
    @Bindable var bound = model
    VStack(alignment: .leading, spacing: TollSpacing.sectionGap) {
      VStack(alignment: .leading, spacing: 8) {
        SectionHeader(Copy.Friends.inviteCode)
        FilledField(Copy.Friends.inviteCode, text: $bound.code, fill: TollColor.surface) {
          QuietButton(Copy.Friends.paste) { Task { await model.paste() } }
        }
        .textInputAutocapitalization(.characters)
        .onSubmit { Task { await model.submitCode() } }
        if let result = model.codeResult { Text(result).tollText(.subhead) }
        if let error = model.codeError { Text(error).tollText(.subhead) }
      }
      VStack(alignment: .leading, spacing: 8) {
        SectionHeader(Copy.Friends.contacts)
        contacts(model)
      }
      VStack(alignment: .leading, spacing: 8) {
        SectionHeader(Copy.Friends.school)
        school(model)
      }
    }
  }

  @ViewBuilder
  private func contacts(_ model: FindFriendsModel) -> some View {
    switch model.contacts {
    case .notAsked:
      QuietButton(Copy.Friends.findContacts) { Task { await model.findContacts() } }
    case .denied:
      Text(Copy.Friends.contactsDenied).tollText(.subhead)
    case .loading:
      ProgressView()
    case .matched(let people):
      ForEach(people) { person in
        HStack {
          Avatar(name: person.displayName, handle: person.handle, photoURL: FriendFormatting.photo(person))
          Text(person.displayName).tollText(.headline)
          Spacer()
          if model.requested.contains(person.id) {
            Text(Copy.People.requested).tollText(.caption)
          } else {
            QuietButton(Copy.People.add) { Task { await model.add(person, source: "contacts") } }
          }
        }
        .frame(minHeight: TollSpacing.rowMinHeight)
      }
    }
  }

  @ViewBuilder
  private func school(_ model: FindFriendsModel) -> some View {
    @Bindable var bound = model
    switch model.school {
    case .joined(let name):
      Text(name).tollText(.headline)
    case .entering:
      FilledField(Copy.Friends.schoolEmail, text: $bound.schoolEmail, fill: TollColor.surface) {
        QuietButton(Copy.Email.send) { Task { await model.sendSchoolCode() } }
      }
      .keyboardType(.emailAddress)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
    case .codeSent:
      CodeBoxes(code: $bound.schoolCode, accessibilityLabel: Copy.Code.title, fill: TollColor.surface) { _ in
        Task { await model.verifySchool() }
      }
    }
    if let error = model.schoolError { Text(error).tollText(.subhead) }
  }
}
