# ADR-0016: Official material_ui package with the Expressive variant where available

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D16

## Context

The plan assumed Flutter had not shipped Material 3 Expressive. P0 vetting found Flutter has moved Material out of the SDK into the official `material_ui` package (flutter.dev, requires Flutter ≥ 3.47). It adds a `StyleVariant.material3Expressive` option (icon buttons first). `dynamic_color` and `go_router` already depend on `material_ui`.

## Decision

Import `package:material_ui/material_ui.dart` instead of `package:flutter/material.dart`. Opt into `StyleVariant.material3Expressive` where the package supports it, and add our own expressive tokens (shape scale, emphasised type, motion) for the rest. Fonts are bundled; `google_fonts` is not used.

## Consequences

Follows Flutter's supported path. Legacy packages that still import the SDK Material library would need `MaterialUiCompatibilityBridge`; none are planned.
