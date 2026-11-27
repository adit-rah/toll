/// The artifact this build carries, for the monitor's night records: the extensions never link the
/// model, and model.json can name an older one until the app opens after an update (#140). Written
/// by ios/scripts/sync-model.sh from the artifact, never by hand.
public enum BundledModel {
  public static let version = "sleep-model.v1"
}
