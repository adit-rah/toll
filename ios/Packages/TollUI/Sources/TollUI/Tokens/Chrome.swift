import SwiftUI
import UIKit

/// Apple's controls in content that take a colour only through UIKit's appearance proxies.
@MainActor
public enum TollChrome {
  /// The segmented control's chosen segment is white by default: the brightest thing on a light
  /// page (design §2.3).
  public static func apply() {
    UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(TollColor.chosen)
  }
}
