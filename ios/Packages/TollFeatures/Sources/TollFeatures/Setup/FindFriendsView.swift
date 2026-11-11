import SwiftUI
import TollCore
import TollData
import TollUI

/// Set up 4 · Find your friends (flows §6), and the same groups wherever People, Settings or Insights
/// embed them (N-17). An embedding screen names the parts it wants and usually supplies the heading.
struct FindFriendsView: View {
  enum Part: CaseIterable { case inviteCode, contacts, school }

  let app: AppModel
  let isSetup: Bool
  var parts: [Part] = Part.allCases
  var showsHeaders = true
  @State private var model: FindFriendsModel?

  var body: some View {
    ZStack {
      if let model {
        if isSetup {
          SetupScaffold(app: app, step: 3, title: Copy.Friends.title, background: TollColor.bgGrouped) {
            groups(model)
          } footer: {
            VStack(spacing: 0) {
              PrimaryButton(Copy.Friends.done) { Task { await model.finish(skipped: false) } }
              QuietButton(Copy.Friends.skip, tone: .secondary) { Task { await model.finish(skipped: true) } }
            }
          }
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

  /// Setup sits on the grouped background, where white cards read. Embedded, the host may be a list
  /// row or a page of either colour, so the fill has to read on all of them.
  private var fieldFill: Color { isSetup ? TollColor.surface : TollColor.fill }

  private func groups(_ model: FindFriendsModel) -> some View {
    VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
      if parts.contains(.inviteCode) {
        group(Copy.Friends.inviteCode) { inviteCode(model) }
      }
      if parts.contains(.contacts) {
        group(Copy.Friends.contacts) { contacts(model) }
      }
      if parts.contains(.school) {
        group(Copy.Friends.school) { school(model) }
      }
    }
  }

  private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: TollSpacing.labelGap) {
      if showsHeaders { SectionHeader(title).padding(.horizontal, 4) }
      content()
    }
  }

  @ViewBuilder
  private func inviteCode(_ model: FindFriendsModel) -> some View {
    @Bindable var bound = model
    FilledField(Copy.Friends.inviteCode, text: $bound.code, fill: fieldFill) {
      QuietButton(Copy.Friends.paste) { Task { await model.paste() } }
    }
    .textInputAutocapitalization(.characters)
    .autocorrectionDisabled()
    .onSubmit { Task { await model.submitCode() } }
    if let result = model.codeResult { note(result) }
    if let error = model.codeError { note(error) }
  }

  @ViewBuilder
  private func contacts(_ model: FindFriendsModel) -> some View {
    switch model.contacts {
    case .notAsked:
      Button {
        Task { await model.findContacts() }
      } label: {
        card {
          HStack(spacing: TollSpacing.labelGap) {
            Text(Copy.Friends.findContacts).tollText(.body)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(TollFont.captionMedium)
              .foregroundStyle(TollColor.label3)
              .accessibilityHidden(true)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    case .denied:
      card { Text(Copy.Friends.contactsDenied).tollText(.subhead) }
    case .loading:
      card { ProgressView() }
    case .matched(let people):
      if people.isEmpty {
        card { Text(Copy.Home.noFriends).tollText(.subhead) }
      } else {
        matches(people, model: model)
      }
    }
  }

  private func matches(_ people: [PersonRef], model: FindFriendsModel) -> some View {
    VStack(spacing: 0) {
      ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
        if index > 0 { Hairline() }
        HStack(spacing: TollSpacing.rowLeadingGap) {
          Avatar(name: person.displayName, handle: person.handle, photoURL: FriendFormatting.photo(person))
          Text(person.displayName).tollText(.headline).lineLimit(1)
          Spacer(minLength: TollSpacing.labelGap)
          if model.requested.contains(person.id) {
            Text(Copy.People.requested).tollText(.caption)
          } else {
            QuietButton(Copy.People.add) { Task { await model.add(person, source: "contacts") } }
          }
        }
        .frame(minHeight: TollSpacing.rowMinHeight)
      }
    }
    .padding(.horizontal, TollSpacing.cardPadding)
    .background(fieldFill, in: RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous))
  }

  @ViewBuilder
  private func school(_ model: FindFriendsModel) -> some View {
    @Bindable var bound = model
    switch model.school {
    case .joined(let name):
      card { Text(name).tollText(.headline) }
    case .entering:
      FilledField(Copy.Friends.schoolEmail, text: $bound.schoolEmail, fill: fieldFill) {
        QuietButton(Copy.Email.send) { Task { await model.sendSchoolCode() } }
          .disabled(model.isWorking || model.schoolEmail.isEmpty)
      }
      .keyboardType(.emailAddress)
      .textContentType(.emailAddress)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
    case .codeSent:
      CodeBoxes(code: $bound.schoolCode, accessibilityLabel: Copy.Code.title, fill: fieldFill) { _ in
        Task { await model.verifySchool() }
      }
    }
    if let error = model.schoolError { note(error) }
  }

  /// One row in the field's shape, so the three groups line up whatever state each is in.
  private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
      .padding(.horizontal, TollSpacing.cardPadding)
      .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
      .background(fieldFill, in: RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous))
  }

  private func note(_ text: String) -> some View {
    Text(text).tollText(.subhead).padding(.horizontal, 4)
  }
}
