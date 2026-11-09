import Foundation

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Seconds since boot, counting sleep, tagged with the boot it belongs to. Only comparable within a boot.
public struct MonotonicInstant: Codable, Hashable, Sendable {
  public var bootID: String
  public var seconds: Double

  public init(bootID: String, seconds: Double) {
    self.bootID = bootID
    self.seconds = seconds
  }
}

/// All time enters through here so waits and days are testable and the monotonic guard (G-9) is possible.
public protocol TollClock: Sendable {
  var now: Date { get }
  var monotonic: MonotonicInstant? { get }
  var timeZone: TimeZone { get }
}

public struct SystemClock: TollClock {
  public init() {}

  public var now: Date { Date() }
  public var timeZone: TimeZone { .current }

  public var monotonic: MonotonicInstant? {
    guard let bootID = Self.bootID else { return nil }
    var spec = timespec()
    #if canImport(Darwin)
      // Darwin's CLOCK_MONOTONIC keeps counting while the phone sleeps, which a wait needs.
      guard clock_gettime(CLOCK_MONOTONIC, &spec) == 0 else { return nil }
    #else
      guard clock_gettime(CLOCK_BOOTTIME, &spec) == 0 else { return nil }
    #endif
    return MonotonicInstant(
      bootID: bootID, seconds: Double(spec.tv_sec) + Double(spec.tv_nsec) / 1e9)
  }

  private static let bootID: String? = {
    #if canImport(Darwin)
      var boot = timeval()
      var size = MemoryLayout<timeval>.size
      guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else { return nil }
      return "\(boot.tv_sec).\(boot.tv_usec)"
    #else
      return try? String(contentsOfFile: "/proc/sys/kernel/random/boot_id", encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    #endif
  }()
}
