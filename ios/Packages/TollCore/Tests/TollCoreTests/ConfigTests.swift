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
    #expect(config.trial.nights == 14)
    #expect(config.blocks.maxApps == 40)
    #expect(config.headsUp.leadMinutes == 20)
    #expect(config.headsUp.nightsAhead == 7)
    #expect(config.flows.offers == 3)
    #expect(config.band.nightMinutes == 60)
    // The heads-up falls inside the night's hour on Tonight's band; flows use that hour itself.
    #expect(config.band.nightMinutes >= config.headsUp.leadMinutes)
  }
}
