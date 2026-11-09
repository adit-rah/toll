@preconcurrency import Contacts
import Foundation
import UIKit
import UserNotifications

/// Notification permission. Denied is fine: the shield fallback copy turns on and the daily summary
/// stays off (spec §9).
public enum NotificationPermission {
  public static func request() async -> Bool {
    let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    if granted { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } }
    return granted
  }

  public static func isAllowed() async -> Bool {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
  }
}

/// Reads emails and phone numbers to hash on the device (N-12). Nothing raw leaves the phone.
public enum ContactsReader {
  public static var isDenied: Bool {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    return status == .denied || status == .restricted
  }

  public static func read() async -> (emails: [String], phones: [String])? {
    guard (try? await CNContactStore().requestAccess(for: .contacts)) == true else { return nil }
    return await Task.detached { () -> (emails: [String], phones: [String]) in
      let store = CNContactStore()
      var emails: [String] = []
      var phones: [String] = []
      let keys = [CNContactEmailAddressesKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
      try? store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
        emails += contact.emailAddresses.map { $0.value as String }
        phones += contact.phoneNumbers.map { $0.value.stringValue }
      }
      return (emails, phones)
    }.value
  }
}

/// The app sends one 512 px JPEG; the server re-encodes it anyway (ledger A27).
public enum PhotoProcessing {
  public static func jpeg(from data: Data, maxPixels: Int) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let longest = max(image.size.width * image.scale, image.size.height * image.scale)
    let factor = min(1, CGFloat(maxPixels) / max(longest, 1))
    let size = CGSize(
      width: (image.size.width * image.scale * factor).rounded(), height: (image.size.height * image.scale * factor).rounded())
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    return resized.jpegData(compressionQuality: 0.85)
  }
}
