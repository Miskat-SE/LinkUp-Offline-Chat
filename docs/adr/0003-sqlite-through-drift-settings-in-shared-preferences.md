# ADR-0003: SQLite through drift; settings in shared_preferences

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D3

## Context

Spec §9 requires SQLite with indexes and no binary data in the database. The chat UI needs reactive queries.

## Decision

Use `drift` + `drift_flutter` (dev: `drift_dev`, `build_runner`). P0 vetting found `sqlite3_flutter_libs` is end-of-life: `sqlite3` 3.x bundles SQLite through Dart build hooks, so it is not added. Identity and settings live in `shared_preferences`.

## Consequences

Type-safe queries, migrations and `watch` streams. Desktop unit tests use an in-memory database. Code generation is needed for the database only.
