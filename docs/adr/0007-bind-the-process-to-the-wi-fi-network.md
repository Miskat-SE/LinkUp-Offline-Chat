# ADR-0007: Bind the process to the Wi-Fi network

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D7

## Context

When Wi-Fi has no internet and mobile data is on, Android may make mobile data the default network, and LAN traffic can fail (spec §16).

## Decision

The Kotlin bridge requests a Wi-Fi network without requiring the internet capability, calls `bindProcessToNetwork` while it is up, and holds a `MulticastLock` while discovery runs.

## Consequences

To be verified on devices in the discovery spike (P0.5): that binding applies to `dart:io` sockets.
