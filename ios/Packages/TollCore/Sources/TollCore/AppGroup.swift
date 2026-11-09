import Foundation

/// The container shared by the app and its three extensions (spec §6, §11.1).
public enum AppGroup {
  public static let fallbackIdentifier = "group.com.advan.toll"

  /// Read from Info.plist so a rename is one build setting (`TOLL_APP_GROUP`), not a code change.
  public static var identifier: String {
    Bundle.main.object(forInfoDictionaryKey: "TollAppGroup") as? String ?? fallbackIdentifier
  }

  public static var containerURL: URL {
    #if canImport(Darwin)
      if let url = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: identifier)
      {
        return url
      }
    #endif
    return FileManager.default.temporaryDirectory.appending(
      path: identifier, directoryHint: .isDirectory)
  }

  public static var defaults: UserDefaults {
    UserDefaults(suiteName: identifier) ?? .standard
  }
}
