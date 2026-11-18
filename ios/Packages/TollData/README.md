# TollData

App-only services: the Keychain (trial start, MVP spec P-4), and, as the build order reaches them, location (home region) and StoreKit (purchase, restore). No third-party code.

Invariants
- Never imported by an extension.
- Nothing here talks to a server other than the App Store.
