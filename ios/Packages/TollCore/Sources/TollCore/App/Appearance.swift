import Foundation

/// The app's look, chosen in Settings: dark first, switchable (decisions D36). With "Dark in the
/// evening", Light and Match iPhone give way to dark from the hour Your sky's evening light starts
/// until its morning (`TollConfig.Sky`), so the brightest screens never meet a dark room.
public enum Appearance: String, CaseIterable, Sendable {
  case dark, light, system

  public enum Scheme: Sendable, Equatable {
    case dark, light
  }

  /// What the app asks for at `date`; nil follows the phone.
  public func scheme(
    at date: Date, darkInEvening: Bool, calendar: Calendar, config: TollConfig = .defaults
  ) -> Scheme? {
    if self == .dark
      || (darkInEvening && Self.isEvening(at: date, calendar: calendar, config: config))
    {
      return .dark
    }
    return self == .light ? .light : nil
  }

  /// From the evening light's hour until the morning's, on the phone's clock.
  public static func isEvening(at date: Date, calendar: Calendar, config: TollConfig = .defaults)
    -> Bool
  {
    let hour = calendar.component(.hour, from: date)
    let from = config.sky.eveningFromHour
    let until = config.sky.morningFromHour
    return from <= until ? (from..<until).contains(hour) : hour >= from || hour < until
  }

  /// The next moment the evening starts or ends after `date`, so an open app changes on time.
  public static func nextChange(
    after date: Date, calendar: Calendar, config: TollConfig = .defaults
  ) -> Date? {
    [config.sky.eveningFromHour, config.sky.morningFromHour]
      .compactMap {
        calendar.nextDate(
          after: date, matching: DateComponents(hour: $0, minute: 0, second: 0),
          matchingPolicy: .nextTime)
      }
      .min()
  }
}
