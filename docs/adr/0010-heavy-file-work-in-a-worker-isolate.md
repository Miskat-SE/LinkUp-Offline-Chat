# ADR-0010: Heavy file work in a worker isolate

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D10

## Context

Spec §13 and §36: no whole-file reads, no UI jank.

## Decision

File reads/writes, hashing and data sockets run in a long-lived transfer isolate that receives paths from the main isolate and posts progress at most 10 times a second.

## Consequences

The UI isolate only handles discovery, control traffic and the database.
