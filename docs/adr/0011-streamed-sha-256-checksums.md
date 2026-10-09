# ADR-0011: Streamed SHA-256 checksums

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D11

## Context

Spec §11, §12 and §28 require checksum verification and duplicate detection.

## Decision

SHA-256 via `crypto`, computed in chunks. The sender hashes before the offer (cached by path, size and modified time); the receiver hashes while writing and re-hashes the partial file on resume.

## Consequences

No file is held in memory; identical content from the same sender is detected without re-sending.
