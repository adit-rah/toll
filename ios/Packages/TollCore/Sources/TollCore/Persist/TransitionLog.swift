import Foundation

/// The append-only transition log (B-6), one JSON line per entry. The device protocol is read from it
/// (spec §11), and Settings shows it until the founders remove it.
public struct TransitionLog: Sendable {
  public let url: URL

  /// About ten nights of every wake; older lines go first.
  public static let maxLines = 2000

  public init(url: URL = AppGroup.file("transitions.jsonl")) {
    self.url = url
  }

  public func append(_ transition: Transition) {
    guard var line = try? DuskStore.encoder.encode(transition) else { return }
    line.append(0x0A)
    CoordinatedFile.append(line, to: url)
  }

  /// Newest first.
  public func read(limit: Int = maxLines) -> [Transition] {
    let decoder = DuskStore.decoder
    return Array(
      lines().compactMap { try? decoder.decode(Transition.self, from: $0) }.suffix(limit)
    )
    .reversed()
  }

  /// The lines in the file's last `bytes`, oldest first, and whether that's every line.
  public func tail(bytes: Int) -> (lines: [Transition], whole: Bool) {
    let decoder = DuskStore.decoder
    let tail = CoordinatedFile.tail(url, bytes: bytes)
    return (tail.lines.compactMap { try? decoder.decode(Transition.self, from: $0) }, tail.whole)
  }

  /// Run by the app, never an extension: rewriting the file is the one slow thing the log does.
  /// Only after the nights in it are recorded (`NightKeeper`).
  public func trim() {
    CoordinatedFile.update(url) { data in
      guard let data else { return nil }
      let lines = data.split(separator: 0x0A)
      guard lines.count > Self.maxLines else { return nil }
      return Data(lines.suffix(Self.maxLines).joined(separator: [0x0A])) + Data([0x0A])
    }
  }

  private func lines() -> [Data] {
    (CoordinatedFile.read(url) ?? Data()).split(separator: 0x0A).map { Data($0) }
  }
}
