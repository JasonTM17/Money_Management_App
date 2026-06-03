# 2. Offline-First Architecture

> **Date:** 2026-05-29
> **Status:** Accepted

## Context

CashFlow Manager targets users who may have intermittent connectivity (commuting, rural areas, data-saving mode). A server-dependent app would fail to open or lose data in these scenarios, making it unreliable for daily finance tracking.

## Decision

The Flutter app uses an offline-first architecture:
- **SQLite** (via `sqlite3_flutter_libs` + `dart:ffi`) as the local source of truth
- **Riverpod** for reactive state management with local-first data flow
- **Remote sync** is opt-in and non-blocking — the app is fully functional without an account
- Sync uses last-write-wins with server-side conflict detection via `updatedAt` timestamps
- Backend PostgreSQL is the canonical remote store; API is Fastify + Prisma

## Consequences

### Positive
- App opens instantly, works in airplane mode
- No loading spinners on core screens (dashboard, transactions, wallets)
- Backend outage does not affect local usage
- Users control when/if data leaves their device

### Negative
- Conflict resolution is simplistic (last-write-wins); true CRDT merge would be more correct
- Schema migrations must be coordinated across local SQLite and server PostgreSQL
- Dual data layer adds testing complexity

### Neutral
- Sync status is visible in the UI (sync indicator badge)

## Alternatives Considered

| Option | Pros | Cons | Why rejected |
|--------|------|------|-------------|
| Server-first (REST-only) | Simple architecture, single source of truth | Unusable offline, latency on every tap | Unacceptable UX for target users |
| Firebase/Firestore | Built-in offline, real-time sync | Vendor lock-in, opaque pricing, no PostgreSQL | Self-hosted stack preferred |
| Isar DB | Fast, Dart-native | Unstable API across versions, smaller ecosystem | SQLite is battle-tested |

## References

- [Riverpod documentation](https://riverpod.dev/)
- [sqlite3_flutter_libs](https://pub.dev/packages/sqlite3_flutter_libs)
