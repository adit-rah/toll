import Foundation

/// Every user-facing line (spec §10, plus the lines `toll-user-flows.md` names). A fact, a number, or a
/// question; no adjectives about the user; the same line whether the numbers are good or bad.
public enum Copy {
  public static let middleDot = " · "

  public static func passes(_ n: Int) -> String { n == 1 ? "pass" : "passes" }
  public static func minutes(_ n: Int) -> String { "\(n) min" }

  public enum Tags {
    public static func display(_ tag: Tag?) -> String {
      switch tag {
      case .instagram: "Instagram"
      case .tiktok: "TikTok"
      case .youtube: "YouTube"
      case .snapchat: "Snapchat"
      case .x: "X"
      case .reddit: "Reddit"
      case .other, nil: "a blocked app"
      }
    }

    /// The chip label; "Other" here, "a blocked app" in sentences.
    public static func chip(_ tag: Tag) -> String { tag == .other ? "Other" : display(tag) }

    public static func list(_ names: [String]) -> String {
      switch names.count {
      case 0: return display(nil)
      case 1: return names[0]
      case 2: return "\(names[0]) and \(names[1])"
      default: return names.dropLast().joined(separator: ", ") + ", and " + (names.last ?? "")
      }
    }
  }

  public enum Shield {
    public static func title(_ app: String) -> String { "\(app) is blocked." }
    public static func unblocked(_ n: Int) -> String {
      "You've unblocked this \(n) \(n == 1 ? "time" : "times") today."
    }
    public static let openToll = "Open Toll"
    public static let dismiss = "Dismiss"
    public static let openFromHomeScreen = "Open Toll from your home screen."
    public static let fallbackApp = "This app"
    public static let notificationTitle = "Open Toll"
  }

  public enum Home {
    public static let tab = "Home"
    public static func passesToday(_ n: Int) -> String { "\(passes(n)) today" }
    public static func week(_ this: Int, last: Int) -> String {
      "\(this) this week\(middleDot)\(last) last week"
    }
    public static func tollOpens(_ n: Int) -> String {
      "You opened Toll \(n) \(n == 1 ? "time" : "times") today."
    }
    /// Follows the system app name, which Toll cannot read as text.
    public static func sessionActiveRest(minutesLeft: Int) -> String {
      "is open\(middleDot)\(minutesLeft) min left"
    }
    public static func sessionActive(_ app: String, minutesLeft: Int) -> String {
      "\(app) \(sessionActiveRest(minutesLeft: minutesLeft))"
    }
    public static let screenTimeOff = "Screen Time is off"
    public static let blocksNeedRepicking = "Blocks need re-picking"
    public static let nothingBlocked = "Nothing blocked yet"
    public static let fix = "Fix"
    public static let addApps = "Add apps"
    public static let friendsHeader = "Friends"
    public static func friendsHeldShort(_ percent: Int) -> String { "held \(percent)% this week" }
    public static func friendsHeld(_ percent: Int) -> String {
      "Your friends held \(percent)% of gates this week."
    }
    public static let noFriends = "No friends yet."
    public static let sendInvite = "Send an invite"
    public static func lastSynced(_ relative: String) -> String { "Updated \(relative)" }
  }

  public enum Wait {
    public static func line(number: Int, nextMinutes: Int) -> String {
      "Wait \(number) of today\(middleDot)next wait \(nextMinutes) min"
    }
    public static let cancel = "Cancel"
    public static let namingQuestion = "Which app is this?"
    public static let namingNote = "Friends see the name. Change it any time from Blocks."
    public static func remainingAccessibility(minutes: Int, seconds: Int) -> String {
      "\(minutes) minutes \(seconds) seconds left"
    }
  }

  public enum SessionPicker {
    public static let question = "How long?"
    public static func open(_ app: String) -> String { "Open \(app)" }
    /// The button reads "Open" followed by the system's own app name, which Toll cannot read as text.
    public static let openVerb = "Open"
    public static let note = "From now. The block returns after."
    public static func unblock(minutes: Int) -> String { "Unblock for \(minutes) min" }
    public static let notNow = "Not now"
  }

