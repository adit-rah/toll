import Foundation
import Testing

@testable import TollCore

struct ShieldTextTests {
  @Test func sleepSaysUntilWhenAndWhy() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    let text = ShieldText(state: s, block: s.sleepBlock, calendar: london)
    #expect(text.title.hasPrefix("Blocked until 7"))
    #expect(text.subtitle == Copy.Shield.subtitle)
  }

  @Test func otherBlocksSayTheirNameAndPlace() {
    var s = setUp(home: false)
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 9))
    run(&s, date(2026, 11, 17, 10))
    let text = ShieldText(state: s, block: s.block(BlockID("study")), calendar: london)
    #expect(text.title.hasPrefix("Study · until 5"))
    #expect(text.subtitle == "You're at Library.")
  }

  @Test func withoutLocationNoPlaceIsClaimed() {
    var s = setUp(home: false)
    s.location = .scheduleOnly
    run(&s, date(2026, 11, 17, 23))
    #expect(
      ShieldText(state: s, block: s.sleepBlock, calendar: london).subtitle
        == Copy.Shield.subtitleWindowOnly)
  }
}
