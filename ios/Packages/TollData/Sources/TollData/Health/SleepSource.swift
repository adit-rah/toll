import Foundation
@preconcurrency import HealthKit
import TollCore

/// Apple Health's sleep, read-only (#144). App only: the extensions never link HealthKit. Dusk asks
/// to read `sleepAnalysis` and nothing else, never writes to Health, and keeps what it reads on the
/// phone: the usual times become the night's hours, and each night's sleep goes into the night log.
@MainActor
public final class SleepSource {
  #if DEBUG
    /// Demo launches stand in for Health: the simulator has no one's nights.
    public static var simulated: [SleepSample]?
  #endif

  private let store = HKHealthStore()
  private static let sleep = HKCategoryType(.sleepAnalysis)

  public init() {}

  /// Health exists on this device. iPad and Mac may have none.
  public var available: Bool {
    #if DEBUG
      if Self.simulated != nil { return true }
    #endif
    return HKHealthStore.isHealthDataAvailable()
  }

  /// iOS's sheet, once: read sleep only. It never says whether reading was refused; a refusal looks
  /// like no nights, so Dusk asks the person instead.
  public func requestRead() async {
    #if DEBUG
      if Self.simulated != nil { return }
    #endif
    guard available else { return }
    try? await store.requestAuthorization(toShare: [], read: [Self.sleep])
  }

  /// Every sleep sample that starts in the range, mapped to TollCore's values. Nothing on error.
  public func samples(from start: Date, to end: Date) async -> [SleepSample] {
    #if DEBUG
      if let simulated = Self.simulated {
        return simulated.filter { $0.start >= start && $0.start < end }
      }
    #endif
    guard available else { return [] }
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
    let query = HKSampleQueryDescriptor(
      predicates: [.categorySample(type: Self.sleep, predicate: predicate)],
      sortDescriptors: [SortDescriptor(\.startDate)])
    let found = (try? await query.result(for: store)) ?? []
    return found.compactMap(Self.sample)
  }

  /// The nights of the last `health.lookbackDays`, one source each (`SleepNight.from`).
  public func nights(now: Date, calendar: Calendar, config: TollConfig = .defaults) async
    -> [SleepNight]
  {
    let days = max(config.health.lookbackDays, config.health.correctDays) + 1
    guard let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))
    else { return [] }
    let samples = await samples(from: start, to: now)
    return SleepNight.from(samples, calendar: calendar, config: config)
  }

  nonisolated static func sample(_ sample: HKCategorySample) -> SleepSample? {
    guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }
    let kind: SleepSample.Kind
    switch value {
    case .inBed: kind = .inBed
    case .awake: kind = .awake
    case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: kind = .asleep
    @unknown default: return nil
    }
    let revision = sample.sourceRevision
    let product = revision.productType ?? ""
    let source: SleepSample.Source =
      product.hasPrefix("Watch") ? .watch : product.hasPrefix("iPhone") ? .phone : .other
    return SleepSample(
      start: sample.startDate, end: sample.endDate, kind: kind, source: source,
      sourceID: revision.source.bundleIdentifier)
  }
}
