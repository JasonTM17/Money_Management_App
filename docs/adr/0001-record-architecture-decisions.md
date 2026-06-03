# 1. Record Architecture Decisions

> **Date:** 2026-05-29
> **Status:** Accepted

## Context

CashFlow Manager needs a lightweight, maintainable way to track architectural decisions that compound over time. Decisions made early (auth algorithm, numeric strategy, database choice) affect every subsequent feature and must be traceable.

## Decision

Use Architecture Decision Records (ADRs) in `docs/adr/`, following the format:
- Sequential numbering (`0001`, `0002`, ...)
- One decision per file
- Template: Context → Decision → Consequences → Alternatives

ADRs are append-only — accepted ADRs are never edited. New ADRs supersede old ones with explicit `Supersedes ADR-NNNN`.

## Consequences

### Positive
- Every architectural choice has a written rationale with trade-offs
- New contributors understand why things are the way they are
- Decisions are revisitable — superseded ADRs preserve history

### Negative
- Adds ~5 minutes overhead per meaningful decision
- Requires discipline to write before (not after) implementation

### Neutral
- ADRs are project-local, not synced to any external system

## References

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub organization](https://adr.github.io/)
