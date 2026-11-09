import SafariServices
import SwiftUI

/// The in-app web view for Terms and Privacy Policy (flows §1, §16).
struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
  public var id: String { absoluteString }
}
