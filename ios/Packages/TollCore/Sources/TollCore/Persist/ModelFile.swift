import Foundation

/// The person's sleep model state, `model.json` in the App Group: written by the app alone, which
/// rebuilds it from the night records whenever the bundled artifact changes (`ModelStore` in
/// TollData, decisions D52). The extensions never read it.
public enum ModelFile {
  public static var url: URL { AppGroup.file("model.json") }
}
