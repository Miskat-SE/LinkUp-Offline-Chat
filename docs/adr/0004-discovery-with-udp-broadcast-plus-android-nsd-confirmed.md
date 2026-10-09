# ADR-0004: Discovery with UDP broadcast plus Android NSD, confirmed over TCP

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D4

## Context

Spec §4 asks for NSD/mDNS where practical and UDP broadcast as a fallback. Both are unreliable on some phones and routers.

## Decision

Run both: UDP HELLO announcements on port 28760 are the main liveness signal; NSD (`_resqmesh._tcp`, via `bonsoir`) adds candidate addresses. A peer is online only after a TCP HELLO succeeds. P0 vetting: `bonsoir` 7.1.x queues resolves on older Android and uses the Android 14+ callback API.

## Consequences

Discovery keeps working when either mechanism is filtered. Ghost peers (stale NSD entries) never show as online.