  /// A block's row and its actions inside Toll.
  public enum ActiveBlock {
    public static let unblock = "Unblock"
    public static let blockAgain = "Block again"
    public static let always = "Always"
    public static let open = "Open"
    public static let passReady = "Pass ready"
    public static func left(seconds: Int) -> String {
      let s = max(0, seconds)
      return String(format: "%d:%02d left", s / 60, s % 60)
    }
    public static func until(_ time: ClockTime) -> String { "Until \(Schedules.time(time))" }
    public static func starts(_ time: ClockTime) -> String { "Starts \(Schedules.time(time))" }
    public static func blocksOn(_ n: Int) -> String { "\(n) \(n == 1 ? "block" : "blocks") on" }
  }

  public enum Schedules {
    public static func label(_ schedule: Schedule) -> String {
      switch schedule.kind {
      case .always: "Always"
      case .nights: "Nights\(middleDot)\(window(schedule))"
      case .weekdays: "Weekdays\(middleDot)\(window(schedule))"
      case .custom: "Custom\(middleDot)\(window(schedule))"
      }
    }

    /// Lower-case form used inside sentences: "Adi's Instagram block is now nights only."
    public static func inline(_ schedule: Schedule) -> String {
      switch schedule.kind {
      case .always: "always on"
      case .nights: "nights"
      case .weekdays: "weekdays"
      case .custom: window(schedule)
      }
    }

    public static func window(_ schedule: Schedule) -> String {
      "\(time(schedule.start)) – \(time(schedule.end))"
    }

    public static func time(_ t: ClockTime) -> String {
      let hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12
      let suffix = t.hour < 12 ? "am" : "pm"
      return t.minute == 0
        ? "\(hour12) \(suffix)" : String(format: "%d:%02d %@", hour12, t.minute, suffix)
    }

    public static let alwaysTile = ("Always", "every day")
    public static let nightsTile = ("Nights", "11 pm – 7 am")
    public static let weekdaysTile = ("Weekdays", "9 am – 5 pm")
    public static let customTile = ("Custom", "pick times")
    public static let when = "When"
    public static let custom = "Custom"
    public static let from = "From"
    public static let until = "Until"
  }

  public enum Welcome {
    public static let name = "Toll"
    public static let apple = "Continue with Apple"
    public static let email = "Continue with email"
    public static let solo = "Continue without an account"
    public static let legalPrefix = "By continuing you confirm you're 16 or older and agree to the "
    public static let terms = "Terms"
    public static let and = " and "
    public static let privacy = "Privacy Policy"
    public static let legalSuffix = "."
  }

  public enum Email {
    public static let title = "What's your email?"
    public static let field = "Email"
    public static let send = "Send code"
    public static let note = "A 6-digit code, no password."
    public static let invalid = "That doesn't look like an email"
  }

  public enum Code {
    public static let title = "Enter the code"
    public static func sentTo(_ email: String) -> String { "Sent to \(email)" }
    public static let resend = "Resend code"
    public static let wrong = "Wrong code"
    public static let expired = "Code expired"
    public static func locked(until time: String) -> String {
      "Too many tries. Try again at \(time)."
    }
    public static func resendIn(_ seconds: Int) -> String { "Resend code in \(seconds) s" }
  }

  public enum You {
    public static let title = "You"
    public static let name = "Name"
    public static let handle = "Handle"
    public static let note = "Friends find you by handle. Both can be changed in Settings."
    public static let available = "available"
    public static let taken = "taken"
    public static let invalidHandle = "letters, numbers, _"
    public static let addPhoto = "Add photo"
    public static let `continue` = "Continue"
  }

  public enum Permissions {
    public static let title = "Toll needs two things"
    public static let screenTime = "Screen Time"
    public static let notifications = "Notifications"
    public static let screenTimeDetail =
      "The next screen is Apple's. It lets Toll block apps on this phone."
    public static let notificationsDetail = "This is how the block screen reaches Toll."
    public static let allow = "Allow"
    public static let denied = "Denied"
    public static let allowed = "Allowed"
    public static let deniedLine = "Toll can't block anything without Screen Time."
    public static let tryAgain = "Try again"
  }

