import Foundation
import Testing

@testable import TollCore

struct ShieldTextTests {
  @Test func sleepSaysUntilWhenAndWhy() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    let text = ShieldText(state: s, block: s.sleepBlock, calendar: london)
    #expect(text.title.hasPrefix("Blocked until 7"))
    #expect(text.subtitle == "It's your sleep time. 3 of 3 unlocks left.")
    #expect(text.offersDoor)
  }

  @Test func otherBlocksSayTheirNameAndPlace() {
    var s = setUp(home: false)
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 9))
    run(&s, date(2026, 11, 17, 10))
    let text = ShieldText(state: s, block: s.block(BlockID("study")), calendar: london)
    #expect(text.title.hasPrefix("Study · until 5"))
    #expect(text.subtitle == "This app is blocked during Study. 3 of 3 unlocks left.")
  }

  @Test func withoutLocationNoPlaceIsClaimed() {
    var s = setUp(home: false)
    s.location = .scheduleOnly
    run(&s, date(2026, 11, 17, 23))
    #expect(
      ShieldText(state: s, block: s.sleepBlock, calendar: london).subtitle
        == "It's your sleep time. 3 of 3 unlocks left.")
  }

  @Test func atNoneLeftTheDoorIsNotOfferedAndItSaysWhenOneReturns() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    s.unlocks.spent = 3
    s.unlocks.cleanNights = 2
    let text = ShieldText(state: s, block: s.sleepBlock, calendar: london)
    #expect(!text.offersDoor)
    #expect(
      text.subtitle
        == "It's your sleep time. No unlocks left. One returns after 5 nights without using any.")
  }
}
