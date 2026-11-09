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
    public static func passesToday(_ n: Int) -> String { "\(passes(n)) today" }
    public static func week(_ this: Int, last: Int) -> String {
      "\(this) this week\(middleDot)\(last) last week"
    }
    public static func tollOpens(_ n: Int) -> String {
      "You opened Toll \(n) \(n == 1 ? "time" : "times") today."
    }
    public static func sessionActive(_ app: String, minutes: Int) -> String {
      "\(app) is open\(middleDot)ends after \(minutes) min of use."
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
    public static let note = "Measured in use of the app. The block returns after."
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
}
