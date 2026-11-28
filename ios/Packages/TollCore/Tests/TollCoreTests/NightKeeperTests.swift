import Foundation
import SleepModel
import Testing

@testable import TollCore

/// #140 risks 3 and 4: every night is recorded before the transition log is trimmed, the monitor
/// records it at its sweep, and every line says its own format and revision, with the model version
/// taken from the artifact.
struct NightKeeperTests {
  struct Files {
    let folder: URL
    var keeper: NightKeeper {
      NightKeeper(
        transitions: TransitionLog(url: folder.appending(path: "transitions.jsonl")),
        nights: NightLog(url: folder.appending(path: "nights.jsonl")))
    }

    init() {
      folder = FileManager.default.temporaryDirectory.appending(
        path: "nights-\(UUID().uuidString)", directoryHint: .isDirectory)
      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func log(_ lines: [Transition]) {
      for line in lines { keeper.transitions.append(line) }
    }
  }

  func line(_ at: Date, _ cause: ReconcileCause, on: Bool) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: on, changed: true, home: true, inWindow: on, entitled: true,
      active: on ? [BlockID("sleep")] : [])
  }

  /// Monday night, 10:30 pm to 7 am, with one "Never mind".
  var monday: [Transition] {
    [
      line(date(2026, 11, 16, 10), .foreground, on: false),
      line(date(2026, 11, 16, 22, 30), .windowStart, on: true),
      line(date(2026, 11, 16, 23, 10), .blockScreen, on: true),
      line(date(2026, 11, 17, 7), .windowEnd, on: false),
    ]
  }

  var state: DuskState {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 16, 9)
    return state
  }

  /// Tuesday's wakes, enough of them to push Monday out of the log's 2000 lines.
  func busyTuesday(_ count: Int) -> [Transition] {
    (0..<count).map {
      line(date(2026, 11, 17, 9).addingTimeInterval(Double($0)), .foreground, on: false)
    }
  }

  @Test func aNightIsRecordedBeforeTheTrimCanTakeIt() throws {
    let files = Files()
    files.log(monday + busyTuesday(TransitionLog.maxLines + 50))
    let added = files.keeper.keep(
      state, model: stamp, now: date(2026, 11, 17, 18), calendar: london)
    #expect(added == 1)
    let night = try #require(files.keeper.nights.past(calendar: london).first)
    #expect(night.ran)
    #expect(night.taps == [date(2026, 11, 16, 23, 10)])
    #expect(files.keeper.transitions.read(limit: .max).count == TransitionLog.maxLines)
  }

  @Test func theMonitorRecordsTheNightAtItsSweepAndTheAppDoesntAgain() throws {
    let files = Files()
    files.log(monday)
    let sweep = date(2026, 11, 17, 7, 1)
    #expect(files.keeper.keepRecent(state, model: stamp, now: sweep, calendar: london) == 1)
    #expect(files.keeper.keepRecent(state, model: stamp, now: sweep, calendar: london) == 0)
    #expect(
      files.keeper.keep(state, model: stamp, now: date(2026, 11, 17, 9), calendar: london) == 0)
    let lines = files.keeper.nights.lines()
    #expect(lines.count == 1)
    let record = try #require(try JSONSerialization.jsonObject(with: lines[0]) as? [String: Any])
    #expect((record["dusk"] as? [String: Any])?["by"] as? String == "monitor")
  }

  /// A busy evening fills the end of the log: the monitor reads only that end, and leaves a night
  /// it can't see from noon to the app, which reads the whole log.
  @Test func theMonitorLeavesANightItCantSeeWhole() throws {
    let files = Files()
    let evening = (0..<700).map {
      line(date(2026, 11, 16, 13).addingTimeInterval(Double($0 * 10)), .foreground, on: false)
    }
    files.log(Array(monday.prefix(1)) + evening + monday.dropFirst())
    let sweep = date(2026, 11, 17, 7, 1)
    #expect(files.keeper.keepRecent(state, model: stamp, now: sweep, calendar: london) == 0)
    #expect(files.keeper.keep(state, model: stamp, now: sweep, calendar: london) == 1)
  }

  @Test func eachLineSaysItsFormatRevisionAndTheArtifactsVersion() throws {
    let facts = try #require(
      NightFacts.ended(
        log: monday, sleep: sleepBlock(), since: state.setupFinishedAt, now: date(2026, 11, 17, 9),
        calendar: london
      ).first)
    let data = try #require(NightRecordLine.encode(facts, calendar: london, model: stamp))
    let record = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(record["record"] as? Int == NightRecordLine.format)
    #expect(record["rev"] as? Int == 1)
    #expect(record["model_version"] as? String == ModelArtifact.bundled().version)
    #expect(try JSONDecoder().decode(NightRecord.self, from: data).modelVersion == stamp.version)
  }

  /// The monitor never links the model: it stamps its lines with the version `sync-model.sh` wrote
  /// from the artifact, which can't be a stale `model.json`.
  @Test func theMonitorStampsWithTheArtifactThisBuildCarries() {
    #expect(BundledModel.version == ModelArtifact.bundled().version)
    #expect(ModelStamp.fixed(BundledModel.version) == stamp)
  }

  /// A night that can't be written keeps the log untrimmed, so the next opening tries again.
  @Test func aNightThatCantBeWrittenKeepsTheLog() throws {
    let files = Files()
    let blocked = files.folder.appending(path: "nights.jsonl")
    try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
    files.log(monday + busyTuesday(TransitionLog.maxLines + 50))
    #expect(
      files.keeper.keep(state, model: stamp, now: date(2026, 11, 17, 18), calendar: london) == nil)
    #expect(files.keeper.transitions.read(limit: .max).count == TransitionLog.maxLines + 54)
  }

  /// Every shape the night log has had (D62, D83's gap, D84's hours, D85's helper, #140's record
  /// and rev, #144's buffer after and Health's correction, #145's pauses by buffer, #155's held
  /// start), with two copies of one night and corrections: one night each, the highest revision.
  @Test func everyPastShapeReadsAndTheHighestRevisionWins() throws {
    let url = try #require(
      Bundle.module.url(
        forResource: "past", withExtension: "jsonl", subdirectory: "Fixtures/nights"))
    let log = NightLog(url: url)
    let current = log.current()
    #expect(current.count == 8)
    let records = try current.map { try JSONDecoder().decode(NightRecord.self, from: $0) }
    #expect(
      records.map(\.night) == [
        "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13", "2026-11-14", "2026-11-15",
        "2026-11-16", "2026-11-17",
      ])
    #expect(records.dropLast().allSatisfy { $0.policy == "fixed" && $0.hold == nil })
    #expect(records[7].hold == Hold(start: "2026-11-17", offset: -30, prob: 0.3492, settled: false))
    #expect(records[7].blockStart == "2026-11-17T21:30:00Z")
    #expect(records[2].sleepOnset == "2026-11-12T23:20:00Z")
    #expect(records[5].sleepSource == "watch")
    #expect(records[5].rev == 2)
    #expect(records[3].helper == "breathe")
    let shared = try #require(try JSONSerialization.jsonObject(with: current[4]) as? [String: Any])
    #expect((shared["dusk"] as? [String: Any])?["by"] as? String == "monitor")
    let past = log.past(calendar: london)
    #expect(past.count == 8)
    #expect(past.allSatisfy { $0.ran })
    #expect(past[2].taps == [date(2026, 11, 12, 23, 5)])
  }
}
