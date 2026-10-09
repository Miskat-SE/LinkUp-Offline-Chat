# ADR-0020: The database schema grows with the phases

- **Status:** Accepted
- **Date:** 2026-10-09
- **Plan decision:** D22

## Context

PROJECT_PLAN.md §8.1 sketched four tables for schema version 1: `peers`, `messages`, `message_recipients` and `files`. P5 only needs messages. Tables created before their feature exists can't be tested against real use, and their columns tend to be guessed wrong.

## Decision

- Schema v1 has the `messages` table only. `files` arrives with file sharing (P6), `message_recipients` with broadcast (P7), and `peers` when a feature needs people remembered across restarts. Each is a numbered migration with a schema snapshot and a migration test.
- Message IDs are unique on their own. They are random UUIDs chosen by the sender, so the plan's (`senderDeviceId`, `messageId`) key adds nothing for direct messages.
- Stored values are fixed text codes (`in`/`out`, `pending`, `sent`, …), mapped by the chat repository rather than taken from Dart enum names. An unknown code from a newer version reads as *failed*, never a crash.
- Times are stored as UTC microseconds: exact, and they sort correctly.
- There is one repository implementation. Tests use the real schema on an in-memory SQLite database instead of a hand-written in-memory copy.

## Consequences

The migration path is exercised from P6 on, with tests. The schema always matches what the app uses. Tests check the SQL that ships, not a stand-in that could drift from it.
