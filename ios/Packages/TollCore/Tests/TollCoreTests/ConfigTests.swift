import Testing

@testable import TollCore

struct ConfigTests {
  @Test func defaultsMatchSpec() {
    let config = TollConfig.defaults
    #expect(config.window.leadHours == 8.5)
    #expect(config.home.radiusMeters == 150)
    #expect(config.door.waitSeconds == 60)
    #expect(config.door.minutes == 10)
    #expect(config.door.regretSeconds == 120)
    #expect(config.unlocks.max == 3)
    #expect(config.unlocks.refillWeekday == 2)
    #expect(config.trial.nights == 7)
    #expect(config.blocks.maxApps == 40)
  }
}
