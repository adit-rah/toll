import Foundation
import Testing

@testable import TollCore

struct ConfigTests {
  @Test func remoteKeysOverrideAndMissingKeysKeepDefaults() {
    let json = #"{"gate":{"waits":[4,6]},"insights":{"minN":7},"unknown":{"x":1}}"#
    let config = TollConfig.merging(remoteJSON: Data(json.utf8))
    #expect(config.gate.waits == [4, 6])
    #expect(config.gate.freePassesPerDay == 2)
    #expect(config.insights.minN == 7)
    #expect(config.blocks.presets.nights.start == ClockTime(hour: 23))
  }

  @Test func malformedRemoteConfigFallsBackToDefaults() {
    #expect(TollConfig.merging(remoteJSON: Data("nope".utf8)) == .defaults)
    #expect(TollConfig.merging(remoteJSON: Data(#"{"gate":{"waits":"x"}}"#.utf8)) == .defaults)
  }

  @Test func defaultsMatchSpec14() {
    let c = TollConfig.defaults
    #expect(c.gate.freePassesPerDay == 2 && c.gate.waits == [3, 5, 8] && c.gate.dayResetHour == 4)
    #expect(c.gate.sessionMinutes == [5, 10, 15] && c.gate.resumeWindowSeconds == 120)
    #expect(c.blocks.maxTokens == 40 && c.blocks.max == 8 && c.notify.hour == 10)
    #expect(
      c.network.tags == ["instagram", "tiktok", "youtube", "snapchat", "x", "reddit", "other"])
  }

  @Test func uuidV7IsTimeOrderedAndVersioned() {
    let a = UUID.v7(at: Date(timeIntervalSince1970: 1))
    let b = UUID.v7(at: Date(timeIntervalSince1970: 2))
    #expect(a.lowercasedString < b.lowercasedString)
    #expect(Array(a.lowercasedString)[14] == "7")
  }
}
