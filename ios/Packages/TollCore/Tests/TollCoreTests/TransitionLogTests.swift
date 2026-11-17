import Foundation
import Testing

@testable import TollCore

struct TransitionLogTests {
  func freshURL() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "log-\(UUID().uuidString).jsonl")
  }

  func line(_ minute: Int) -> Transition {
    Transition(
      at: date(2026, 11, 17, 22, minute), cause: .arrived, blockOn: true, changed: true, home: true,
      inWindow: true, entitled: true)
  }

  @Test func appendsAndReadsNewestFirst() {
    let log = TransitionLog(url: freshURL())
    log.append(line(1))
    log.append(line(2))
    #expect(log.read() == [line(2), line(1)])
  }

  @Test func trimKeepsTheNewest() {
    let log = TransitionLog(url: freshURL())
    for minute in 0..<(TransitionLog.maxLines % 60 + 5) { log.append(line(minute % 60)) }
    for _ in 0..<TransitionLog.maxLines { log.append(line(59)) }
    log.trim()
    #expect(log.read(limit: .max).count == TransitionLog.maxLines)
  }

  @Test func storeRoundTrips() {
    let store = SleepStore(url: freshURL())
    store.update { $0.settings.window = usual }
    #expect(store.load().settings.window == usual)
  }
}