  public enum BlockEditor {
    public static let setupTitle = "Block these"
    public static let returningTitle = "Block these again"
    public static let newTitle = "New block"
    public static let chooseApps = "Choose apps"
    public static let chooseMore = "Choose more"
    public static func more(_ n: Int) -> String { "+\(n) more" }
    public static let tagNote = "Names on the right are what friends see. Tap to change."
    public static let blockName = "Block name"
    public static let blockNameNote = "Optional. Only you see it."
    public static let done = "Done"
    public static let addAnother = "Add another block"
    public static func compactSummary(_ count: Int, schedules: String) -> String {
      "\(count) blocks\(middleDot)\(schedules)"
    }
    public static let limit = "40 apps is the most this phone allows."
    public static let discardTitle = "Discard changes?"
    public static let discard = "Discard"
    public static let keepEditing = "Keep editing"
  }

  public enum Blocks {
    public static let title = "Blocks"
    public static let header = "Removing a block is shown to your friends."
    public static let add = "Add a block"
    public static func removeConfirm(_ app: String) -> String {
      "Remove \(app)? Your friends will see this."
    }
    public static let remove = "Remove"
    public static let keep = "Keep"
  }

  public enum Friends {
    public static let title = "Find your friends"
    public static let inviteCode = "Invite code"
    public static let paste = "Paste"
    public static let contacts = "Contacts"
    public static let findContacts = "Find friends from contacts"
    public static let contactsDenied = "Allowed in Settings"
    public static let school = "School"
    public static let schoolEmail = "School email"
    public static let done = "Done"
    public static let skip = "Skip"
    public static let noSuchCode = "No one has that code"
    public static let notASchool = "Not a school email we know"
    public static let tellUs = "Tell us"
    public static func requestSent(to name: String) -> String { "\(name)\(middleDot)request sent" }
  }

