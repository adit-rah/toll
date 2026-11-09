import AuthenticationServices
import CryptoKit
import Foundation

/// Nonce handling for Sign in with Apple: the request carries the SHA-256, the server receives the raw
/// value and checks the token's nonce claim against it.
public struct AppleNonce: Sendable {
  public let raw: String

  public init() {
    raw = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
  }

  public var hashed: String {
    SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

public struct AppleCredential: Sendable {
  public var identityToken: String
  public var authorizationCode: String
  public var givenName: String?
  public var familyName: String?

  public init?(_ authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
      let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
      let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) })
    else { return nil }
    identityToken = token
    authorizationCode = code
    givenName = credential.fullName?.givenName
    familyName = credential.fullName?.familyName
  }
}
