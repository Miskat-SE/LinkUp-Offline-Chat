# ADR-0014: Files stored under our own IDs

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D14

## Context

Spec §28: never trust incoming file names; prevent path traversal.

## Decision

Files are written to app-internal storage as `<dir>/<fileId>`. Incoming names are sanitised and used only for display and export. P0 vetting: `file_picker` always copies the picked file into the cache; that copy is moved (same partition, no second copy) into `files/sent/<fileId>`.

## Consequences

Path traversal is impossible by construction; the sent copy supports retry and resume.
