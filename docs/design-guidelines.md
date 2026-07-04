# Design Guidelines

Visual language, design tokens, and UI patterns for CashFlow Manager. All app
screens should inherit this vocabulary.

## 2026-07 Private Banking Ledger Refresh

CashFlow Manager now uses a light-first, premium mobile finance direction based
on a ClaudeKit/Stitch exploration. Stitch reference:
`plans/stitch-cashflow-redesign/` (ignored local design export), project
`933341575628831362`, screen `81692608becb44968f624e8fac5963c5`.

- **First viewport:** Dashboard leads with a large ivory balance hero, net
  cashflow pill, and compact income/expense mini metrics.
- **Navigation:** Five Material 3 destinations sit in a floating rounded bottom
  capsule. App-bar add/settings actions stay global and visible.
- **Surfaces:** Default to warm ivory panels, low-contrast borders, and soft
  shadows. Dark mode remains supported but no longer drives the brand.
- **Color:** Emerald is the only primary action color. Amber is reserved for
  warning/insight states. Avoid broad blue, purple, neon, or gradient-heavy UI.
- **Numbers:** Money values use tabular figures where possible to reduce layout
  jitter in balances, ledgers, charts, and metric cards.
- **Transactions:** Ledger rows keep amount, note, wallet/category/date chips,
  and delete action compact. Long text may wrap, but must not collide.
- **Wallets:** Start with a portfolio summary showing total balance and wallet
  count before individual wallet rows.
- **Responsive layout:** Main scroll content is constrained on larger screens
  while staying full-width and touch-friendly on phones.
- **Docs media:** Screenshots are regenerated from deterministic fake data after
  UI changes and manually checked for blank, clipped, or overlapped states.

## Design Tokens

### Color System

Source of truth: [app_theme.dart](../lib/app/app_theme.dart).

| Token | Light Mode | Dark Mode | Usage |
|-------|------------|-----------|-------|
| `primary` | `#0F7A5C` | `#7BE0B3` | Primary actions, active nav, net-positive states |
| `onPrimary` | `#FFFFFF` | `#092116` | Text/icon on primary |
| `surface` | `#F4F0E7` | `#101613` | App background |
| `panel` | `#FFFCF4` | `#1B2721` | Cards, sheets, bottom nav |
| `panelTint` | `#F8F2E6` | `#24352C` | Inputs, subtle elevated areas |
| `ink` | `#1D251F` | `#E8EFE8` | Headings, body |
| `mutedInk` | `#667267` | `#BAC7BB` | Metadata, captions |
| `border` | `#E5DBC9` | `#354338` | Card borders, dividers |
| `income` | `#0F8F68` | `#0F8F68` | Income amounts and chart rods |
| `expense` | `#C2413A` | `#C2413A` | Expense amounts and chart rods |
| `warning` | `#B7791F` | `#B7791F` | Budget warning, insight states |
| `forecast` | `#126E6A` | `#126E6A` | Forecast and secondary finance states |

### Typography

| Level | Font | Weight | Usage |
|-------|------|--------|-------|
| Balance display | Be Vietnam Pro | 800 | Dashboard hero money values |
| Screen title | Be Vietnam Pro | 800 | Tab titles, settings sheet titles |
| Card title | Be Vietnam Pro | 700-800 | Panels and row headings |
| Body | Be Vietnam Pro | 400-600 | Forms, descriptions, list content |
| Labels | Be Vietnam Pro | 600-800 | Chips, nav labels, badges |

Japanese text uses Noto Sans JP as fallback. Money and chart values should use
tabular figures.

### Spacing And Roundness

| Token | Value | Usage |
|-------|-------|-------|
| `controlRadius` | 12 | Inputs, chips, compact controls |
| `cardRadius` | 18 | Repeated cards and panels |
| `sheetRadius` | 22 | Sheets and large modal surfaces |
| `pillRadius` | 999 | Pills, nav indicator, status chips |
| `bottomNavigationHeight` | 72 | Floating bottom navigation capsule |

Use dense mobile spacing: 8-14 px for row gaps, 14-20 px for panel padding, and
24 px only for major section transitions.

## UI Vocabulary

Shared Flutter widgets and patterns. Prefer these before creating new visual
surfaces:

| Pattern | Usage |
|---------|-------|
| SoftPanel | Default card/sheet surface with semantic tint |
| MetricCard | Compact KPI card with tabular money value |
| HeroBalanceCard | First dashboard card; only one per dashboard |
| StatusPill | Compact semantic state, count, or net-cashflow badge |
| TransactionTile | Ledger row with amount, chips, and optional delete action |
| InlineInfoCard | Short warning/forecast/privacy row |
| Floating NavigationBar | Five primary app destinations in bottom capsule |
| EmptyState | Every no-data branch |

### Anti-Patterns - Fix On Sight

| Bad | Good |
|-----|------|
| Raw blue/purple gradients | Use AppTheme finance tokens |
| Web CSS vocabulary in Flutter docs | Use actual Flutter widget names |
| Decorative nested cards | One SoftPanel per repeated item or tool |
| Giant marketing hero inside the app | Dense mobile finance surface |
| Placeholder/real finance screenshots | Seeded fake data screenshots only |
| Hidden primary add action | Keep add transaction in app bar |

## Iconography

- Material Icons filled for primary navigation.
- Material Icons outlined for secondary actions.
- Icon size: 18-20 for row icons, 22-24 for standalone actions.
- Custom brand mark: `assets/brand/cashflow-logo-mark.png`.

## Animation

| Pattern | Duration | Usage |
|---------|----------|-------|
| Shimmer | 1.4s linear loop | Skeleton loading |
| Number counter | 800ms | Balance animation |
| Micro transition | 180-250ms | Press/selection changes |

Keep animation supportive. Finance screens should feel calm, not flashy.

## Responsive Breakpoints

| Breakpoint | Width | Target |
|------------|-------|--------|
| `sm` | >= 360 px | Small phones |
| `md` | >= 600 px | Tablets portrait |
| `lg` | >= 900 px | Tablets landscape |
| `xl` | >= 1200 px | Desktop builds |

## Accessibility

- Contrast ratio >= 4.5:1 for text and >= 3:1 for large text.
- Touch targets should be >= 48 x 48 px where practical.
- Focus indicators stay visible on interactive elements.
- Inputs need labels, not placeholder-only meaning.
- Screen reader support uses Flutter semantics widgets.
- `NSFaceIDUsageDescription` stays present for iOS biometric prompts.

## Brand Assets

| Asset | Path | Usage |
|-------|------|-------|
| Logo mark | `assets/brand/cashflow-logo-mark.png` | App icon, README hero |
| Logo master | `assets/brand/cashflow-logo-master-1024.png` | High-res source |
| Hero dashboard | `docs/media/hero-dashboard.png` | README hero |
| Demo GIF | `docs/media/demo-cashflow-flow.gif` | README demo |

## Screenshot Standards

- Must show populated seeded data, never empty states or loading skeletons.
- Never capture real user finance data, secrets, local paths, or terminal output.
- Keep all amounts in VND format.
- Review screenshots for blank, clipped, overlapped, or unreadable content.
- Regenerate mobile media after UI changes:

```bash
flutter test --no-pub scripts/capture_demo_media_test.dart -r expanded
```
