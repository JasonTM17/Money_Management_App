# 4. Integer-Based Financial Amounts

> **Date:** 2026-05-30
> **Status:** Accepted

## Context

Floating-point arithmetic (IEEE 754) cannot exactly represent most decimal fractions. `0.1 + 0.2 !== 0.3` in every language that uses floats. In finance, rounding errors compound over thousands of transactions and become visible as incorrect balances — a critical bug for a money management app.

## Decision

- All monetary amounts are stored and transmitted as **integers representing the smallest currency unit** (VND đồng, USD cents, JPY units)
- TypeScript/Prisma: `BigInt` for amounts in the database schema
- Flutter/Dart: `int` for amounts, displayed via `decimal` package for formatting only
- API validation enforces integer amounts via Zod schemas (`z.number().int()`)
- Frontend input fields accept decimal notation and convert to integer before storage (e.g., "18,000,000" → `18000000`)

## Consequences

### Positive
- Zero rounding errors — all arithmetic is exact integer math
- Consistent across stack: DB (BigInt), API (int), Flutter (int)
- Avoids `double` bugs that plague finance apps

### Negative
- Developers must remember to divide by 100 (or currency divisor) for display
- Multi-currency support requires per-currency divisor (VND = 1, USD = 100)
- Some libraries expect float amounts — need adapter layer

### Neutral
- Formatting code is centralized in `amount_format.dart` and API response serializers

## Alternatives Considered

| Option | Pros | Cons | Why rejected |
|--------|------|------|-------------|
| `double`/`Float` | Works with every library | Rounding errors, `0.1+0.2 !== 0.3` | Non-starter for finance |
| `Decimal`/`BigDecimal` type | Exact decimal arithmetic | Slower, larger, inconsistent across languages | Integer is simpler and just as correct |
| String amounts ("18.50") | Human-readable in JSON | Must parse for every operation, validation burden | Adds complexity for no gain |

## References

- [IEEE 754 problems](https://0.30000000000000004.com/)
- `api/src/modules/finance/finance-schemas.ts` — Zod validation with `.int()`
- `api/prisma/schema.prisma` — BigInt amount fields
