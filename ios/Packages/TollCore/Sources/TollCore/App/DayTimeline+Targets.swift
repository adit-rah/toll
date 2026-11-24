import Foundation

extension DayTimeline {
  /// A stretch of the strip a tap opens, and the segments its snippet shows.
  public struct Target: Equatable, Sendable {
    public var start: Double
    public var end: Double
    /// Indices into `segments`, earliest first.
    public var segments: [Int]
  }

  /// Where a tap lands (D75): each segment widened to `minimum` (44 pt as a fraction of the strip)
  /// around its middle and held inside the strip. Two that overlap split the room between them
  /// when both keep `minimum`; otherwise they become one target whose snippet shows both, so no
  /// segment is too small to hit and none hides another.
  public func targets(minimum: Double) -> [Target] {
    let minimum = min(1, max(0, minimum))
    var result: [Target] = []
    for index in segments.indices {
      let segment = segments[index]
      let width = max(segment.end - segment.start, minimum)
      let middle = (segment.start + segment.end) / 2
      let start = min(max(0, middle - width / 2), 1 - width)
      var target = Target(start: start, end: start + width, segments: [index])
      guard var last = result.last, last.end > target.start else {
        result.append(target)
        continue
      }
      // Split between the last segment's end and this one's start, if both keep the minimum.
      let lastEnd = last.segments.map { segments[$0].end }.max() ?? last.end
      let split = min(
        max((lastEnd + segment.start) / 2, last.start + minimum), target.end - minimum)
      if split >= last.start + minimum, split <= target.end - minimum, lastEnd <= segment.start {
        last.end = split
        target.start = split
        result[result.count - 1] = last
        result.append(target)
      } else {
        last.end = max(last.end, target.end)
        last.segments.append(index)
        result[result.count - 1] = last
      }
    }
    return result
  }
}
