import SwiftUI
import TollCore
import TollData
import TollUI

/// Settings (design §4.8, flows §16): a standard grouped list. Delete account is a two-step confirm
/// with re-authentication.
struct SettingsView: View {
  let app: AppModel
  @State private var model: SettingsModel?
  @State private var legal: URL?
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    ZStack {
      if let model { list(model) }
    }
    // The model arrives a frame after the push; without this the page is white for that frame.
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TollColor.bgGrouped)
    .navigationTitle(Copy.Settings.title)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if model == nil { model = SettingsModel(app: app) }
      await model?.refresh()
    }
    .sheet(item: $legal) { SafariView(url: $0).ignoresSafeArea() }
  }

  private func list(_ model: SettingsModel) -> some View {
    @Bindable var bound = model
    return List {
      account(model)
      if app.isSignedIn {
        school(model)
        Section(Copy.Settings.notifications) {
          if app.notificationsAllowed == false {
            // A switch for a summary the system will not deliver would be a lie; the way to turn
            // them on takes its place. Two rows, so the button is a full-width target at any text size.
            Text(Copy.Settings.notificationsOff)
            Button(Copy.Settings.openSettings) { Task { await model.allowNotifications() } }
          } else {
            Toggle(Copy.Settings.dailySummary, isOn: $bound.notifyEnabled)
            if model.notifyEnabled {
              Picker(Copy.Settings.time, selection: $bound.notifyHour) {
                ForEach(0..<24, id: \.self) { Text(Copy.Schedules.time(ClockTime(hour: $0))).tag($0) }
              }
            }
          }
        }
        Section {
          Toggle(Copy.Settings.letContactsFind, isOn: $bound.discoverable)
        } header: {
          Text(Copy.Settings.discoverability)
        } footer: {
          // Under the switches that just went back, which is where the eye is.
          if let error = model.saveError { Text(error) }
        }
      }
      Section(Copy.Blocks.title) {
        // A value, not a destination: every push in Home's stack goes through its path.
        NavigationLink(value: HomeRoute.blocks) {
          if let count = model.blockedAppCount {
            LabeledContent(Copy.Settings.blockedApps, value: "\(count)")
          } else {
            Text(Copy.Settings.blockedApps)
          }
        }
        if !model.blockedPeople.isEmpty {
          NavigationLink(Copy.Settings.blockedPeople) { BlockedPeopleView(model: model) }
        }
      }
      Section(Copy.Settings.data) {
        ShareLink(item: model.export, preview: SharePreview(Copy.Settings.export)) {
          Text(Copy.Settings.export)
        }
        if app.isSignedIn {
          Button(Copy.Settings.delete, role: .destructive) { model.beginDelete() }
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
    }
    .listStyle(.insetGrouped)
    .onChange(of: model.notifyEnabled) { Task { await model.save() } }
    .onChange(of: model.notifyHour) { Task { await model.save() } }
    .onChange(of: model.discoverable) { Task { await model.save() } }
    .confirmationDialog(Copy.Settings.signOutConfirm, isPresented: $bound.confirmSignOut, titleVisibility: .visible) {
      Button(Copy.Settings.signOut, role: .destructive) { Task { await model.signOut() } }
    }
    .confirmationDialog(
      Copy.Settings.leaveConfirm(app.me?.school?.name ?? ""), isPresented: $bound.confirmLeaveSchool,
      titleVisibility: .visible
    ) {
      Button(Copy.Settings.leave, role: .destructive) { Task { await model.leaveSchool() } }
    }
    .sheet(isPresented: $bound.confirmDelete) { DeleteAccountSheet(model: model) }
  }

  private func account(_ model: SettingsModel) -> some View {
    Section(Copy.Settings.account) {
      if let me = app.me, app.isSignedIn {
        NavigationLink {
          AccountEditView(app: app)
        } label: {
          HStack(spacing: TollSpacing.rowLeadingGap) {
            Avatar(
              name: me.displayName ?? "", handle: me.handle ?? "", photoURL: me.photoUrl.flatMap(URL.init(string:)),
              size: .settings)
            VStack(alignment: .leading, spacing: 2) {
              Text(me.displayName ?? "").tollText(.headline)
              Text("@\(me.handle ?? "")").tollText(.caption)
            }
            Spacer(minLength: TollSpacing.labelGap)
            // At accessibility sizes the name needs the width more than the chevron needs a caption.
            if !typeSize.isAccessibilitySize {
              Text(Copy.Settings.edit).tollText(.subhead)
            }
          }
          .padding(.vertical, 4)
          .accessibilityElement(children: .combine)
        }
        Button(Copy.Settings.signOut) { model.confirmSignOut = true }
      } else {
        Button(Copy.Settings.signIn) { app.showsSignInSheet = true }
      }
    }
  }

  private func school(_ model: SettingsModel) -> some View {
    Section(Copy.Settings.school) {
      if let school = app.me?.school {
        HStack(spacing: TollSpacing.labelGap) {
          Text(school.name).tollText(.body)
          Spacer(minLength: 0)
          // Borderless, or the whole row becomes the button and a tap on the name asks to leave.
          Button(Copy.Settings.leave, role: .destructive) { model.confirmLeaveSchool = true }
            .buttonStyle(.borderless)
        }
      } else {
        FindFriendsView(app: app, isSetup: false, parts: [.school], showsHeaders: false)
      }
    }
  }
}
