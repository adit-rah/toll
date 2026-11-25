import Foundation
import Testing

@testable import TollCore

/// The coordinator runs commands and reconcile in one write and hands each effect to its port.
struct CoordinatorTests {
  final class Fakes: ShieldPort, SchedulePort, LogPort, @unchecked Sendable {
    // Test-only fake, used from one thread.
    var shields: [ShieldPlan] = []
    var windows: [[TimeWindow]] = []
    var doors: [String] = []
    var lines: [Transition] = []
    var failWindows = false

    func apply(_ plan: ShieldPlan) { shields.append(plan) }
    func monitor(windows: [TimeWindow]) throws {
      if failWindows { throw CancellationError() }
      self.windows.append(windows)
    }
    func startDoor(_ door: Door, config: TollConfig) throws { doors.append("start") }
    func stopDoor() { doors.append("stop") }
    func append(_ line: Transition) { lines.append(line) }
  }

  struct FixedClock: TollClock {
    var now: Date
    var monotonic: MonotonicInstant? {
      MonotonicInstant(bootID: "b", seconds: now.timeIntervalSinceReferenceDate)
    }
    var timeZone: TimeZone { TimeZone(identifier: "Europe/London") ?? .gmt }
  }

  func make() -> (Coordinator, Fakes, DuskStore) {
    let fakes = Fakes()
    let store = DuskStore(
      url: FileManager.default.temporaryDirectory.appending(path: "state-\(UUID().uuidString).json")
    )
    return (Coordinator(store: store, shield: fakes, schedule: fakes, log: fakes), fakes, store)
  }

  @Test func setupThenTheNightEndToEnd() {
    let (coordinator, fakes, store) = make()
    let setup = coordinator.run(
      .edit,
      [.finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 17, 15))],
      clock: FixedClock(now: date(2026, 11, 17, 15)))
    #expect(setup.error == nil)
    // A new install locks 30 minutes before sleep (D76, #144): the schedule starts at 10 pm.
    #expect(fakes.windows == [[TimeWindow(start: time(22), end: time(7))]])
    #expect(setup.effects.places == [homePlace])
    coordinator.run(
      .arrived, [.presence(homePlace.id, Presence(isInside: true, at: date(2026, 11, 17, 23)))],
      clock: FixedClock(now: date(2026, 11, 17, 23)))
    #expect(fakes.shields.last?.selections == [Data([1])])
    #expect(store.load().isBlocking)
    coordinator.run(.windowEnd, clock: FixedClock(now: date(2026, 11, 18, 7)))
    #expect(fakes.shields.last?.isOff == true)
    #expect(fakes.lines.map(\.cause) == [.edit, .arrived, .windowEnd])
  }

  @Test func refusedCommandsStillReconcile() {
    let (coordinator, fakes, _) = make()
    let outcome = coordinator.run(
      .doorChosen, [.startDoor], clock: FixedClock(now: date(2026, 11, 17, 15)))
    #expect(outcome.error == .door(.notBlocked))
    #expect(fakes.shields.count == 1)
  }

  @Test func aFailedScheduleIsTriedAgainNextTime() {
    let (coordinator, fakes, store) = make()
    fakes.failWindows = true
    coordinator.run(
      .edit,
      [.finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 17, 15))],
      clock: FixedClock(now: date(2026, 11, 17, 15)))
    #expect(store.load().runtime.scheduledWindows == nil)
    fakes.failWindows = false
    coordinator.run(.launch, clock: FixedClock(now: date(2026, 11, 17, 16)))
    #expect(fakes.windows == [[TimeWindow(start: time(22), end: time(7))]])
  }

  @Test func theDoorScheduleStartsAndStops() {
    let (coordinator, fakes, _) = make()
    coordinator.run(
      .edit,
      [
        .finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 17, 15)),
        .presence(homePlace.id, Presence(isInside: true, at: date(2026, 11, 17, 23))),
      ], clock: FixedClock(now: date(2026, 11, 17, 23)))
    coordinator.run(
      .doorChosen, [.startDoor], clock: FixedClock(now: date(2026, 11, 17, 23)))
    coordinator.run(
      .doorCancelled, [.cancelDoor], clock: FixedClock(now: date(2026, 11, 17, 23, 0, 30)))
    #expect(fakes.doors == ["start", "stop"])
  }
}
