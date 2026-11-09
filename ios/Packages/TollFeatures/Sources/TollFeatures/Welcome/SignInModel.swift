import AuthenticationServices
import Foundation
import Observation
import TollCore
import TollData

/// Welcome, Email and Code (spec §9, flows §1–§2). Errors are server codes mapped to Copy here, so no
/// user-facing text crosses the network.
@MainActor
@Observable
public final class SignInModel {
  public enum Step: Hashable { case email, code }

  let app: AppModel
  public var path: [Step] = []
  public var email = ""
  public var code = ""
  public private(set) var emailError: String?
  public private(set) var codeError: String?
  public private(set) var shakeCount = 0
  public private(set) var resendAvailableAt: Date?
  public private(set) var isWorking = false
  public private(set) var nonce = AppleNonce()

  public init(app: AppModel) {
    self.app = app
  }

  // MARK: Apple

  public func prepare(_ request: ASAuthorizationAppleIDRequest) {
    nonce = AppleNonce()
    request.requestedScopes = [.fullName, .email]
    request.nonce = nonce.hashed
  }

  public func completeApple(_ result: Result<ASAuthorization, Error>) async {
    guard case .success(let authorization) = result, let credential = AppleCredential(authorization) else { return }
    isWorking = true
    defer { isWorking = false }
    do {
      let session = try await app.deps.account.signInWithApple(
        identityToken: credential.identityToken, authorizationCode: credential.authorizationCode,
        rawNonce: nonce.raw, givenName: credential.givenName, familyName: credential.familyName)
      if let given = credential.givenName {
        try? await app.deps.store.setSetting("appleName", [given, credential.familyName].compactMap { $0 }.joined(separator: " "))
      }
      await app.signedIn(session)
    } catch {
      emailError = Copy.Errors.generic
    }
  }

  // MARK: Email

  public static func isPlausibleEmail(_ text: String) -> Bool {
    let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "@")
    return parts.count == 2 && parts[1].contains(".") && !parts[0].isEmpty && !parts[1].hasSuffix(".")
  }

  public func sendCode() async {
    let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
    guard Self.isPlausibleEmail(trimmed) else {
      emailError = Copy.Email.invalid
      return
    }
    email = trimmed
    emailError = nil
    isWorking = true
    defer { isWorking = false }
    do {
      try await app.deps.account.startEmail(trimmed)
      resendAvailableAt = app.deps.clock.now.addingTimeInterval(30)
      code = ""
      codeError = nil
      if path.last != .code { path.append(.code) }
    } catch let error as APIError {
      emailError = message(for: error)
    } catch {
      emailError = Copy.Errors.generic
    }
  }

  public func resend() async {
    guard canResend else { return }
    await sendCode()
  }

  public var canResend: Bool { (resendAvailableAt ?? .distantPast) <= app.deps.clock.now }

  /// Advances on the sixth digit with no button (design §2.5 "Code boxes").
  public func codeChanged() async {
    code = String(code.filter(\.isNumber).prefix(6))
    guard code.count == 6, !isWorking else { return }
    isWorking = true
    defer { isWorking = false }
    do {
      let session = try await app.deps.account.verifyEmail(email, code: code)
      await app.signedIn(session)
    } catch let error as APIError {
      codeError = message(for: error)
      shakeCount += 1
      code = ""
      if error.code == "locked" { path.removeAll { $0 == .code } }
    } catch {
      codeError = Copy.Errors.generic
    }
  }

  func message(for error: APIError) -> String {
    switch error.code {
    case "wrong_code": return Copy.Code.wrong
    case "expired": return Copy.Code.expired
    case "invalid_email": return Copy.Email.invalid
    case "locked":
      let until = error.payload["lockedUntil"]?.number.map { Date(millis: $0) } ?? app.deps.clock.now
      return Copy.Code.locked(until: until.formatted(date: .omitted, time: .shortened))
    case "rate_limited": return Copy.Code.resendIn(30)
    case APIError.transport: return Copy.Errors.offline
    default: return Copy.Errors.generic
    }
  }

  // MARK: Solo

  public func continueSolo() async {
    await app.chooseSolo()
  }
}
