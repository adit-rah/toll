import Foundation
import Testing

@testable import TollCore

/// D65, D68, D70: plain words only. Dusk-only terms ("door", "unlock"), the night's old names
/// ("sleep window", "bedtime"), judgement ("missed", streaks, praise, "!") and population norms
/// ("most adults") never reach a screen. Scans the text of every string literal in `Copy`.
struct CopyTermsTests {
  static let banned = [
    "door", "unlock", "sleep window", "sleep hours", "time window", "bedtime", "streak", "missed",
    "!", "great", "awesome", "most adults",
  ]

  /// A literal that may hold a banned term, and why. Empty today; add one only with its reason.
  static let allowed: [(term: String, literal: String, reason: String)] = []

  @Test func copyHasNoBannedTerms() throws {
    let literals = try Self.copyLiterals()
    #expect(literals.count > 200, "the scan read the Copy files")
    var found: [String] = []
    for (file, literal) in literals {
      let text = literal.lowercased()
      for term in Self.banned where text.contains(term) {
        let excused = Self.allowed.contains { $0.term == term && literal.contains($0.literal) }
        if !excused { found.append("\(file): \"\(literal)\" has \"\(term)\"") }
      }
    }
    #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
  }

  @Test func scannerSkipsInterpolationsAndComments() {
    let source = """
      // "door" in a comment
      let a = "Night \\(unlocksLeft) of \\(n == 1 ? "one" : "\\(n) left")"
      /* "unlock" */ let b = "x\\"y"
      """
    #expect(Literals.scan(source) == ["one", "… left", "Night … of …", "x\"y"])
  }

  static func copyLiterals() throws -> [(String, String)] {
    let copy = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/TollCore/Copy")
    let files = try FileManager.default.contentsOfDirectory(atPath: copy.path)
      .filter { $0.hasSuffix(".swift") }.sorted()
    return try files.flatMap { file in
      let source = try String(contentsOf: copy.appendingPathComponent(file), encoding: .utf8)
      return Literals.scan(source).map { (file, $0) }
    }
  }
}

/// The text of a Swift file's string literals: interpolations are code, so their own literals count
/// and their identifiers ("unlocksLeft") don't. Comments are skipped.
enum Literals {
  static func scan(_ source: String) -> [String] {
    var scanner = Scanner(chars: Array(source))
    scanner.code(interpolation: false)
    return scanner.found
  }

  private struct Scanner {
    let chars: [Character]
    var at = 0
    var found: [String] = []

    init(chars: [Character]) { self.chars = chars }

    func peek(_ offset: Int = 0) -> Character? {
      at + offset < chars.count ? chars[at + offset] : nil
    }

    mutating func code(interpolation: Bool) {
      var depth = 0
      while let c = peek() {
        if c == "/", peek(1) == "/" {
          while let n = peek(), n != "\n" { at += 1 }
        } else if c == "/", peek(1) == "*" {
          at += 2
          while peek() != nil, !(peek() == "*" && peek(1) == "/") { at += 1 }
          at += 2
        } else if c == "\"" {
          let triple = peek(1) == "\"" && peek(2) == "\""
          at += triple ? 3 : 1
          string(triple: triple)
        } else if c == "(" {
          depth += 1
          at += 1
        } else if c == ")" {
          at += 1
          if interpolation, depth == 0 { return }
          depth -= 1
        } else {
          at += 1
        }
      }
    }

    mutating func string(triple: Bool) {
      var text = ""
      while let c = peek() {
        if c == "\\" {
          if peek(1) == "(" {
            at += 2
            text.append("…")
            code(interpolation: true)
          } else {
            if let escaped = peek(1) { text.append(escaped) }
            at += 2
          }
        } else if c == "\"", !triple || (peek(1) == "\"" && peek(2) == "\"") {
          at += triple ? 3 : 1
          break
        } else {
          text.append(c)
          at += 1
        }
      }
      if !text.isEmpty { found.append(text) }
    }
  }
}
