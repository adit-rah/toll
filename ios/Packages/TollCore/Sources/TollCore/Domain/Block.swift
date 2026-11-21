import Foundation

/// One block (D29): these apps, at this place, in these hours. Exactly one is the Sleep block, whose
/// occurrences are the nights the trial and the unlock refill count.
public struct Block: Codable, Hashable, Sendable, Identifiable {
  public enum Kind: String, Codable, CaseIterable, Sendable {
    case sleep, study, work, gym, other
  }

  public var id: BlockID
  public var name: String
  public var kind: Kind
  /// Nil: anywhere.
  public var place: PlaceID?
  public var schedule: WeeklySchedule
  /// The encoded `FamilyActivitySelection`; opaque here, read only by the Screen Time adapter.
  public var apps: Data?
  /// Apps and sites named one by one in `apps`, counted when it was chosen: iOS limits the block to 50
  /// by name across every block (D29), and the domain cannot open `apps` to count them.
  public var appCount: Int
  public var categoryCount: Int
  public var isOn: Bool
  /// Without Always location the app can't tell when the user is at `place`. True: the block waits
  /// for Always instead of running on its hours anywhere (D37). The user chooses when saving (#63).
  /// Sleep ignores it: Sleep always runs on its hours (D37).
  public var onlyAtPlace: Bool

  public init(
    id: BlockID = .make(), name: String, kind: Kind, place: PlaceID?, schedule: WeeklySchedule,
    apps: Data?, appCount: Int = 0, categoryCount: Int = 0, isOn: Bool = true,
    onlyAtPlace: Bool = false
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.place = place
    self.schedule = schedule
    self.apps = apps
    self.appCount = appCount
    self.categoryCount = categoryCount
    self.isOn = isOn
    self.onlyAtPlace = onlyAtPlace
  }

  public var isSleep: Bool { kind == .sleep }
}

/// A place blocks share by id, so moving Home moves every block at Home.
public struct Place: Codable, Hashable, Sendable, Identifiable {
  public var id: PlaceID
  public var name: String
  public var latitude: Double
  public var longitude: Double
  public var radiusMeters: Double

  public init(
    id: PlaceID = .make(), name: String, latitude: Double, longitude: Double, radiusMeters: Double
  ) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.radiusMeters = radiusMeters
  }

  /// Same spot and size; the name does not move the region.
  public func sameRegion(as other: Place) -> Bool {
    latitude == other.latitude && longitude == other.longitude && radiusMeters == other.radiusMeters
  }
}

/// The last word from region monitoring for one place: one boolean and when it came (spec §9).
public struct Presence: Codable, Hashable, Sendable {
  public var isInside: Bool
  public var at: Date

  public init(isInside: Bool, at: Date) {
    self.isInside = isInside
    self.at = at
  }
}

/// Decisions D8, D37: without Always and Precise location, places are ignored and every block runs on
/// its hours alone, so nothing paid depends on location.
public enum LocationMode: String, Codable, Hashable, Sendable {
  case places
  case scheduleOnly
}
