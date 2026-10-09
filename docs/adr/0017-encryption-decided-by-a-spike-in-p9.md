# ADR-0017: Encryption decided by a spike in P9

- **Status:** Accepted; decided by ADR-0022 (no encryption in v1.0)
- **Date:** 2026-10-08
- **Plan decision:** D17

## Context

Spec §29: encryption only if practical, using established primitives, never at the cost of stability.

## Decision

Spike in P9: TLS 1.3 via `dart:io` `SecureSocket` with a self-signed certificate per device, pinned on first use per device ID. Ship only if the device matrix passes and file throughput drops ≤ 20%; otherwise ship plaintext and document it.

## Consequences

Until P9 all traffic is plaintext on the trusted LAN (documented).
