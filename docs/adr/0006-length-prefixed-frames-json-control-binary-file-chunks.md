# ADR-0006: Length-prefixed frames: JSON control, binary file chunks

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D6

## Context

Spec §11: control messages structured, file data binary; spec §28: limit control packet sizes.

## Decision

Frame = kind (1 byte) + length (uint32 big-endian) + body. Kind 0x01 is JSON control (≤ 64 KiB), kind 0x02 is a binary file chunk (≤ 256 KiB). UDP datagrams are `RQM1` + JSON, ≤ 1,400 bytes. See PROTOCOL.md.

## Consequences

Lengths are checked before buffering, so oversized input can't exhaust memory.
