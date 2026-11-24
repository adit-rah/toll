extension Copy {
  /// Your sky (D79). Facts only: how many nights and which shapes are there, never what's left or
  /// what comes next.
  public enum Sky {
    public static let title = "Your sky"

    /// "Your sky. 23 nights. 3 constellations." Before the first shape, just the nights.
    public static func spoken(nights: Int, constellations: Int) -> String {
      let shapes =
        constellations == 0
        ? "" : constellations == 1 ? " 1 constellation." : " \(constellations) constellations."
      return "\(title). \(number(nights)).\(shapes)"
    }

    /// The number in the shared picture: "30 nights".
    public static func number(_ nights: Int) -> String {
      nights == 1 ? "1 night" : "\(nights) nights"
    }

    /// The morning card's landmark line: "30 nights. Orion is in your sky."
    public static func landmark(_ nights: Int, completed: Constellation?) -> String {
      guard let completed else { return "\(number(nights)) in your sky." }
      return "\(number(nights)). \(name(completed)) is in your sky."
    }

    public static let share = "Share"

    public static func name(_ constellation: Constellation) -> String {
      switch constellation {
      case .bigDipper: "The Big Dipper"
      case .cassiopeia: "Cassiopeia"
      case .littleDipper: "The Little Dipper"
      case .orion: "Orion"
      case .cygnus: "Cygnus"
      case .lyra: "Lyra"
      case .leo: "Leo"
      case .gemini: "Gemini"
      case .taurus: "Taurus"
      case .bootes: "Boötes"
      case .coronaBorealis: "Corona Borealis"
      case .hercules: "Hercules"
      case .aquila: "Aquila"
      case .pegasus: "Pegasus"
      case .andromeda: "Andromeda"
      case .perseus: "Perseus"
      case .auriga: "Auriga"
      case .cepheus: "Cepheus"
      case .delphinus: "Delphinus"
      case .canisMajor: "Canis Major"
      case .canisMinor: "Canis Minor"
      case .aries: "Aries"
      case .draco: "Draco"
      }
    }
  }
}
