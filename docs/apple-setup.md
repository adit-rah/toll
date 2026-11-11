# Apple setup (E0.1) — founders

Everything here needs the Apple Developer account holder. Nothing in the repo can do it. TestFlight is blocked until the four Family Controls (Distribution) requests are approved (spec §6, ledger D2); the development entitlement works for device builds meanwhile.

## 1. Identifiers (developer.apple.com → Certificates, Identifiers & Profiles)

| Identifier | Type | Capabilities |
|---|---|---|
| `com.advan.toll` | App ID | Family Controls, App Groups, Push Notifications, Sign in with Apple, Associated Domains |
| `com.advan.toll.ShieldConfig` | App ID | Family Controls, App Groups |
| `com.advan.toll.ShieldAction` | App ID | Family Controls, App Groups |
| `com.advan.toll.Monitor` | App ID | Family Controls, App Groups |
| `group.com.advan.toll` | App Group | assign to all four App IDs |

If any of these names must change, change `ios/Config/Base.xcconfig` (and `APPLE_BUNDLE_ID` in `api/wrangler.jsonc`); nothing else hard-codes them.

## 2. Family Controls (Distribution) — file four requests

Form: developer.apple.com/contact/request/family-controls-distribution — one request per bundle id above. Reported turnaround is four business days to several weeks. Paste this justification (adjust the first sentence per extension):

> Toll is a personal self-control app. The person using it chooses apps on their own iPhone to block; when they tap a blocked app, getting past the block costs them a wait spent inside Toll. Toll uses individual (not family) authorization on the user's own device only. It reads no Screen Time usage data and transmits none: the only data that leaves the device are events Toll records itself (for example, "a pass was taken at 9:10 after a 3-minute wait"), labelled with a name the user picks from a fixed list. Tokens never leave the device. There is no payment of any kind for getting past a block: it costs time, never money (Guideline 4.10). This bundle id is [the app / the ShieldConfiguration extension that renders the shield text / the ShieldAction extension that handles the shield's buttons / the DeviceActivityMonitor extension that applies schedules, ends sessions and records a daily check-in].

Record the four request ids here when filed:

| Bundle id | Request id | Filed | Approved |
|---|---|---|---|
| `com.advan.toll` | | | |
| `com.advan.toll.ShieldConfig` | | | |
| `com.advan.toll.ShieldAction` | | | |
| `com.advan.toll.Monitor` | | | |

## 3. Keys

- **APNs key** (Keys → +, Apple Push Notifications service): download the `.p8` once. Its key id → `APNS_KEY_ID` in `api/wrangler.jsonc`; the file contents → `wrangler secret put APNS_PRIVATE_KEY`.
- **Sign in with Apple key** (Keys → +, Sign in with Apple, primary App ID `com.advan.toll`): key id → `APPLE_KEY_ID`; contents → `wrangler secret put APPLE_PRIVATE_KEY`. The Worker uses it to exchange the authorization code and to revoke tokens on account deletion (spec §13).
- **Team id** → `APPLE_TEAM_ID` in `api/wrangler.jsonc` (both environments) and `DEVELOPMENT_TEAM` in `ios/Config/Base.xcconfig` (committed, because Xcode Cloud reads only committed files).

## 4. Associated domains

The Worker serves `https://toll.alders.dev/.well-known/apple-app-site-association` for `/i/*` once `APPLE_TEAM_ID` is set. If the domain changes, update `TOLL_LINK_HOST` and `TOLL_API_BASE_URL` in `ios/Config/Base.xcconfig` and `PUBLIC_BASE_URL` in `api/wrangler.jsonc`.

## 5. Xcode Cloud

See `ios/README.md`. Needs the approved entitlements before the first TestFlight upload.
