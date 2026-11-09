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

  public static func file(_ name: String) -> URL {
    containerURL.appending(path: name, directoryHint: .notDirectory)
  }
}

/// Reads and writes a file under file coordination, so the app and an extension never interleave writes.
/// Coordination is Darwin-only; elsewhere (tests on Linux) plain I/O is enough.
public enum CoordinatedFile {
  public static func read(_ url: URL) -> Data? {
    var result: Data?
    coordinate(url, writing: false) { result = try? Data(contentsOf: $0) }
    return result
  }

  /// Read-modify-write as one coordinated operation. Return nil from `transform` to leave the file alone.
  public static func update(_ url: URL, _ transform: (Data?) -> Data?) {
    coordinate(url, writing: true) { target in
      let current = try? Data(contentsOf: target)
      guard let next = transform(current) else { return }
      try? FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? next.write(to: target, options: .atomic)
    }
  }

  public static func append(_ data: Data, to url: URL) {
    coordinate(url, writing: true) { target in
      let manager = FileManager.default
      if !manager.fileExists(atPath: target.path) {
        try? manager.createDirectory(
          at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = manager.createFile(atPath: target.path, contents: nil)
      }
      guard let handle = try? FileHandle(forWritingTo: target) else { return }
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    }
  }

  private static func coordinate(_ url: URL, writing: Bool, _ body: (URL) -> Void) {
    #if canImport(Darwin)
      let coordinator = NSFileCoordinator(filePresenter: nil)
      var error: NSError?
      if writing {
        coordinator.coordinate(writingItemAt: url, options: [], error: &error, byAccessor: body)
      } else {
        coordinator.coordinate(readingItemAt: url, options: [], error: &error, byAccessor: body)
      }
    #else
      body(url)
    #endif
  }
}