  /// "11:40 p.m." — clock times inside sentences (spec §10).
  public static func clock(_ date: Date, offsetMinutes: Int) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: offsetMinutes * 60) ?? .gmt
    let c = calendar.dateComponents([.hour, .minute], from: date)
    let hour = c.hour ?? 0
    let hour12 = hour % 12 == 0 ? 12 : hour % 12
    return String(format: "%d:%02d %@", hour12, c.minute ?? 0, hour < 12 ? "a.m." : "p.m.")
  }

  public static func weekdayName(_ day: TollDay) -> String {
    ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day.weekday.rawValue - 1]
  }

  public static func percent(_ n: Int) -> String { "\(n)%" }

  public enum FriendRows {
    public static func waited(_ app: String, at time: String, minutes: Int) -> String {
      "Opened \(app) at \(time) after a \(minutes)-minute wait"
    }
    public static func free(_ app: String, at time: String) -> String { "Opened \(app) at \(time) (free pass)" }
    public static let clean = "0 passes today"
    public static func silent(since day: String) -> String { "Toll has been off since \(day)" }
    public static func mutual(via name: String, others: Int) -> String {
      switch others {
      case ...0: "friends with \(name)"
      case 1: "friends with \(name) and 1 other"
      default: "friends with \(name) and \(others) others"
      }
    }
    public static func trend(_ trend: Double?) -> String? {
      guard let trend else { return nil }
      let percent = Int((abs(trend) * 100).rounded())
      return trend <= 0 ? "▼ \(percent)%" : "▲ \(percent)%"
    }
    public static func trendAccessibility(_ trend: Double?) -> String? {
      guard let trend else { return nil }
      let percent = Int((abs(trend) * 100).rounded())
      return trend <= 0 ? "down \(percent) percent on last week" : "up \(percent) percent on last week"
    }
    public static func accessibility(name: String, level: String?, passes n: Int, trend: Double?) -> String {
      [name, level, "\(n) \(passes(n)) today", trendAccessibility(trend)].compactMap { $0 }.joined(separator: ", ")
    }
    public static let silentAccessibility = "Toll is off"
  }

  public enum Pins {
    public static func removal(_ name: String, apps: String) -> String { "\(name) removed \(apps) from their blocklist." }
    public static func loosened(_ name: String, apps: String, schedule: String) -> String {
      "\(name)'s \(apps) block is now \(schedule) only."
    }
    public static func silence(_ name: String, since day: String) -> String {
      "Toll has been off on \(name)'s phone since \(day)."
    }
  }

  public enum Status {
    public static func label(_ level: StatusLevel, personalised: Bool) -> String {
      if personalised {
        switch level {
        case .fewer: return "fewer than usual"
        case .usual: return "about usual"
        case .more: return "more than usual"
        }
      }
      switch level {
      case .fewer: return "0 to 2 passes"
      case .usual: return "3 to 4 passes"
      case .more: return "5 or more passes"
      }
    }
  }

  public enum FriendDetail {
    public static func since(handle: String, date: String) -> String { "@\(handle)\(middleDot)friends since \(date)" }
    public static let thisWeek = "This week"
    public static let held = "Held"
    public static let waited = "Waited"
    public static let cleanDays = "Clean days"
    public static func lastWeek(_ value: String) -> String { "\(value) last week" }
    public static let today = "Today"
    public static let yesterday = "Yesterday"
    public static let noPasses = "No passes"
    public static let blocks = "Blocks"
    public static let remove = "Remove friend"
    public static let block = "Block"
    public static let report = "Report"
    public static func removeConfirm(_ name: String) -> String { "Remove \(name)?" }
    public static func blockConfirm(_ name: String) -> String { "Block \(name)? You won't see each other anywhere." }
    public static let cancel = "Cancel"
  }

  public enum Report {
    public static let title = "Report"
    public static func reason(_ raw: String) -> String {
      switch raw {
      case "name": "Name"
      case "photo": "Photo"
      case "harassment": "Harassment"
      default: "Other"
      }
    }
    public static let details = "Details (optional)"
    public static let send = "Send"
    public static let thanks = "Sent. The founders read every report."
    public static let alsoBlock = "Also block this person?"
    public static let notNow = "Not now"
  }

  public enum People {
    public static let title = "People"
    public static let requests = "Requests"
    public static let friends = "Friends"
    public static let mutuals = "Mutuals"
    public static let contacts = "In your contacts"
    public static let school = "School"
    public static let invite = "Invite"
    public static let accept = "Accept"
    public static let decline = "Decline"
    public static let add = "Add"
    public static let requested = "Requested"
    public static func requestVia(_ name: String) -> String { "friends with \(name)" }
    public static func schoolLine(members: Int, heldPercent: Int?) -> String {
      let base = "\(members) \(members == 1 ? "person" : "people")"
      return heldPercent.map { "\(base)\(middleDot)held \($0)% this week" } ?? base
    }
    public static func findAtSchool(_ school: String) -> String { "Find people at \(school)" }
    public static let addSchool = "Add your school"
    public static let signInToAdd = "Sign in to add friends"
    public static func signInToAddName(_ name: String) -> String { "Sign in to add \(name)" }
    public static let signIn = "Sign in"
    public static let shareInvite = "Share invite link"
    public static let schoolBelowMinimum = "Not enough people at your school yet."
  }

  public enum Invite {
    public static let yourCode = "Your code"
    public static let share = "Share link"
    public static let caption = "Friends who install from this link are added when they accept."
    public static func message(_ url: String) -> String { "Join me on Toll: \(url)" }
  }

  public enum Settings {
    public static let title = "Settings"
    public static let account = "Account"
    public static let edit = "Edit"
    public static let save = "Save"
    public static let signOut = "Sign out"
    public static let signOutConfirm = "Sign out? Blocks stay on this phone."
    public static let signIn = "Sign in"
    public static let school = "School"
    public static let leave = "Leave"
    public static func leaveConfirm(_ school: String) -> String { "Leave \(school)?" }
    public static let notifications = "Notifications"
    public static let dailySummary = "One summary a day"
    public static let time = "Time"
    public static let discoverability = "Discoverability"
    public static let letContactsFind = "Let contacts find me"
    public static let blockedApps = "Blocked apps"
    public static let blockedPeople = "Blocked people"
    public static let unblock = "Unblock"
    public static let data = "Data"
    public static let export = "Export my data"
    public static let delete = "Delete account"
    public static let deleteConfirm = "Are you sure? Friends, history, everything."
    public static let `continue` = "Continue"
    public static let about = "About"
    public static let privacy = "Privacy Policy"
    public static let terms = "Terms"
    public static let support = "Support"
    public static let version = "Version"
    public static let supportToll = "Support Toll"
    public static let donate = "Donate"
    public static let historyQuestion = "Merge this phone's history into your account?"
    public static let historyYes = "Yes"
    public static let historyNo = "No, keep it on this phone"
    public static let historyUploaded = "This phone's history is now in your account."
    public static let checkEmailToDelete = "Enter the code we sent to confirm."
  }

  public enum Insights {
    public static let title = "Insights"
    public static let me = "Me"
    public static let friends = "Friends"
    public static let school = "School"
    public static let thisWeekVsLast = "This week vs last"
    public static let dayByDay = "Day by day"
    public static let byHour = "Passes by hour"
    public static let weekdays = "Weekday pattern"
    public static let byApp = "By app"
    public static let gates = "Gates"
    public static let eightWeeks = "Eight weeks"
    public static let term = "Term"
    public static let examWeeks = "Exam weeks"
    public static let distribution = "This week"
    public static let heldByFriend = "Gates held"
    public static let whenFriendsReach = "When your friends reach"
    public static let weekOnWeek = "Week on week"
    public static let schoolVsYou = "School vs you"
    public static let schoolByHour = "School by hour"
    public static let whatSchoolBlocks = "What the school blocks"
    public static let week = "Week"
    public static let eightWeeksToggle = "8 weeks"
    public static let hits = "Block hits"
    public static let heldLabel = "Held"
    public static let abandoned = "Abandoned waits"
    public static let waitMinutes = "Wait minutes"
    public static let cleanDays = "Clean days"
    public static let tollOpens = "Toll opens"
    public static let markExamWeek = "Exam week"
    public static func lateShare(_ percent: Int, after hour: String) -> String {
      "\(percent)% of your passes are after \(hour)."
    }
    public static func weekdayRange(high: String, low: String) -> String {
      "Most passes on \(high), fewest on \(low)."
    }
    public static func appCost(_ app: String, minutes: Int) -> String {
      "\(app) cost you \(minutes) minutes of waiting this week."
    }
    public static func walkedAway(_ percent: Int) -> String { "You walked away from \(percent)% of gates this week." }
    public static func examComparison(exam: Int, other: Int) -> String {
      "Exam weeks: \(exam) passes/week. Other weeks: \(other)."
    }
    public static func friendsUnder(_ count: Int, of total: Int, under limit: Int) -> String {
      "You and \(count) of \(total) friends had under \(limit) passes this week."
    }
    public static func peakHour(_ hour: String) -> String { "Your friends reach most around \(hour)." }
    public static func friendsChange(_ points: Int) -> String {
      points >= 0 ? "Up \(points) points on last week." : "Down \(-points) points on last week."
    }
    public static func sameApp(_ count: Int, app: String, after hour: String) -> String {
      "\(count) of your friends opened \(app) after \(hour) this week."
    }
    public static func schoolBin(from: Int, to: Int, percent: Int, school: String) -> String {
      "You're in the group with \(from)–\(to) passes. \(percent)% of \(school) is there."
    }
    public static func mostBlocked(_ app: String, school: String) -> String { "\(app) is the most blocked app at \(school)." }
    public static let asOf = "as of 4 a.m."
    public static let noFriends = "Insights about friends need a friend."
    public static let notVerified = "Add your school to see how it compares."
    public static let share = "Share"
    public static let story = "Story"
    public static let square = "Square"
    public static let light = "Light"
    public static let dark = "Dark"
    public static let showName = "Show my name"
    public static let cancel = "Cancel"
    public static let cardWeek = "Week"
    public static let cardDay = "Day"
    public static let cardGates = "Gates"
    public static let cardFriends = "Friends"
    public static let cardSchool = "School"
    public static let cardExam = "Exam weeks"
  }

  public enum ShareCards {
    public static func week(_ this: Int, last: Int) -> String { "\(this) \(passes(this)) this week\(middleDot)\(last) last week" }
    public static func day(_ n: Int) -> String { "\(n) \(passes(n)) today" }
    public static func gates(_ percent: Int) -> String { "Walked away from \(percent)% of gates this week" }
    public static func friends(_ percent: Int) -> String { "My friends held \(percent)% of gates this week" }
    public static func school(_ school: String, schoolPercent: Int, mine: Int) -> String {
      "\(school) held \(schoolPercent)% of gates this week. I held \(mine)%."
    }
    public static func friendsCount(_ n: Int, passesPerPerson: String) -> String {
      "\(n) friends\(middleDot)\(passesPerPerson) passes per person"
    }
    public static let wordmark = "TOLL"
  }

  public enum Errors {
    public static let generic = "That didn't work. Try again."
    public static let offline = "No connection."
    public static let handleTaken = "taken"
    public static let handleCooldown = "Handles change once a month."
    public static let nameInvalid = "2 to 24 characters."
  }
}
