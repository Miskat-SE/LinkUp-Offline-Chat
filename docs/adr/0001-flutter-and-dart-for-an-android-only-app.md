# ADR-0001: Flutter and Dart for an Android-only app

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D1

## Context

The specification (spec §2) requires Flutter, Dart and Android. No other platform is in scope.

## Decision

Use Flutter stable (3.47.6 / Dart 3.13.5 at P0) and generate only the Android platform folder.

## Consequences

iOS, desktop and web folders are not generated. Platform-specific code goes in the Kotlin bridge (ADR-0008).
