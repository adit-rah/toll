import AuthenticationServices
import SwiftUI
import TollCore
import TollData
import TollUI

/// The second step of deleting an account (spec §13): say what goes, re-authenticate, delete.
struct DeleteAccountSheet: View {
  @Bindable var model: SettingsModel
  @State private var nonce = AppleNonce()
  @Environment(\.colorScheme) private var colorScheme

  private var entersCode: Bool { model.isEmailAccount && model.deleteCodeSent }

  var body: some View {
    VStack(alignment: .leading, spacing: TollSpacing.grid * 2) {
      Text(Copy.Settings.deleteConfirm)
        .tollText(.title)
        .fixedSize(horizontal: false, vertical: true)
      if entersCode {
        Text(Copy.Settings.checkEmailToDelete).tollText(.subhead)
        CodeBoxes(
          code: $model.deleteCode, shakeTrigger: model.deleteShake, accessibilityLabel: Copy.Code.title,
          fill: TollColor.fill
        ) { _ in
          Haptics.warning()
          Task { await model.deleteWithEmailCode() }
        }
      }
      if let error = model.deleteError {
        Text(error).tollText(.subhead)
      }
    }
    // Pinned to the top: left to itself the stack floats in the middle of the sheet.
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(.top, TollSpacing.sectionGap)
    .tollGutter()
    .tollBottomBar(background: TollColor.bg) { actions }
    // The number pad covers the lower half of a medium sheet, boxes included.
    .presentationDetents(entersCode ? [.large] : [.medium])
    .presentationDragIndicator(.visible)
  }

  private var actions: some View {
    VStack(spacing: 0) {
      if !model.isEmailAccount {
        SignInWithAppleButton(.continue) { request in
          nonce = AppleNonce()
          request.nonce = nonce.hashed
        } onCompletion: { result in
          guard case .success(let auth) = result, let credential = AppleCredential(auth) else { return }
          Haptics.warning()
          Task { await model.deleteWithApple(credential, nonce: nonce) }
        }
        // Black on the dark sheet would be a hole, not a button.
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: TollRadius.button, style: .continuous))
      } else if !model.deleteCodeSent {
        DestructiveQuiet(Copy.Settings.continue) { Task { await model.sendDeleteCode() } }
      }
      QuietButton(Copy.FriendDetail.cancel, tone: .secondary) { model.confirmDelete = false }
    }
    .frame(maxWidth: .infinity)
  }
}

struct BlockedPeopleView: View {
  let model: SettingsModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    List(model.blockedPeople) { person in
      HStack(spacing: TollSpacing.rowLeadingGap) {
        Avatar(
          name: person.displayName, handle: person.handle, photoURL: person.photoUrl.flatMap(URL.init(string:)))
        VStack(alignment: .leading, spacing: 2) {
          Text(person.displayName).tollText(.headline).lineLimit(1)
          Text("@\(person.handle)").tollText(.caption).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        Spacer(minLength: TollSpacing.labelGap)
        QuietButton(Copy.Settings.unblock) { Task { await model.unblock(person) } }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(Copy.Settings.blockedPeople)
    .navigationBarTitleDisplayMode(.inline)
    // Unblocking the last person removes the row in Settings that leads here; an empty page with
    // nothing to do on it is not somewhere to be left.
    .onChange(of: model.blockedPeople.isEmpty) { _, isEmpty in
      if isEmpty { dismiss() }
    }
  }
}

/// Edit name and handle (flows §16); reuses the You step's model.
struct AccountEditView: View {
  let app: AppModel
  @State private var model: YouModel?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      if let model {
        @Bindable var bound = model
        Section {
          TextField(Copy.You.name, text: $bound.name)
            .textContentType(.name)
          HStack(spacing: TollSpacing.labelGap) {
            TextField(Copy.You.handle, text: $bound.handle)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
            if let status = handleStatus(model) {
              Text(status).tollText(.caption)
            }
          }
        } footer: {
          Text(model.error ?? (model.nameRinged ? Copy.Errors.nameInvalid : Copy.You.note))
        }
      }
    }
    .navigationTitle(Copy.Settings.account)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(Copy.Settings.save) { Task { await save() } }
          .disabled(model?.isSaving ?? true)
      }
    }
    .task {
      if model == nil {
        model = YouModel(app: app)
        await model?.load()
      }
    }
  }

  private func handleStatus(_ model: YouModel) -> String? {
    switch model.handleState {
    case .available: Copy.You.available
    case .taken: Copy.You.taken
    case .invalid: Copy.You.invalidHandle
    case .unknown, .checking: nil
    }
  }

  /// Leaves only when the account now holds what was typed; a refused name or handle stays on
  /// screen with its reason.
  private func save() async {
    guard let model else { return }
    await model.save()
    let name = model.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if model.error == nil, app.me?.displayName == name, app.me?.handle == model.handle.lowercased() { dismiss() }
  }
}
