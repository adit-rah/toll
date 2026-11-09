import AuthenticationServices
import SwiftUI
import TollCore
import TollData
import TollUI

/// Settings (design §4.8, flows §16). Delete account is a two-step confirm with re-authentication.
struct SettingsView: View {
  let app: AppModel
  @State private var model: SettingsModel?
  @State private var legal: URL?
  @State private var nonce = AppleNonce()

  var body: some View {
    Group {
      if let model { list(model) }
    }
    .navigationTitle(Copy.Settings.title)
    .task {
      if model == nil {
        model = SettingsModel(app: app)
        await model?.loadBlockedPeople()
      }
    }
    .sheet(item: $legal) { SafariView(url: $0).ignoresSafeArea() }
  }

  private func list(_ model: SettingsModel) -> some View {
    @Bindable var model = model
    return List {
      Section(Copy.Settings.account) {
        if let me = app.me, app.isSignedIn {
          NavigationLink { AccountEditView(app: app) } label: {
            HStack(spacing: 12) {
              Avatar(name: me.displayName ?? "", handle: me.handle ?? "", photoURL: me.photoUrl.flatMap(URL.init(string:)), size: .settings)
              VStack(alignment: .leading) {
                Text(me.displayName ?? "").tollText(.headline)
                Text("@\(me.handle ?? "")").tollText(.caption)
              }
            }
          }
          Button(Copy.Settings.signOut) { model.confirmSignOut = true }
        } else {
          Button(Copy.Settings.signIn) { app.showsSignInSheet = true }
        }
      }
      if app.isSignedIn {
        Section(Copy.Settings.school) {
          if let school = app.me?.school {
            HStack {
              Text(school.name)
              Spacer()
              Button(Copy.Settings.leave, role: .destructive) { model.confirmLeaveSchool = true }
            }
          } else {
            FindFriendsView(app: app, isSetup: false)
          }
        }
        Section(Copy.Settings.notifications) {
          Toggle(Copy.Settings.dailySummary, isOn: $model.notifyEnabled)
          if model.notifyEnabled {
            Picker(Copy.Settings.time, selection: $model.notifyHour) {
              ForEach(0..<24, id: \.self) { Text(Copy.Schedules.time(ClockTime(hour: $0))).tag($0) }
            }
          }
        }
        .onChange(of: model.notifyEnabled) { Task { await model.save() } }
        .onChange(of: model.notifyHour) { Task { await model.save() } }
        Section(Copy.Settings.discoverability) {
          Toggle(Copy.Settings.letContactsFind, isOn: $model.discoverable)
            .onChange(of: model.discoverable) { Task { await model.save() } }
        }
      }
      Section {
        NavigationLink(Copy.Settings.blockedApps) { BlocksView(app: app) }
        if !model.blockedPeople.isEmpty {
          NavigationLink(Copy.Settings.blockedPeople) { BlockedPeopleView(model: model) }
        }
      }
      Section(Copy.Settings.data) {
        if let url = model.exportURL {
          ShareLink(Copy.Settings.export, item: url)
        } else {
          Button(Copy.Settings.export) { Task { await model.prepareExport() } }
        }
        if app.isSignedIn {
          Button(Copy.Settings.delete, role: .destructive) { model.confirmDelete = true }
        }
      }
      Section(Copy.Settings.about) {
        Button(Copy.Settings.privacy) { legal = model.legalBase.appending(path: "privacy") }
        Button(Copy.Settings.terms) { legal = model.legalBase.appending(path: "terms") }
        if let mail = URL(string: "mailto:\(model.supportEmail)") {
          Link(model.supportEmail, destination: mail)
        }
        LabeledContent(Copy.Settings.version, value: model.version)
      }
      if let donation = model.donationURL {
        Section(Copy.Settings.supportToll) {
          Link(Copy.Settings.donate, destination: donation)
        }
      }
      if let error = model.error { Text(error).tollText(.subhead) }
    }
    .confirmationDialog(Copy.Settings.signOutConfirm, isPresented: $model.confirmSignOut, titleVisibility: .visible) {
      Button(Copy.Settings.signOut, role: .destructive) { Task { await model.signOut() } }
    }
    .confirmationDialog(
      Copy.Settings.leaveConfirm(app.me?.school?.name ?? ""), isPresented: $model.confirmLeaveSchool,
      titleVisibility: .visible
    ) {
      Button(Copy.Settings.leave, role: .destructive) { Task { await model.leaveSchool() } }
    }
    .sheet(isPresented: $model.confirmDelete) { deleteSheet(model) }
  }

  private func deleteSheet(_ model: SettingsModel) -> some View {
    @Bindable var model = model
    return VStack(alignment: .leading, spacing: 20) {
      Text(Copy.Settings.deleteConfirm).tollText(.title)
      if model.isEmailAccount {
        if model.deleteCodeSent {
          Text(Copy.Settings.checkEmailToDelete).tollText(.subhead)
          CodeBoxes(code: $model.deleteCode, accessibilityLabel: Copy.Code.title) { _ in
            Haptics.warning()
            Task { await model.deleteWithEmailCode() }
          }
        } else {
          Button(Copy.Settings.continue) { Task { await model.sendDeleteCode() } }.buttonStyle(.tollDestructiveQuiet)
        }
      } else {
        SignInWithAppleButton(.continue) { request in
          nonce = AppleNonce()
          request.nonce = nonce.hashed
        } onCompletion: { result in
          guard case .success(let auth) = result, let credential = AppleCredential(auth) else { return }
          Haptics.warning()
          Task { await model.deleteWithApple(credential, nonce: nonce) }
        }
        .frame(height: 50)
      }
      if let error = model.error { Text(error).tollText(.subhead) }
      QuietButton(Copy.FriendDetail.cancel, tone: .secondary) { model.confirmDelete = false }
    }
    .tollGutter()
    .padding(.top, 24)
    .presentationDetents([.medium])
  }
}

struct BlockedPeopleView: View {
  let model: SettingsModel

  var body: some View {
    List(model.blockedPeople) { person in
      HStack {
        Text(person.displayName)
        Spacer()
        QuietButton(Copy.Settings.unblock) { Task { await model.unblock(person) } }
      }
    }
    .navigationTitle(Copy.Settings.blockedPeople)
  }
}

/// Edit name, handle and photo (flows §16); reuses the You step's model.
struct AccountEditView: View {
  let app: AppModel
  @State private var model: YouModel?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      if let model {
        @Bindable var model = model
        TextField(Copy.You.name, text: $model.name)
        TextField(Copy.You.handle, text: $model.handle)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        Text(Copy.You.note).tollText(.caption)
      }
    }
    .navigationTitle(Copy.Settings.account)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(Copy.Settings.save) { Task { await model?.save(); dismiss() } }
      }
    }
    .task {
      if model == nil {
        model = YouModel(app: app)
        await model?.load()
      }
    }
  }
}
