# ADR-0015: SDK levels: minSdk 26, targetSdk 36 for now

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D15

## Context

The plan aimed for targetSdk 37 if Flutter stable supported it. Flutter 3.47.6 defaults to compileSdk 36, targetSdk 36, minSdk 24. Android 17 enforces the local network permission only for apps targeting 37+; apps below 37 that declare INTERNET are granted access automatically, and Google discourages requesting `ACCESS_LOCAL_NETWORK` before targeting 37.

## Decision

`minSdk 26`, `compileSdk` and `targetSdk` follow Flutter's defaults (36). The app does not request `ACCESS_LOCAL_NETWORK` yet, but treats `EPERM` socket errors as a Blocked state. Revisit when Flutter stable targets 37.

## Consequences

No extra permission prompt today; a known migration item when moving to targetSdk 37.
