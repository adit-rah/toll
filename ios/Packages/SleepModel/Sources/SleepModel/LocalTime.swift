/// An ISO 8601 time with its offset, as whole microseconds since 1970 UTC. Differences are exact,
/// as Python's `datetime` subtraction is, so onsets match the reference to the last bit.
struct LocalTime: Equatable {
  let micros: Int64

  /// "2026-01-05T23:12:34", optional ".ffffff", then "Z" or "±HH:MM".
  init?(_ text: String) {
    let c = Array(text.utf8)
    func number(_ from: Int, _ count: Int) -> Int? {
      guard from + count <= c.count else { return nil }
      var v = 0
      for byte in c[from..<from + count] {
        guard byte >= 48, byte <= 57 else { return nil }
        v = v * 10 + Int(byte - 48)
      }
      return v
    }
    guard c.count >= 19, c[4] == 45, c[7] == 45, c[10] == 84, c[13] == 58, c[16] == 58,
      let year = number(0, 4), let month = number(5, 2), let day = number(8, 2),
      let hour = number(11, 2), let minute = number(14, 2), let second = number(17, 2)
    else { return nil }
    var i = 19
    var fraction = 0
    if i < c.count, c[i] == 46 {
      var digits = 0
      i += 1
      while i < c.count, c[i] >= 48, c[i] <= 57 {
        if digits < 6 { fraction = fraction * 10 + Int(c[i] - 48) }
        digits += 1
        i += 1
      }
      for _ in digits..<max(digits, 6) { fraction *= 10 }
    }
    var offsetMinutes = 0
    if i < c.count, c[i] == 90 {
      i += 1
    } else if i + 6 == c.count, c[i] == 43 || c[i] == 45, c[i + 3] == 58,
      let oh = number(i + 1, 2), let om = number(i + 4, 2)
    {
      offsetMinutes = (c[i] == 45 ? -1 : 1) * (oh * 60 + om)
      i += 6
    }
    guard i == c.count else { return nil }
    let days = Self.daysFromCivil(year, month, day)
    let seconds = days * 86_400 + hour * 3_600 + minute * 60 + second - offsetMinutes * 60
    micros = Int64(seconds) * 1_000_000 + Int64(fraction)
  }

  /// Minutes from `earlier` to this time, rounded once, as Python's `total_seconds() / 60`.
  func minutes(since earlier: LocalTime) -> Double {
    Double(micros - earlier.micros) / 1_000_000 / 60
  }

  /// Howard Hinnant's days_from_civil.
  private static func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
    let y = m <= 2 ? y0 - 1 : y0
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
  }
}
