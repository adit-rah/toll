import Foundation

extension Copy {
  /// Apple's count of screen time after bed, in its own row (#65). The number is Apple's, drawn by
  /// the report; the row's words are Dusk's.
  public enum AfterBed {
    public static let title = "Screen time after bed"
    public static let caption = "Last night, from Screen Time"
    public static let spoken = "Screen time after bed, last night, from Screen Time"
    /// The number for VoiceOver: "1 hour 12 minutes", never "1 h 12 m".
    public static func minutes(_ minutes: Int) -> String {
      let hours = minutes / 60
      let rest = minutes % 60
      let parts = [
        hours > 0 ? (hours == 1 ? "1 hour" : "\(hours) hours") : nil,
        rest > 0 || hours == 0 ? (rest == 1 ? "1 minute" : "\(rest) minutes") : nil,
      ]
      return parts.compactMap { $0 }.joined(separator: " ")
    }
  }
}
