#if os(iOS)
  @preconcurrency import FamilyControls
  import Foundation
  @preconcurrency import ManagedSettings
  import TollCore
  import os

  /// The device-only map from app refs to picker tokens (spec §4 "App ref"). Written by the app; read by
  /// the app and the extensions. Tokens are opaque and never leave this phone.
  public struct TokenRegistry: Sendable {
    struct Entry: Codable, Sendable {
      var kind: TokenKind
      var data: Data
    }

    public let url: URL

    public init(url: URL = AppGroup.file("tokens.json")) {
      self.url = url
    }

    /// What identifies one written version of the file: every write replaces it atomically, so a new
    /// version always differs in at least one of these.
    private struct Stamp: Equatable, Sendable {
      var modified: Date
      var size: Int
      var fileNumber: Int
    }

    private struct Snapshot: Sendable {
      var url: URL
      var stamp: Stamp
      var entries: [AppRef: Entry]
    }

    /// The decoded file, kept per process until the file changes. Labels and the shield ask for tokens
    /// on every draw; a coordinated read and a full decode each time is main-thread I/O.
    private static let snapshot = OSAllocatedUnfairLock<Snapshot?>(initialState: nil)

    private func currentStamp() -> Stamp? {
      guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
        let modified = attributes[.modificationDate] as? Date,
        let size = attributes[.size] as? NSNumber,
        let fileNumber = attributes[.systemFileNumber] as? NSNumber
      else { return nil }
      return Stamp(modified: modified, size: size.intValue, fileNumber: fileNumber.intValue)
    }

    private func load() -> [AppRef: Entry] {
      // Stamped before reading: a write that lands in between leaves an older stamp on newer entries,
      // which the next call sees as a change and reads again.
      let stamp = currentStamp()
      let cached = Self.snapshot.withLock { $0 }
      if let stamp, let cached, cached.url == url, cached.stamp == stamp { return cached.entries }
      guard let data = CoordinatedFile.read(url) else { return [:] }
      let entries = (try? JSONDecoder().decode([AppRef: Entry].self, from: data)) ?? [:]
      if let stamp {
        let fresh = Snapshot(url: url, stamp: stamp, entries: entries)
        Self.snapshot.withLock { $0 = fresh }
      }
      return entries
    }

    /// Returns the app refs for a picker selection, reusing a ref for any token already registered.
    public func register(_ selection: FamilyActivitySelection) -> [AppRef] {
      var refs: [AppRef] = []
      CoordinatedFile.update(url) { data in
        var entries =
          data.flatMap { try? JSONDecoder().decode([AppRef: Entry].self, from: $0) } ?? [:]
        func refFor(_ kind: TokenKind, _ encoded: Data) -> AppRef {
          if let existing = entries.first(where: {
            $0.value.kind == kind && $0.value.data == encoded
          }) {
            return existing.key
          }
          let ref = AppRef.make()
          entries[ref] = Entry(kind: kind, data: encoded)
          return ref
        }
        let encoder = Self.encoder
        for token in selection.applicationTokens {
          if let encoded = try? encoder.encode(token) { refs.append(refFor(.application, encoded)) }
        }
        for token in selection.webDomainTokens {
          if let encoded = try? encoder.encode(token) { refs.append(refFor(.webDomain, encoded)) }
        }
        for token in selection.categoryTokens {
          if let encoded = try? encoder.encode(token) { refs.append(refFor(.category, encoded)) }
        }
        return try? JSONEncoder().encode(entries)
      }
      return refs
    }

    /// Registers one encoded token seen by an extension (an app inside a blocked category).
    public func register(encoded: Data, kind: TokenKind) -> AppRef {
      var ref = AppRef.make()
      CoordinatedFile.update(url) { data in
        var entries =
          data.flatMap { try? JSONDecoder().decode([AppRef: Entry].self, from: $0) } ?? [:]
        if let existing = entries.first(where: { $0.value.kind == kind && $0.value.data == encoded }
        ) {
          ref = existing.key
          return nil
        }
        entries[ref] = Entry(kind: kind, data: encoded)
        return try? JSONEncoder().encode(entries)
      }
      return ref
    }

    public func remove(_ refs: Set<AppRef>) {
      CoordinatedFile.update(url) { data in
        var entries =
          data.flatMap { try? JSONDecoder().decode([AppRef: Entry].self, from: $0) } ?? [:]
        for ref in refs { entries[ref] = nil }
        return try? JSONEncoder().encode(entries)
      }
    }

    public func ref(for token: ApplicationToken) -> AppRef? {
      ref(kind: .application, token: token)
    }
    public func ref(for token: WebDomainToken) -> AppRef? { ref(kind: .webDomain, token: token) }
    public func ref(for token: ActivityCategoryToken) -> AppRef? {
      ref(kind: .category, token: token)
    }

    private func ref<T: Codable & Equatable>(kind: TokenKind, token: T) -> AppRef? {
      for (ref, entry) in load() where entry.kind == kind {
        if let decoded = try? JSONDecoder().decode(T.self, from: entry.data), decoded == token {
          return ref
        }
      }
      return nil
    }

    public struct Tokens {
      public var applications: Set<ApplicationToken> = []
      public var webDomains: Set<WebDomainToken> = []
      public var categories: Set<ActivityCategoryToken> = []

      public var isEmpty: Bool { applications.isEmpty && webDomains.isEmpty && categories.isEmpty }
      public var count: Int { applications.count + webDomains.count + categories.count }
    }

    public func tokens(for refs: some Sequence<AppRef>) -> Tokens {
      let entries = load()
      var tokens = Tokens()
      let decoder = JSONDecoder()
      for ref in refs {
        guard let entry = entries[ref] else { continue }
        switch entry.kind {
        case .application:
          if let t = try? decoder.decode(ApplicationToken.self, from: entry.data) {
            tokens.applications.insert(t)
          }
        case .webDomain:
          if let t = try? decoder.decode(WebDomainToken.self, from: entry.data) {
            tokens.webDomains.insert(t)
          }
        case .category:
          if let t = try? decoder.decode(ActivityCategoryToken.self, from: entry.data) {
            tokens.categories.insert(t)
          }
        }
      }
      return tokens
    }

    /// A picker selection holding exactly these refs, to prefill the picker when editing a block.
    public func selection(for refs: [AppRef]) -> FamilyActivitySelection {
      let tokens = tokens(for: refs)
      var selection = FamilyActivitySelection()
      selection.applicationTokens = tokens.applications
      selection.webDomainTokens = tokens.webDomains
      selection.categoryTokens = tokens.categories
      return selection
    }

    public func kind(of ref: AppRef) -> TokenKind? { load()[ref]?.kind }

    public static func encode(_ token: ApplicationToken) -> Data? { try? encoder.encode(token) }
    public static func encode(_ token: WebDomainToken) -> Data? { try? encoder.encode(token) }
    public static func encode(_ token: ActivityCategoryToken) -> Data? {
      try? encoder.encode(token)
    }

    private static var encoder: JSONEncoder {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      return encoder
    }
  }
#endif
