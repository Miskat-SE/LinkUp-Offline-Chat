# ADR-0022: v1.0 ships without encryption on the trusted LAN

- **Status:** Accepted
- **Date:** 2026-10-10
- **Plan decision:** D17 (decided by the P9.5 spike; refines ADR-0017)

## Context

ADR-0017 left encryption to a spike: TLS 1.3 through `dart:io` with self-signed certificates pinned per device on first use, shipped only if stable and if file throughput drops by 20% or less.

Spike results (`tool/tls_spike.dart`, 512 MB over loopback on a MacBook, same write pattern as file transfers):

| | Median throughput | Handshake |
|---|---|---|
| Plaintext | 1,656 MB/s | — |
| TLS 1.3, server pinned | 122 MB/s (−93%) | 1.4 ms |

- **Speed:** on phones, with processors several times slower, TLS would top out around the speed of fast Wi-Fi (an estimate; not measured on a phone), so large transfers could slow down. That fails the "20% or less" rule, or at best can't be guaranteed.
- **Identity:** a `dart:io` TLS server can't accept an unknown self-signed client certificate (the handshake fails with `CERTIFICATE_VERIFY_FAILED`). Mutual trust-on-first-use pinning isn't possible with `dart:io` alone, so only the accepting phone could be pinned; the sender's identity would remain a claim.
- **Dependencies:** generating keys and certificates on the phone needs extra cryptography packages (no public certificate API on Android), which would need vetting.

## Decision

v1.0 sends messages and files **unencrypted**, for use on a local network the user trusts, and says so plainly in the README and in the app (Settings → Privacy). The protections that don't depend on encryption all ship: strict validation of every input, size and rate limits, checksums, files stored under our own IDs, no message text or file names in logs, and data kept only in the app's private storage.

## Consequences

- Anyone on the same Wi-Fi with the right tools can read traffic, and a device can claim another's ID. Both are documented under *Security model*.
- Full Wi-Fi speed and no new dependencies for v1.0.
- After v1.0, encryption is reconsidered with a vetted Noise XX implementation or platform TLS with client-certificate support; the spike tool and these numbers are the baseline. The protocol already has `capabilities` in HELLO, so encryption can be negotiated later without breaking v1.0 devices.
