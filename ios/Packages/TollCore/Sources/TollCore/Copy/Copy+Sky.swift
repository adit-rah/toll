import Foundation

extension Copy {
  /// Your sky (D79). Facts only: how many nights and which shapes are there, never what's left or
  /// what comes next.
  public enum Sky {
    public static let title = "Your sky"

    /// "Your sky. 23 nights locked. 3 constellations: the Big Dipper, Cassiopeia, the Little
    /// Dipper." Before the first shape, just the nights, counted as Your sleep counts them; before
    /// the first night, the empty sky's line.
    public static func spoken(nights: Int, completed: [Constellation]) -> String {
      guard nights > 0 else { return "\(title). \(empty)" }
      let names = completed.map { inSentence($0) }.joined(separator: ", ")
      let shapes =
        completed.isEmpty
        ? ""
        : completed.count == 1
          ? " 1 constellation: \(names)." : " \(completed.count) constellations: \(names)."
      return "\(title). \(Copy.YourSleep.nights(nights)).\(shapes)"
    }

    /// Under an empty sky, before the first night the lock runs.
    public static let empty = "Your first star comes with your first locked night."

    /// A star's night, in its popover: "Mon 23 Nov".
    public static func night(_ night: Date, calendar: Calendar = .current) -> String {
      formatted(night, template: "EEEdMMM", calendar: calendar)
    }

    /// "Locked 10:15 pm – 7:00 am": when the lock came on and went off that night.
    public static func locked(_ from: String, _ until: String) -> String {
      "Locked \(from) – \(until)"
    }

    /// The shared picture's small date: "24 November 2026".
    public static func date(_ night: Date, calendar: Calendar = .current) -> String {
      formatted(night, template: "dMMMMyyyy", calendar: calendar)
    }

    private static func formatted(_ date: Date, template: String, calendar: Calendar) -> String {
      let locale = calendar.locale.flatMap { $0.identifier.isEmpty ? nil : $0 } ?? .current
      let formatter = DateFormatter()
      formatter.locale = locale
      formatter.calendar = calendar
      formatter.timeZone = calendar.timeZone
      formatter.setLocalizedDateFormatFromTemplate(template)
      return formatter.string(from: date)
    }

    /// A name as a star chart sets it beside its figure, without the article: "Big Dipper".
    public static func chartName(_ constellation: Constellation) -> String {
      let full = name(constellation)
      return full.hasPrefix("The ") ? String(full.dropFirst(4)) : full
    }

    /// A name inside a sentence: "the Big Dipper".
    static func inSentence(_ constellation: Constellation) -> String {
      let full = name(constellation)
      return full.hasPrefix("The ") ? "the " + full.dropFirst(4) : full
    }

    /// The wordmark at the foot of the shared picture.
    public static let wordmark = Copy.name

    /// The number in the shared picture, as the card says it: "30 nights locked".
    public static func number(_ nights: Int) -> String { Copy.YourSleep.nights(nights) }

    /// The landmark line's count: "30 nights".
    static func count(_ nights: Int) -> String { nights == 1 ? "1 night" : "\(nights) nights" }

    /// The morning card's landmark line: "30 nights. Orion is in your sky."
    public static func landmark(_ nights: Int, completed: Constellation?) -> String {
      guard let completed else { return "\(count(nights)) in your sky." }
      return "\(count(nights)). \(name(completed)) is in your sky."
    }

    public static let share = "Share"

    public static func name(_ constellation: Constellation) -> String {
      switch constellation {
      case .bigDipper: "The Big Dipper"
      case .cassiopeia: "Cassiopeia"
      case .littleDipper: "The Little Dipper"
      case .orion: "Orion"
      case .cygnus: "Cygnus"
      case .lyra: "Lyra"
      case .leo: "Leo"
      case .gemini: "Gemini"
      case .taurus: "Taurus"
      case .bootes: "Boötes"
      case .coronaBorealis: "Corona Borealis"
      case .hercules: "Hercules"
      case .aquila: "Aquila"
      case .pegasus: "Pegasus"
      case .andromeda: "Andromeda"
      case .perseus: "Perseus"
      case .auriga: "Auriga"
      case .cepheus: "Cepheus"
      case .delphinus: "Delphinus"
      case .canisMajor: "Canis Major"
      case .canisMinor: "Canis Minor"
      case .aries: "Aries"
      case .draco: "Draco"
      }
    }
  }
}
