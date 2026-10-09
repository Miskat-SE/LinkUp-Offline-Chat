# ADR-0005: One control connection per peer pair plus one data connection per transfer

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D5

## Context

A large file must not block chat messages (spec §11, §36).

## Decision

TCP: a long-lived control connection per pair of peers, and a short-lived data connection for each file transfer. Both use the listening port (28761 preferred).

## Consequences

Chat stays responsive during transfers, and TCP backpressure provides flow control.
