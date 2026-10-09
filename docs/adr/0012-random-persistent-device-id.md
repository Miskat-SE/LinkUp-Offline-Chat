# ADR-0012: Random persistent device ID

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D12

## Context

Spec §4 and §28: device identity must not be the username.

## Decision

A UUID v4 generated on first launch and stored locally. It only changes after Clear all local data.

## Consequences

Renames never split conversations. Without encryption, a device ID can be spoofed on the LAN (documented in the security model).
