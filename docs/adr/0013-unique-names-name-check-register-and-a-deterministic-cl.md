# ADR-0013: Unique names: NAME_CHECK, REGISTER and a deterministic clash rule

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D13

## Context

Spec §5: names must be unique among active peers, but the app must open with no peers.

## Decision

Names are trimmed, internal whitespace collapsed, 2–30 graphemes, compared case-insensitively. Before claiming, check online peers and broadcast NAME_CHECK for 3 s. Later clashes: earlier `nameClaimedAt` wins, ties go to the lower device ID.

## Consequences

Behaviour is predictable when two networks merge; the losing device is asked to rename.
