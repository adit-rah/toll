# Apple setup — founders

Everything here needs the Apple Developer account holder. Nothing in the repo can do it.

## 1. Identifiers (unchanged from Toll)

| Identifier | Type | Capabilities |
|---|---|---|
| `com.advan.toll` | App ID | Family Controls, App Groups, In-App Purchase, HealthKit (D97; not Clinical Health Records, not Background Delivery) |
| `com.advan.toll.ShieldConfig` | App ID | Family Controls, App Groups |
| `com.advan.toll.ShieldAction` | App ID | Family Controls, App Groups |
| `com.advan.toll.Monitor` | App ID | Family Controls, App Groups |
| `com.advan.toll.Report` | App ID | Family Controls, App Groups (#65: Apple's screen time after bed, the `TollReport` extension) |
| `group.com.advan.toll` | App Group | the five App IDs above |

The pivot keeps these ids so their Family Controls (Distribution) approvals carry over. On `com.advan.toll`, Push Notifications, Sign in with Apple and Associated Domains can be switched off; the app no longer asks for them. `com.advan.toll.Report` is built again since #65 (it was Toll's, so its Family Controls (Distribution) approval should carry over): before a build with `TollReport` reaches `main`, check in the developer account that the id still has Family Controls with the Distribution approval, and tick App Groups with `group.com.advan.toll`, or Xcode Cloud can't sign it. Location needs no capability, only the purpose strings in `ios/Config/App-Info.plist`; nor does Before bed's tone (the audio background mode is an Info.plist key) or the trial date in iCloud Keychain. HealthKit must be ticked on `com.advan.toll` before a build with `com.apple.developer.healthkit` reaches `main`, or Xcode Cloud can't sign it.

If a name must change, change `ios/Config/Base.xcconfig`; nothing else hard-codes it. A new bundle id needs a new Family Controls (Distribution) request (developer.apple.com/contact/request/family-controls-distribution).

## 2. App Store Connect

- In-app purchase: one non-consumable, product id `com.advan.toll.full`, $9.99 (price tier of the founders' choosing; the app shows the App Store's localized price). Its display name and description: "Keeps the nightly block running after the free nights." The trial needs no product (decisions D7); if review asks for one, add a $0 non-consumable named "14-day Trial".
- Agreements: the Paid Apps agreement, with tax and banking, must be active before the in-app purchase can be bought, even in TestFlight's sandbox.
- Privacy label: Data Not Collected (MVP spec §9). Reading Health on the device doesn't change it (`docs/app-store.md`).
- A privacy policy URL is required, and with HealthKit the policy must say what Health data is read and that it stays on the device (`docs/privacy.md`).
- Before review: set `TOLL_PRIVACY_URL` (where `docs/privacy.md` is published) and `TOLL_SUPPORT_EMAIL` in `ios/Config/Base.xcconfig`; Settings hides those rows while they are empty.
- Review notes: written in §12 step 10.

## 3. Toll's services to shut down (outside this repo)

The repo no longer contains the Worker, but deleting the code stopped nothing. Shut down and delete the Cloudflare Worker, D1 database, KV, Queues and R2 at `toll.alders.dev`; the Sentry and TelemetryDeck projects; and revoke the APNs and Sign in with Apple keys. Toll's TestFlight testers' accounts and events live in D1: delete them, and tell testers, before the pivot ships under the same app record.

## 4. Xcode Cloud

See `ios/README.md`.
