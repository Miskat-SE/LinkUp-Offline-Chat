# ADR-0002: Riverpod for state management and dependency injection

- **Status:** Accepted
- **Date:** 2026-10-08
- **Plan decision:** D2

## Context

Spec §21 prefers Riverpod and forbids global mutable state.

## Decision

Use `flutter_riverpod` 3.x. Providers are the only dependency-injection mechanism; classes receive dependencies through constructors. No Riverpod code generation.

## Consequences

Tests override providers instead of patching globals. Core classes stay usable without Riverpod.
