# ADR-0009: Cached FlutterEngine plus a connectedDevice foreground service

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D9

## Context

Spec §18 and §42: reliable background transfers on modern Android, no unnecessary services. `dataSync` services are capped at 6 hours a day from Android 15.

## Decision

The Application creates and caches the FlutterEngine; MainActivity attaches to it. A `connectedDevice` foreground service runs during transfers, and while idle only if the user enables Stay reachable.

## Consequences

The Dart isolate survives the activity being closed while the service runs. Force-stop and reboot are documented limitations.
