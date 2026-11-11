import AuthenticationServices
import SwiftUI
import TollCore
import TollUI

/// Welcome → (Apple sheet | Email → Code) (spec §9, flows §1–§2). As a sheet it is the sign-in for a solo
/// user who later wants friends (flows §20).
struct WelcomeFlow: View {
  let app: AppModel
  var asSheet = false
  @State private var model: SignInModel?
  @State private var legal: URL?

  var body: some View {
    ZStack {
      if let model {
        @Bindable var bound = model
        NavigationStack(path: $bound.path) {
          welcome(model)
            .navigationDestination(for: SignInModel.Step.self) { step in
              switch step {
              case .email: EmailView(model: model)
              case .code: CodeView(model: model)
              }
            }
        }
      }
    }
    .task { if model == nil { model = SignInModel(app: app) } }
    .sheet(item: $legal) { url in SafariView(url: url).ignoresSafeArea() }
  }

  private func welcome(_ model: SignInModel) -> some View {
    VStack(spacing: 0) {
      Spacer()
      VStack(spacing: 20) {
        Circle().strokeBorder(TollColor.label, lineWidth: 7).frame(width: 56, height: 56).accessibilityHidden(true)
        Text(Copy.Welcome.name).font(.system(size: 40, weight: .semibold)).accessibilityAddTraits(.isHeader)
      }
      Spacer()
      SignInWithAppleButton(.continue) { model.prepare($0) } onCompletion: { result in
        Task { await model.completeApple(result) }
      }
      .signInWithAppleButtonStyle(.black)
      .frame(height: 50)
      .clipShape(RoundedRectangle(cornerRadius: TollRadius.button, style: .continuous))
      Button(Copy.Welcome.email) { model.path.append(.email) }
        .buttonStyle(.tollSecondary)
        .padding(.top, TollSpacing.labelGap)
      if !asSheet {
        QuietButton(Copy.Welcome.solo, tone: .secondary) { Task { await model.continueSolo() } }
      }
      // The sheet has no quiet action above the legal line, so it needs the gap that action gives.
      legalLine
        .padding(.horizontal, 12)
        .padding(.top, asSheet ? 16 : 0)
        .padding(.bottom, TollSpacing.footerBottom)
    }
    .tollGutter()
    .background(TollColor.bg)
    .toolbar(.hidden, for: .navigationBar)
  }

  private var legalLine: some View {
    let base = URL(string: "https://\(Bundle.main.object(forInfoDictionaryKey: "TollLinkHost") as? String ?? "toll.alders.dev")")
    var text = AttributedString(Copy.Welcome.legalPrefix)
    var terms = AttributedString(Copy.Welcome.terms)
    terms.link = base?.appending(path: "terms")
    var privacy = AttributedString(Copy.Welcome.privacy)
    privacy.link = base?.appending(path: "privacy")
    text += terms + AttributedString(Copy.Welcome.and) + privacy + AttributedString(Copy.Welcome.legalSuffix)
    return Text(text)
      .font(.caption2)
      .foregroundStyle(TollColor.label3)
      .multilineTextAlignment(.center)
      .tint(TollColor.label2)
      .environment(\.openURL, OpenURLAction { url in
        legal = url
        return .handled
      })
  }
}

struct EmailView: View {
  @Bindable var model: SignInModel
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScreenTitle(Copy.Email.title)
      FilledField(Copy.Email.field, text: $model.email, isFocused: $focused)
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.send)
        .onSubmit { Task { await model.sendCode() } }
        .padding(.top, TollSpacing.titleGap)
      if let error = model.emailError {
        Text(error).tollText(.subhead).padding(.top, TollSpacing.labelGap)
      }
      PrimaryButton(Copy.Email.send) { Task { await model.sendCode() } }
        .disabled(model.isWorking || model.email.isEmpty)
        .padding(.top, 12)
      Text(Copy.Email.note).tollText(.caption).frame(maxWidth: .infinity).padding(.top, 16)
      Spacer()
    }
    .tollGutter()
    .background(TollColor.bg)
    .onAppear { focused = true }
  }
}

struct CodeView: View {
  @Bindable var model: SignInModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScreenTitle(Copy.Code.title)
      Text(Copy.Code.sentTo(model.email)).tollText(.subhead).padding(.top, TollSpacing.labelGap)
      CodeBoxes(code: $model.code, shakeTrigger: model.shakeCount, accessibilityLabel: Copy.Code.title) { _ in
        Task { await model.codeChanged() }
      }
      .padding(.top, TollSpacing.titleGap)
      if let error = model.codeError {
        Text(error).tollText(.subhead).padding(.top, 12)
      }
      QuietButton(Copy.Code.resend) { Task { await model.resend() } }
        .disabled(!model.canResend)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
      Spacer()
    }
    .tollGutter()
    .background(TollColor.bg)
  }
}
