import Foundation
import Testing

@testable import TollCore

struct OutboxPlanTests {
  func event(_ seconds: TimeInterval, id: UUID = UUID()) -> GateEvent {
    GateEvent(
      id: id, kind: .pass, occurredAt: Date(timeIntervalSince1970: seconds), tzOffsetMinutes: 0)
  }

  @Test func deduplicatesAndOrdersOldestFirst() {
    let shared = UUID()
    let batches = OutboxPlan.batches([
      event(3), event(1, id: shared), event(2), event(1, id: shared),
    ])
    #expect(batches.count == 1)
    #expect(batches[0].map(\.occurredAt.timeIntervalSince1970) == [1, 2, 3])
  }

  @Test func splitsIntoServerSizedBatches() {
    let batches = OutboxPlan.batches((0..<250).map { event(Double($0)) })
    #expect(batches.map(\.count) == [100, 100, 50])
    #expect(OutboxPlan.batches([]).isEmpty)
  }

  @Test func backoffDoublesAndCaps() {
    #expect(OutboxPlan.backoff(afterFailures: 0) == 0)
    #expect(OutboxPlan.backoff(afterFailures: 1) == 5)
    #expect(OutboxPlan.backoff(afterFailures: 3) == 20)
    #expect(OutboxPlan.backoff(afterFailures: 30) == 3600)
    #expect(OutboxPlan.backoff(afterFailures: 1, jitter: 0.9) == 6.25)
  }

  @Test func rejectedForGoodCountsAsSettled() {
    #expect(OutboxPlan.settled(accepted: ["a"], rejected: [("b", "skew")]) == ["a", "b"])
  }
}
