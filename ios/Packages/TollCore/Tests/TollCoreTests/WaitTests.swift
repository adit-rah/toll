import Foundation
import Testing

@testable import TollCore

struct WaitTests {
  let start = Date(timeIntervalSince1970: 1_800_000_000)
  let boot = MonotonicInstant(bootID: "boot-1", seconds: 1_000)

  func wait() -> Wait {
    Wait(appRef: "a", number: 1, minutes: 3, startedAt: start, startedMonotonic: boot)
  }

  func mono(_ elapsed: Double, boot id: String = "boot-1") -> MonotonicInstant {
    MonotonicInstant(bootID: id, seconds: 1_000 + elapsed)
  }

  @Test func remainingFollowsTheClockWhenClocksAgree() {
    let remaining = wait().remaining(
      now: start.addingTimeInterval(60), monotonic: mono(61), tolerance: 60)
    #expect(remaining == 120)
  }

  @Test func clockMovedBackDoesNotLengthenOrShortenBeyondRealTime() {
    let remaining = wait().remaining(
      now: start.addingTimeInterval(-3600), monotonic: mono(100), tolerance: 60)
    #expect(remaining == 80)
  }

  @Test func clockMovedForwardNeverShortensTheWait() {
    let w = wait()
    #expect(!w.isComplete(now: start.addingTimeInterval(3600), monotonic: mono(30), tolerance: 60))
    #expect(
      w.remaining(now: start.addingTimeInterval(3600), monotonic: mono(30), tolerance: 60) == 150)
  }

  @Test func afterARebootOnlyTheWallClockIsLeft() {
    let remaining = wait().remaining(
      now: start.addingTimeInterval(100), monotonic: mono(5, boot: "boot-2"), tolerance: 60)
    #expect(remaining == 80)
  }

  @Test func remainingNeverGoesNegative() {
    #expect(
      wait().remaining(now: start.addingTimeInterval(999), monotonic: mono(999), tolerance: 60) == 0
    )
    #expect(
      wait().isComplete(now: start.addingTimeInterval(180), monotonic: mono(180), tolerance: 60))
  }

  @Test func joiningAddsAnAppOnce() {
    var w = wait()
    w.join("b")
    w.join("b")
    w.join("a")
    #expect(w.appRefs == ["a", "b"])
    #expect(w.primaryApp == "a")
  }
}
