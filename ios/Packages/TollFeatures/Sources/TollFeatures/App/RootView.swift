import SwiftUI
import TollUI

/// The one window. Empty until setup and Status exist (MVP spec §12 steps 4 and 5).
public struct RootView: View {
  public init() {}

  public var body: some View {
    TollColor.bg.ignoresSafeArea()
  }
}
