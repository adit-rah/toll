import Foundation
import Testing

@testable import TollCore

struct StatusLevelTests {
  struct Input: Decodable, Sendable {
    let passesToday: Int
    let history: [Int]
  }

  static let cases =
    (try? Fixtures.load("status-levels.json", as: FixtureFile<Input, Int>.self).cases) ?? []

  @Test("fixtures load") func fixturesLoad() { #expect(Self.cases.count >= 15) }

  @Test(arguments: cases)
  func level(_ c: FixtureFile<Input, Int>.Case) {
    let level = StatusRules.level(
      passesToday: c.input.passesToday, history: c.input.history, config: TollConfig.defaults.status
    )
    #expect(level.rawValue == c.expected)
  }

  @Test func personalisationCanBeTurnedOff() {
    var config = TollConfig.Status()
    config.personalise = false
    #expect(
      StatusRules.level(passesToday: 3, history: Array(repeating: 10, count: 14), config: config)
        == .usual)
  }
}
