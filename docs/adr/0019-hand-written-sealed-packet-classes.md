# ADR-0019: Hand-written sealed packet classes

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D19

## Context

Spec §19 asks for strongly typed packet models; spec §28 asks for strict validation.

## Decision

One `final class` per packet type under a `sealed class Packet`, with hand-written validating `fromJson`/`toJson`. The codec returns a `DecodeResult` instead of throwing.

## Consequences

No code generation for packets; exhaustive `switch` statements catch missing handlers at compile time.
