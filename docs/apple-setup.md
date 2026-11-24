# Apple setup — founders

Everything here needs the Apple Developer account holder. Nothing in the repo can do it.

## 1. Identifiers (unchanged from Toll)

| Identifier | Type | Capabilities |
|---|---|---|
| `com.advan.toll` | App ID | Family Controls, App Groups, In-App Purchase |
| `com.advan.toll.ShieldConfig` | App ID | Family Controls, App Groups |
| `com.advan.toll.ShieldAction` | App ID | Family Controls, App Groups |
| `com.advan.toll.Monitor` | App ID | Family Controls, App Groups |
| `group.com.advan.toll` | App Group | the four App IDs above |

The pivot keeps these ids so their Family Controls (Distribution) approvals carry over. On `com.advan.toll`, Push Notifications, Sign in with Apple and Associated Domains can be switched off; the app no longer asks for them. `com.advan.toll.Report` is no longer built and can be left or removed. Location needs no capability, only the purpose strings in `ios/Config/App-Info.plist`.

If a name must change, change `ios/Config/Base.xcconfig`; nothing else hard-codes it. A new bundle id needs a new Family Controls (Distribution) request (developer.apple.com/contact/request/family-controls-distribution).

## 2. App Store Connect

- In-app purchase: one non-consumable, product id `com.advan.toll.full`, $9.99 (price tier of the founders' choosing; the app shows the App Store's localized price). Its display name and description: "Keeps the nightly block running after the free nights." The trial needs no product (decisions D7); if review asks for one, add a $0 non-consumable named "14-day Trial".
- Privacy label: Data Not Collected (MVP spec §9).
- Before review: set `TOLL_PRIVACY_URL` (where `docs/privacy.md` is published) and `TOLL_SUPPORT_EMAIL` in `ios/Config/Base.xcconfig`; Settings hides those rows while they are empty.
- Review notes: written in §12 step 10.

## 3. Toll's services to shut down (outside this repo)

The repo no longer contains the Worker, but deleting the code stopped nothing. Shut down and delete the Cloudflare Worker, D1 database, KV, Queues and R2 at `toll.alders.dev`; the Sentry and TelemetryDeck projects; and revoke the APNs and Sign in with Apple keys. Toll's TestFlight testers' accounts and events live in D1: delete them, and tell testers, before the pivot ships under the same app record.

## 4. Xcode Cloud

See `ios/README.md`.
