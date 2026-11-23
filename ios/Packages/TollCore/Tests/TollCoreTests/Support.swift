import Foundation

@testable import TollCore

func calendar(_ zone: String) -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
  return calendar
}

func date(
  _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0,
  in zone: String = "Europe/London"
) -> Date {
  calendar(zone).date(
    from: DateComponents(
      year: year, month: month, day: day, hour: hour, minute: minute, second: second))
    ?? .distantPast
}

func time(_ hour: Int, _ minute: Int = 0) -> ClockTime { ClockTime(hour: hour, minute: minute) }

/// 10:30 pm to 7:00 am, the spec's example night.
let usual = TimeWindow(start: time(22, 30), end: time(7))

let london = calendar("Europe/London")
let homePlace = Place(
  id: PlaceID("home"), name: "Home", latitude: 51.5, longitude: -0.12, radiusMeters: 150)
let libraryPlace = Place(
  id: PlaceID("library"), name: "Library", latitude: 51.52, longitude: -0.13, radiusMeters: 150)

func sleepBlock(_ window: TimeWindow = usual, place: PlaceID? = homePlace.id) -> Block {
  Block(
    id: BlockID("sleep"), name: "Sleep", kind: .sleep, place: place, schedule: .everyDay(window),
    apps: Data([1]), appCount: 4)
}

/// 9 to 5 on weekdays at the library.
func studyBlock() -> Block {
  Block(
    id: BlockID("study"), name: "Study", kind: .study, place: libraryPlace.id,
    schedule: WeeklySchedule(rules: [
      .init(days: Weekday.weekdays, window: TimeWindow(start: time(9), end: time(17)))
    ]),
    apps: Data([2]), appCount: 3)
}

/// Set up with the Sleep block at Home, home or not as asked.
func setUp(home isHome: Bool? = true, at: Date = date(2026, 11, 17, 20)) -> DuskState {
  var state = DuskState()
  state.places = [homePlace]
  state.blocks = [sleepBlock()]
  if let isHome { state.presence[homePlace.id] = Presence(isInside: isHome, at: at) }
  return state
}

/// One boot, monotonic seconds equal to wall seconds unless a test moves the wall clock.
func boot(_ wall: Date, shift: TimeInterval = 0, id: String = "boot") -> MonotonicInstant {
  MonotonicInstant(bootID: id, seconds: wall.timeIntervalSinceReferenceDate - shift)
}

@discardableResult
func run(
  _ state: inout DuskState, _ wall: Date, _ cause: ReconcileCause = .foreground,
  monotonic: MonotonicInstant? = nil, calendar: Calendar = london
) -> Effects {
  Engine.reconcile(
    &state, wall: wall, monotonic: monotonic ?? boot(wall), calendar: calendar, cause: cause)
}

func apply(_ command: Command, _ state: inout DuskState, _ now: Date) -> CommandError? {
  Engine.apply(command, to: &state, now: now, calendar: london)
}

func arrive(_ state: inout DuskState, _ place: Place = homePlace, _ at: Date, inside: Bool = true) {
  state.presence[place.id] = Presence(isInside: inside, at: at)
}
