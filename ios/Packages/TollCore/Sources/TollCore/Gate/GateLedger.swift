import Foundation

/// Today's gate facts, derived from the day's events. Everything the gate decides comes from here.
public struct GateLedger: Equatable, Sendable {
  public var freePasses = 0
  public var waitedPasses = 0
  public var passesByApp: [AppRef: Int] = [:]

  public init() {}

  public init(eventsOfToday events: [GateEvent]) {
    for event in events where event.kind == .pass {
      if event.free == true { freePasses += 1 } else { waitedPasses += 1 }
      let refs = event.appRefs ?? (event.appRef.map { [$0] } ?? [])
      for ref in refs { passesByApp[ref, default: 0] += 1 }
    }
  }

  public var passes: Int { freePasses + waitedPasses }
}

/// What opening Toll from a shield does (G-3, G-5).
public enum GateEntry: Equatable, Sendable {
  case freePass
  case startWait(minutes: Int, number: Int)
  case joinWait
}

public enum GateRules {
  public static func entry(ledger: GateLedger, runningWait: Wait?, config: TollConfig.Gate)
    -> GateEntry
  {
    if runningWait != nil { return .joinWait }
    if ledger.freePasses < config.freePassesPerDay { return .freePass }
    return .startWait(
      minutes: waitMinutes(afterWaitedPasses: ledger.waitedPasses, config: config),
      number: ledger.waitedPasses + 1)
  }

  /// `gate.waits[n]` where n is waited passes already taken today, capped at the last value (G-4).
  public static func waitMinutes(afterWaitedPasses count: Int, config: TollConfig.Gate) -> Int {
    guard let last = config.waits.last else { return 0 }
    return count < config.waits.count ? config.waits[max(0, count)] : last
  }

  /// "Wait 3 of today · next wait 8 min" (spec §10).
  public static func nextWaitMinutes(forWaitNumber number: Int, config: TollConfig.Gate) -> Int {
    waitMinutes(afterWaitedPasses: number, config: config)
  }

  /// A block hit is held when neither a wait start nor a free pass follows within the resume window.
  public static func isHeld(hit: GateEvent, following events: [GateEvent], window: TimeInterval)
    -> Bool
  {
    let deadline = hit.occurredAt.addingTimeInterval(window)
    return !events.contains { event in
      guard event.occurredAt >= hit.occurredAt, event.occurredAt <= deadline else { return false }
      return event.kind == .waitStarted || (event.kind == .pass && event.free == true)
    }
  }
}
