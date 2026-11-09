import Foundation
import TollCore
import TollData
import TollUI

/// Turns server facts into the §10 lines. Kept in one place so Home, People and Friend detail agree.
enum FriendFormatting {
  static func passLine(_ pass: PassLine) -> String {
    let app = Copy.Tags.display(pass.tag)
    let time = Copy.clock(Date(millis: pass.at), offsetMinutes: pass.tzOffset)
    return pass.free ? Copy.FriendRows.free(app, at: time) : Copy.FriendRows.waited(app, at: time, minutes: pass.waitMinutes)
  }

  static func silentDay(_ text: String?) -> String? {
    text.flatMap(TollDay.init).map(Copy.weekdayName)
  }

  static func detail(_ friend: FriendSummary) -> String {
    if let day = silentDay(friend.silentSince) { return Copy.FriendRows.silent(since: day) }
    if let pass = friend.latestPass, friend.today.passes > 0 { return passLine(pass) }
    return Copy.FriendRows.clean
  }

  static func mark(_ friend: FriendSummary) -> StatusMark {
    friend.silentSince != nil ? .silent : StatusMark(level: friend.level)
  }

  static func statusSpeech(_ level: StatusLevel?, personalised: Bool = true) -> String? {
    level.map { Copy.Status.label($0, personalised: personalised) }
  }

  static func speech(_ friend: FriendSummary) -> FriendRow.Speech {
    if friend.silentSince != nil { return FriendRow.Speech(status: Copy.FriendRows.silentAccessibility) }
    let n = friend.today.passes
    return FriendRow.Speech(
      status: statusSpeech(friend.level), count: "\(n) \(Copy.passes(n)) today",
      trend: Copy.FriendRows.trendAccessibility(friend.week.trend))
  }

  static func trailing(_ friend: FriendSummary) -> FriendRow.Trailing {
    friend.silentSince != nil ? .silent : .count(friend.today.passes, trend: friend.week.trend.map(Trend.init(fraction:)))
  }

  static func pinned(_ pin: Pinned) -> String {
    let apps = Copy.Tags.list(pin.tags.map(Copy.Tags.display))
    switch pin.kind {
    case .removal: return Copy.Pins.removal(pin.user.displayName, apps: apps)
    case .loosened:
      return Copy.Pins.loosened(pin.user.displayName, apps: apps, schedule: pin.schedule.map(Copy.Schedules.inline) ?? "")
    case .silence:
      let day = Copy.weekdayName(TollDay(Date(millis: pin.since)))
      return Copy.Pins.silence(pin.user.displayName, since: day)
    }
  }

  static func photo(_ person: PersonRef) -> URL? { person.photoUrl.flatMap(URL.init(string:)) }
}

extension TollDay {
  init(_ date: Date) {
    let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
    self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
  }
}
