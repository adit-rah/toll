/// The constellations Your sky completes, in the order it completes them (D79): the Big Dipper
/// first, at 7 nights, then Cassiopeia and the Little Dipper; Orion completes at 30 and Pegasus at
/// 100. Simplified stick figures, as most star charts draw them.
public enum Constellation: String, CaseIterable, Sendable {
  case bigDipper, cassiopeia, littleDipper, orion, cygnus, lyra, leo, gemini, taurus, bootes
  case coronaBorealis, hercules, aquila, pegasus, andromeda, perseus, auriga, cepheus, delphinus
  case canisMajor, canisMinor, aries, draco
}

/// One star of the table (`SkyStars.swift`).
struct SkyStar: Sendable {
  let hr: Int
  let x: Double
  let y: Double
  let magnitude: Double
}

/// A constellation's stars, as a range of the table, and its lines, as pairs of table indexes. A
/// line may reach a star of an earlier figure (Auriga shares Elnath with Taurus).
struct SkyFigure: Sendable {
  let constellation: Constellation
  let stars: Range<Int>
  let lines: [(Int, Int)]

  init(_ constellation: Constellation, stars: Range<Int>, lines: [(Int, Int)]) {
    self.constellation = constellation
    self.stars = stars
    self.lines = lines
  }
}

/// Your sky as data, embedded so nothing is fetched and nothing needs a licence (D79).
enum SkyCatalogue {
  /// The sky's height, in widths.
  static let aspect = 0.52

  static let figures: [SkyFigure] = [
    .init(
      .bigDipper, stars: 0..<7, lines: [(0, 1), (1, 2), (2, 3), (3, 0), (3, 4), (4, 5), (5, 6)]),
    .init(.cassiopeia, stars: 7..<12, lines: [(7, 8), (8, 9), (9, 10), (10, 11)]),
    .init(
      .littleDipper, stars: 12..<19,
      lines: [(12, 13), (13, 14), (14, 15), (15, 16), (16, 17), (17, 18), (18, 15)]),
    .init(
      .orion, stars: 19..<30,
      lines: [
        (20, 19), (20, 21), (21, 22), (22, 23), (23, 24), (24, 19), (22, 25), (24, 26), (21, 27),
        (19, 28), (23, 29),
      ]),
    .init(.cygnus, stars: 30..<36, lines: [(30, 31), (31, 32), (32, 33), (34, 31), (31, 35)]),
    .init(
      .lyra, stars: 36..<42,
      lines: [(36, 37), (36, 38), (37, 38), (38, 39), (39, 40), (40, 41), (41, 38)]),
    .init(
      .leo, stars: 42..<51,
      lines: [
        (42, 43), (43, 44), (44, 45), (45, 46), (46, 47), (44, 48), (48, 49), (49, 50), (50, 42),
      ]),
    .init(
      .gemini, stars: 51..<59,
      lines: [(51, 52), (51, 53), (53, 54), (54, 55), (55, 56), (52, 57), (57, 58)]),
    .init(
      .taurus, stars: 59..<66, lines: [(65, 59), (59, 60), (60, 61), (61, 62), (62, 63), (63, 64)]),
    .init(
      .bootes, stars: 66..<73,
      lines: [(66, 67), (67, 68), (68, 69), (69, 70), (70, 71), (71, 66), (66, 72)]),
    .init(
      .coronaBorealis, stars: 73..<80,
      lines: [(73, 74), (74, 75), (75, 76), (76, 77), (77, 78), (78, 79)]),
    .init(
      .hercules, stars: 80..<86,
      lines: [(82, 81), (81, 80), (80, 83), (83, 82), (80, 84), (83, 85)]
    ),
    .init(
      .aquila, stars: 86..<93, lines: [(87, 86), (86, 88), (86, 89), (89, 90), (89, 91), (89, 92)]),
    .init(
      .pegasus, stars: 93..<100,
      lines: [(93, 94), (94, 95), (95, 96), (96, 93), (93, 97), (97, 98), (98, 99)]),
    .init(.andromeda, stars: 100..<105, lines: [(100, 101), (101, 102), (101, 103), (103, 104)]),
    .init(
      .perseus, stars: 105..<112,
      lines: [(107, 106), (106, 105), (105, 108), (108, 109), (109, 110), (105, 111)]),
    .init(
      .auriga, stars: 112..<117,
      lines: [(112, 113), (113, 114), (114, 64), (64, 115), (115, 112), (112, 116)]),
    .init(
      .cepheus, stars: 117..<122,
      lines: [(117, 118), (118, 119), (119, 120), (120, 121), (121, 117), (117, 120)]),
    .init(
      .delphinus, stars: 122..<127,
      lines: [(122, 123), (123, 124), (124, 125), (125, 126), (126, 123)]),
    .init(
      .canisMajor, stars: 127..<133,
      lines: [(128, 127), (127, 129), (129, 130), (130, 131), (130, 132)]),
    .init(.canisMinor, stars: 133..<135, lines: [(133, 134)]),
    .init(.aries, stars: 135..<138, lines: [(135, 136), (136, 137)]),
    .init(
      .draco, stars: 138..<150,
      lines: [
        (138, 139), (139, 140), (140, 141), (141, 138), (141, 142), (142, 143), (143, 144),
        (144, 145), (145, 146), (146, 147), (147, 148), (148, 149),
      ]),
  ]
}
