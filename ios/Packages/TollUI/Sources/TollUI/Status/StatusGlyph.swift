import SwiftUI
import TollCore

/// What a glyph shows: a level, or the dashed ring when the level is unknown or Toll is off.
public struct StatusMark: Hashable, Sendable {
  public var level: StatusLevel?
  public var isSilent: Bool

  public init(level: StatusLevel?, isSilent: Bool = false) {
    self.level = level
    self.isSilent = isSilent
  }

  public static func level(_ level: StatusLevel) -> StatusMark { StatusMark(level: level) }
  public static let silent = StatusMark(level: nil, isSilent: true)

  var shownLevel: StatusLevel? { isSilent ? nil : level }
}

/// Design §3.1. The level is carried by shape (filled, left half, ring with a dot) so it reads in
/// grayscale; colour only reinforces it.
public struct StatusGlyph: View {
  public enum Size: CGFloat, Sendable {
    case badge = 12
    case row = 14
    case hero = 20
  }

  let mark: StatusMark
  let size: Size
  let accessibilityText: String?

  /// Pass `accessibilityLabel` (`Copy.Status.label`, or `Copy.FriendRows.silentAccessibility`) when
  /// the glyph stands alone; leave it nil inside a row whose own label already says the level.
  public init(
    level: StatusLevel?, isSilent: Bool = false, size: Size = .row,
    accessibilityLabel: String? = nil
  ) {
    self.init(
      StatusMark(level: level, isSilent: isSilent), size: size,
      accessibilityLabel: accessibilityLabel)
  }

  public init(_ mark: StatusMark, size: Size = .row, accessibilityLabel: String? = nil) {
    self.mark = mark
    self.size = size
    self.accessibilityText = accessibilityLabel
  }

  public var body: some View {
    ZStack {
      shape(for: mark.shownLevel)
        .id(mark.shownLevel)
        .transition(.opacity)
    }
    .frame(width: size.rawValue, height: size.rawValue)
    .animation(Motion.movement, value: mark.shownLevel)
    .accessibilityElement()
    .accessibilityLabel(accessibilityText ?? "")
    .accessibilityHidden(accessibilityText == nil)
  }

  private var lineWidth: CGFloat { max(1.5, size.rawValue / 9) }

  /// About 2 pt, adjusted so a whole number of dashes goes round and the ring has no short seam.
  private var dashLength: CGFloat {
    let circumference = CGFloat.pi * (size.rawValue - lineWidth)
    let dashes = max(4, (circumference / 4).rounded())
    return circumference / (dashes * 2)
  }

  @ViewBuilder
  private func shape(for level: StatusLevel?) -> some View {
    switch level {
    case .some(.fewer):
      Circle().fill(TollColor.level1)
    case .some(.usual):
      ZStack {
        // A circle's path starts at three o'clock, so the middle half of it is the left half.
        // Trimmed rather than masked: a mask costs an offscreen pass for every row's glyph.
        Circle()
          .trim(from: 0.25, to: 0.75)
          .fill(TollColor.level2)
        Circle().strokeBorder(TollColor.level2, lineWidth: lineWidth)
      }
    case .some(.more):
      ZStack {
        Circle().strokeBorder(TollColor.level3, lineWidth: lineWidth)
        Circle()
          .fill(TollColor.level3)
          .frame(width: size.rawValue * 2 / 7, height: size.rawValue * 2 / 7)
      }
    case .none:
      Circle()
        .strokeBorder(
          TollColor.label3,
          style: StrokeStyle(lineWidth: lineWidth, dash: [dashLength, dashLength]))
    }
  }
}
