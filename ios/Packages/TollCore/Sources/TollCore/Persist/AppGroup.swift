import Foundation

/// The container shared by the app and its three extensions (spec §6, §11.1).
public enum AppGroup {
  public static let fallbackIdentifier = "group.com.advan.toll"

  /// Read from Info.plist so a rename is one build setting (`TOLL_APP_GROUP`), not a code change.
  public static let identifier: String =
    Bundle.main.object(forInfoDictionaryKey: "TollAppGroup") as? String ?? fallbackIdentifier

  /// Resolved once per process: every gate store, spool and registry value starts from this lookup, and
  /// the container cannot move while the process lives.
  public static let containerURL: URL = {
    #if canImport(Darwin)
      if let url = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppGroup.identifier)
      {
        return url
      }
    #endif
    return FileManager.default.temporaryDirectory.appending(
      path: AppGroup.identifier, directoryHint: .isDirectory)
  }()

  public static func file(_ name: String) -> URL {
    containerURL.appending(path: name, directoryHint: .notDirectory)
  }
}

/// What a file holds, told apart from a file that's there but can't be opened: before the first
/// unlock after a restart, data protection keeps the App Group's files closed, and reading that as
/// "no file" would write an empty state over a person's setup.
public enum FileContents: Sendable, Equatable {
  case missing
  case data(Data)
  case unreadable

  init(at url: URL) {
    guard FileManager.default.fileExists(atPath: url.path) else {
      self = .missing
      return
    }
    guard let data = try? Data(contentsOf: url) else {
      self = .unreadable
      return
    }
    self = .data(data)
  }

  public var data: Data? {
    if case .data(let data) = self { data } else { nil }
  }
}

/// Reads and writes a file under file coordination, so the app and an extension never interleave writes.
/// Coordination is Darwin-only; elsewhere (tests on Linux) plain I/O is enough.
public enum CoordinatedFile {
  public static func read(_ url: URL) -> Data? {
    contents(url).data
  }

  /// `.unreadable` too when coordination refused the file.
  public static func contents(_ url: URL) -> FileContents {
    var result = FileContents.unreadable
    coordinate(url, writing: false) { result = FileContents(at: $0) }
    return result
  }

  /// One coordinated read and write: `body` sees what's there and may replace it, atomically, or
  /// keep copies beside it first. Returns false, without calling `body`, if coordination refused.
  @discardableResult
  public static func change(_ url: URL, _ body: (FileContents, Writer) -> Void) -> Bool {
    var ran = false
    coordinate(url, writing: true) { target in
      ran = true
      body(FileContents(at: target), Writer(url: target))
    }
    return ran
  }

  /// Writes inside `change`, beside the coordinated file.
  public struct Writer {
    let url: URL

    /// Written to a temporary file, then moved over the old one, so a reader never sees half.
    @discardableResult
    public func replace(with data: Data) -> Bool {
      try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      return (try? data.write(to: url, options: .atomic)) != nil
    }

    /// A copy named `name` in the same folder, never written over: a taken name gets a number.
    @discardableResult
    public func keep(_ data: Data, as name: String, ext: String = "json") -> Bool {
      let folder = url.deletingLastPathComponent()
      for attempt in 0..<20 {
        let file = folder.appending(
          path: attempt == 0 ? "\(name).\(ext)" : "\(name)-\(attempt).\(ext)",
          directoryHint: .notDirectory)
        if (try? data.write(to: file, options: .withoutOverwriting)) != nil { return true }
      }
      return false
    }

    /// Whether a kept copy of that name is already there.
    public func has(_ name: String, ext: String = "json") -> Bool {
      FileManager.default.fileExists(
        atPath: url.deletingLastPathComponent().appending(path: "\(name).\(ext)").path)
    }
  }

  /// Read-modify-write as one coordinated operation. Return nil from `transform` to leave the file
  /// alone. A file that's there but can't be read is never written over.
  public static func update(_ url: URL, _ transform: (Data?) -> Data?) {
    change(url) { contents, writer in
      guard contents != .unreadable, let next = transform(contents.data) else { return }
      writer.replace(with: next)
    }
  }

  /// The last `bytes` of a file, from the first whole line in them, and whether that is the whole
  /// file: an extension reads a log's end without holding all of it.
  public static func tail(_ url: URL, bytes: Int) -> (lines: [Data], whole: Bool) {
    var result: (lines: [Data], whole: Bool) = ([], true)
    coordinate(url, writing: false) { target in
      guard let handle = try? FileHandle(forReadingFrom: target) else { return }
      defer { try? handle.close() }
      guard let size = try? handle.seekToEnd() else { return }
      let start = size > UInt64(bytes) ? size - UInt64(bytes) : 0
      guard (try? handle.seek(toOffset: start)) != nil, let data = try? handle.readToEnd() else {
        return
      }
      var lines = data.split(separator: 0x0A, omittingEmptySubsequences: false)
      // A cut first line is part of a line before the tail.
      if start > 0, !lines.isEmpty { lines.removeFirst() }
      result = (lines.filter { !$0.isEmpty }.map { Data($0) }, start == 0)
    }
    return result
  }

  /// Whether every byte went in.
  @discardableResult
  public static func append(_ data: Data, to url: URL) -> Bool {
    var written = false
    coordinate(url, writing: true) { target in
      let manager = FileManager.default
      if !manager.fileExists(atPath: target.path) {
        try? manager.createDirectory(
          at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = manager.createFile(atPath: target.path, contents: nil)
      }
      guard let handle = try? FileHandle(forWritingTo: target) else { return }
      defer { try? handle.close() }
      guard (try? handle.seekToEnd()) != nil else { return }
      written = (try? handle.write(contentsOf: data)) != nil
    }
    return written
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
