# TollData

The app's persistence and I/O: GRDB store (events, blocks, settings), spool ingest from the App Group, the outbox that posts events, the `APIClient` actor, Keychain, and analytics (TelemetryDeck, Sentry). Services are protocols collected in `Dependencies` with `.live`, `.preview` and `.test` factories.

Invariants
- Never imported by an extension.
- Migrations are append-only (`DatabaseMigrator` names never change).
- Every write request carries an `Idempotency-Key`; events carry client UUIDv7 ids.
- API models mirror the Zod schemas in `api/src/features/*/contract.ts`.
